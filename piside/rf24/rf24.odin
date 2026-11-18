// Thank you claude a 3rd time

// Odin bindings for the RF24 C shim (see shim.cpp).
// librf24shim.a is built by the Makefile in the repo root; the path below is
// relative to this file. system:rf24 is the installed RF24 library and
// system:stdc++ is the C++ runtime that RF24 needs.
package rf24

foreign import lib {
	"librf24shim.a",
	"system:rf24",
	"system:stdc++",
}

// Opaque handle to a radio instance.
Radio :: distinct rawptr

Data_Rate :: enum i32 {
	Mbps_1  = 0,
	Mbps_2  = 1,
	Kbps_250 = 2,
}

PA_Level :: enum i32 {
	Min  = 0,
	Low  = 1,
	High = 2,
	Max  = 3,
}

CRC_Length :: enum i32 {
	Disabled = 0,
	Bits_8   = 1,
	Bits_16  = 2,
}

@(default_calling_convention = "c", link_prefix = "rf24_")
foreign lib {
	// ce_pin: BCM GPIO number of CE. csn_pin: 0 = /dev/spidev0.0, 1 = /dev/spidev0.1.
	create :: proc(ce_pin: u16, csn_pin: u16) -> Radio ---
	destroy :: proc(r: Radio) ---

	// false means the radio didn't respond (check wiring, 3.3V power, SPI enabled, CSN).
	begin :: proc(r: Radio) -> bool ---
	is_chip_connected :: proc(r: Radio) -> bool ---

	set_channel :: proc(r: Radio, channel: u8) ---
	set_data_rate :: proc(r: Radio, rate: Data_Rate) ---
	set_pa_level :: proc(r: Radio, level: PA_Level) ---
	set_crc_length :: proc(r: Radio, length: CRC_Length) ---
	set_payload_size :: proc(r: Radio, size: u8) ---
	set_auto_ack :: proc(r: Radio, enable: bool) ---

	open_reading_pipe :: proc(r: Radio, pipe: u8, address: ^[5]u8) ---
	start_listening :: proc(r: Radio) ---
	stop_listening :: proc(r: Radio) ---

	// true if a payload is waiting in the RX FIFO.
	available :: proc(r: Radio) -> bool ---
	// Reads one payload; length should match the configured payload size.
	read :: proc(r: Radio, buf: rawptr, length: u8) ---
}
