package main

import "base:intrinsics"

import "core:math"
import "core:math/rand"
import "core:fmt"
import "core:container/handle_map"

import "vendor:raylib"

import "rf24"

Asteroid :: struct {
    using pos: [2]f32,
    vel: [2]f32,
    rotation, angular_vel: f32,
    size: Asteroid_Size,
    fresh: bool,
    handle: Handle
}

Handle :: handle_map.Handle32
Asteroid_Map :: handle_map.Static_Handle_Map(MAX_ASTEROIDS, Asteroid, Handle)

Asteroid_Size :: enum {
    LARGE,
    MED,
    SMALL
}

SCREEN_SIZE :: [2]i32{800, 800}

BASE_RADIUS :: 38
ASTEROID_COUNT :: 12
MAX_ASTEROIDS :: ASTEROID_COUNT * 4

@(rodata)
SCALES := [Asteroid_Size]f32{
    .LARGE = 1.5,
    .MED = 1,
    .SMALL = .5
}

asteroid_tex: raylib.Texture

// ---- Radio settings (must match the Arduino sketch) ----
RADIO_CE_PIN  :: 25   // BCM GPIO25
RADIO_CSN_PIN :: 0    // /dev/spidev0.0
RADIO_CHANNEL :: 76
RADIO_ADDRESS :: [5]u8{'0', '0', '0', '0', '1'}

// ---- Controller buttons (bits in Packet.buttons) ----
BUTTON_SHOOT :: u8(1 << 0)   // D2
BUTTON_RESET :: u8(1 << 1)   // D3 (hold to keep position and velocity at 0)
// bit 2 (D4) is unused

// ---- Motion tuning ----
PACKET_INTERVAL  :: f32(0.02)   // seconds between packets (50 per second)
MAX_MISSED_STEPS :: 25          // larger sequence jumps are treated as one step
COUNTS_PER_G     :: f32(256)    // ADXL345 at +/-2g
GRAVITY_ALPHA    :: f32(0.01)   // gravity low-pass, per packet (~2 s time constant)
DEADZONE_G       :: f32(0.04)   // ignore accelerations smaller than this
DAMPING          :: f32(2.0)    // velocity decay per second; higher = less floaty
PIXELS_PER_METER :: f32(2000)   // how far the crosshair moves per meter of motion
G_TO_PX          :: f32(9.81) * PIXELS_PER_METER
AIM_SIGN         :: [2]f32{1, -1}   // flip a sign if an axis feels reversed

MAX_PACKETS_PER_FRAME :: 8

// 9-byte packet from the Arduino, little-endian.
Packet :: struct #packed {
    seq:     u16le,
    x, y, z: i16le,   // raw ADXL345 counts (z is received but unused)
    buttons: u8,
}
#assert(size_of(Packet) == 9)

Controller :: struct {
    radio:        rf24.Radio,
    have_packet:  bool,
    last_seq:     u16,
    prev_buttons: u8,
    gravity:      [2]f32,   // running gravity estimate, raw counts
    vel:          [2]f32,   // pixels per second
    pos:          [2]f32,   // pixels from screen center
}

main :: proc() {
    raylib.InitWindow(SCREEN_SIZE.x, SCREEN_SIZE.y, "1300 Exhibit Game")
    raylib.SetTargetFPS(60)

    asteroid_tex = raylib.LoadTexture("asteroid.png")
    defer raylib.UnloadTexture(asteroid_tex)

    asteroids := generate_asteroids()

    controller: Controller
    if controller_init(&controller) {
        fmt.println("nRF24L01 ready, listening for the controller")
    } else {
        fmt.eprintln("nRF24L01 not found; mouse input only")
    }
    defer controller_destroy(&controller)

    for !raylib.WindowShouldClose() {
        controller_shot := controller_poll(&controller)
        aim := cast([2]f32)SCREEN_SIZE / 2 + controller.pos

        raylib.ClearBackground(raylib.BLACK)
        raylib.BeginDrawing()
        defer raylib.EndDrawing()
        
        iter := handle_map.iterator_make(&asteroids)
        for asteroid, _ in handle_map.iterate(&iter) {
            asteroid.pos += asteroid.vel
            ffs := cast([2]f32)(SCREEN_SIZE)
            asteroid.pos = {posmod(asteroid.x, ffs.x), posmod(asteroid.y, ffs.y)}

            asteroid.rotation += asteroid.angular_vel

            asteroid.fresh = false

            draw_asteroid(asteroid^)
        }

        if controller_shot {
            shoot(&asteroids, aim)
        }
        if raylib.IsMouseButtonPressed(.LEFT) {
            shoot(&asteroids, raylib.GetMousePosition())
        }

        draw_crosshair(aim)
    }
}

shoot :: proc(asteroids: ^Asteroid_Map, at: [2]f32) {
    iter := handle_map.iterator_make(asteroids)
    for asteroid, handle in handle_map.iterate(&iter) {
        real_size := SCALES[asteroid.size] * BASE_RADIUS
        if (!asteroid.fresh) && raylib.Vector2Distance(at, asteroid.pos) < real_size {
            handle_map.remove(asteroids, handle)

            new_size: Asteroid_Size
            switch asteroid.size {
            case .SMALL:
                continue
            case .LARGE:
                new_size = .MED
            case .MED:
                new_size = .SMALL
            }

            for i in 0..<2 {
                new_asteroid := generate_asteroid()
                new_asteroid.size = new_size
                new_asteroid.pos = asteroid.pos
                new_handle, ok := handle_map.add(asteroids, new_asteroid)
            }
        }
    }
}

