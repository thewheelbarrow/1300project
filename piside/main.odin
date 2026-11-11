package main

import "base:intrinsics"

import "core:math"
import "core:math/rand"
import "core:fmt"
import "core:container/handle_map"

import "vendor:raylib"

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

SCREEN_SIZE :: [2]i32{600, 600}

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

main :: proc() {
    raylib.InitWindow(SCREEN_SIZE.x, SCREEN_SIZE.y, "1300 Exhibit Game")
    raylib.SetTargetFPS(60)

    asteroid_tex = raylib.LoadTexture("asteroid.png")
    defer raylib.UnloadTexture(asteroid_tex)

    asteroids := generate_asteroids()

    for !raylib.WindowShouldClose() {
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

        if raylib.IsMouseButtonPressed(.LEFT) {
            iter := handle_map.iterator_make(&asteroids)
            for asteroid, handle in handle_map.iterate(&iter) {
                real_size := SCALES[asteroid.size] * BASE_RADIUS
                if (!asteroid.fresh) && raylib.Vector2Distance(raylib.GetMousePosition(), asteroid.pos) < real_size {
                    handle_map.remove(&asteroids, handle)
                    
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
                        handle, ok := handle_map.add(&asteroids, new_asteroid)
                    }
                }
            }
        }
    }
}

posmod :: proc(lhs, rhs: $T) -> T where intrinsics.type_is_numeric(T) {
    return lhs - rhs * math.floor(lhs / rhs)
}

draw_asteroid :: proc(asteroid: Asteroid) {
    tex_size := [2]f32{f32(asteroid_tex.width), f32(asteroid_tex.height)}
    scale := SCALES[asteroid.size]
    real_size := tex_size * scale

    raylib.DrawCircle(i32(asteroid.x), i32(asteroid.y), real_size.x / 2, raylib.RED)
    // raylib.DrawTexturePro(
    //     asteroid_tex,
    //     {0, 0, tex_size.x, tex_size.y},
    //     {asteroid.x, asteroid.y, real_size.x, real_size.y},
    //     real_size / 2,
    //     asteroid.rotation,
    //     raylib.WHITE
    // )
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
        pos = {50, 50} + 1100 * {rand.float32(), rand.float32()},
        vel = 3 * ({rand.float32(), rand.float32()} - .5),
        rotation = 360 * rand.float32(),
        angular_vel = 2 * rand.float32(),
        size = rand.choice_enum(Asteroid_Size),
        fresh = true
    }
}