draw_crosshair :: proc(at: [2]f32) {
    raylib.DrawCircleLines(i32(at.x), i32(at.y), 14, raylib.GREEN)
    raylib.DrawLineV(at - {22, 0}, at - {6, 0}, raylib.GREEN)
    raylib.DrawLineV(at + {6, 0}, at + {22, 0}, raylib.GREEN)
    raylib.DrawLineV(at - {0, 22}, at - {0, 6}, raylib.GREEN)
    raylib.DrawLineV(at + {0, 6}, at + {0, 22}, raylib.GREEN)
}

// Returns false if the radio doesn't respond; the game then runs with the mouse only.
controller_init :: proc(c: ^Controller) -> bool {
    radio := rf24.create(RADIO_CE_PIN, RADIO_CSN_PIN)
    if !rf24.begin(radio) {
        rf24.destroy(radio)
        return false
    }
    rf24.set_channel(radio, RADIO_CHANNEL)
    rf24.set_data_rate(radio, .Mbps_1)
    rf24.set_crc_length(radio, .Bits_16)
    rf24.set_pa_level(radio, .Low)
    rf24.set_auto_ack(radio, true)
    rf24.set_payload_size(radio, size_of(Packet))

    address := RADIO_ADDRESS
    rf24.open_reading_pipe(radio, 1, &address)
    rf24.start_listening(radio)

    c.radio = radio
    return true
}

controller_destroy :: proc(c: ^Controller) {
    if c.radio != nil {
        rf24.destroy(c.radio)
        c.radio = nil
    }
}

// Drains waiting packets. Returns true if the shoot button was newly pressed.
controller_poll :: proc(c: ^Controller) -> (shot: bool) {
    if c.radio == nil {
        return
    }
    for _ in 0..<MAX_PACKETS_PER_FRAME {
        if !rf24.available(c.radio) {
            break
        }
        packet: Packet
        rf24.read(c.radio, &packet, size_of(Packet))
        if controller_handle_packet(c, packet) {
            shot = true
        }
    }
    return
}

controller_handle_packet :: proc(c: ^Controller, p: Packet) -> (shot: bool) {
    seq := u16(p.seq)
    raw := [2]f32{f32(i16(p.x)), f32(i16(p.y))}

    shot = (p.buttons & BUTTON_SHOOT) != 0 && (c.prev_buttons & BUTTON_SHOOT) == 0
    c.prev_buttons = p.buttons

    // First packet, or reset held: zero position and velocity, and re-take the
    // gravity reading from the current pose so the controller stops drifting.
    if !c.have_packet || (p.buttons & BUTTON_RESET) != 0 {
        c.have_packet = true
        c.last_seq = seq
        c.gravity = raw
        c.pos = {}
        c.vel = {}
        return
    }

    // Packets lost in the air show up as a gap in the sequence number.
    delta := int(seq - c.last_seq)
    c.last_seq = seq
    if delta == 0 {
        return
    }
    if delta > MAX_MISSED_STEPS {
        delta = 1
    }
    dt := f32(delta) * PACKET_INTERVAL

    // Remove gravity with a slow low-pass, then drop small noise.
    c.gravity += (raw - c.gravity) * GRAVITY_ALPHA
    lin := (raw - c.gravity) / COUNTS_PER_G
    for i in 0..<2 {
        if abs(lin[i]) < DEADZONE_G {
            lin[i] = 0
        }
    }

    // Integrate acceleration -> velocity -> position, with damping against drift.
    accel := lin * AIM_SIGN * G_TO_PX
    c.vel += accel * dt
    c.vel -= c.vel * min(DAMPING * dt, 1)
    c.pos += c.vel * dt

    // Keep the crosshair on screen.
    half := cast([2]f32)SCREEN_SIZE / 2
    for i in 0..<2 {
        if c.pos[i] < -half[i] {
            c.pos[i] = -half[i]
            c.vel[i] = 0
        } else if c.pos[i] > half[i] {
            c.pos[i] = half[i]
            c.vel[i] = 0
        }
    }
    return
}

posmod :: proc(lhs, rhs: $T) -> T where intrinsics.type_is_numeric(T) {
    return lhs - rhs * math.floor(lhs / rhs)
}

draw_asteroid :: proc(asteroid: Asteroid) {
    tex_size := [2]f32{f32(asteroid_tex.width), f32(asteroid_tex.height)}
    scale := SCALES[asteroid.size]
    real_size := tex_size * scale

    // raylib.DrawCircle(i32(asteroid.x), i32(asteroid.y), real_size.x / 2, raylib.RED)
    raylib.DrawTexturePro(
        asteroid_tex,
        {0, 0, tex_size.x, tex_size.y},
        {asteroid.x, asteroid.y, real_size.x, real_size.y},
        real_size / 2,
        asteroid.rotation,
        raylib.WHITE
    )
}

generate_asteroids :: proc() -> Asteroid_Map {
    asteroids: Asteroid_Map
    for i in 0..<ASTEROID_COUNT {
        handle, ok := handle_map.add(&asteroids, generate_asteroid())
        continue // very clever
    }
    return asteroids
}

generate_asteroid :: proc() -> Asteroid {
    return {
        pos = cast([2]f32)SCREEN_SIZE * {rand.float32(), rand.float32()},
        vel = 3 * ({rand.float32(), rand.float32()} - .5),
        rotation = 360 * rand.float32(),
        angular_vel = 2 * rand.float32(),
        size = rand.choice_enum(Asteroid_Size),
        fresh = true
    }
}
