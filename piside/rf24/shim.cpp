// everone say thank you claude a 2nd time

// C shim over the TMRh20 RF24 C++ library, so Odin can call it via foreign import.
// Build: see the Makefile in the repo root (produces rf24/librf24shim.a).
//
// Pin numbers are passed straight through to RF24's SPIDEV driver:
//   ce_pin  = BCM GPIO number wired to the radio's CE pin (GPIO25 in your wiring)
//   csn_pin = 0 -> /dev/spidev0.0 (CE0, GPIO8), 1 -> /dev/spidev0.1 (CE1)
 
#include <RF24/RF24.h>
#include <stdbool.h>
#include <stdint.h>
 
struct rf24_t {
    RF24 radio;
    rf24_t(uint16_t ce_pin, uint16_t csn_pin) : radio(ce_pin, csn_pin) {}
};
 
extern "C" {
 
rf24_t *rf24_create(uint16_t ce_pin, uint16_t csn_pin) {
    return new rf24_t(ce_pin, csn_pin);
}
 
void rf24_destroy(rf24_t *r) {
    delete r;
}
 
// Returns false if the radio doesn't respond (wiring, power, SPI not enabled, wrong CSN).
bool rf24_begin(rf24_t *r) {
    return r->radio.begin();
}
 
bool rf24_is_chip_connected(rf24_t *r) {
    return r->radio.isChipConnected();
}
 
void rf24_set_channel(rf24_t *r, uint8_t channel) {
    r->radio.setChannel(channel);
}
 
// 0 = 1 Mbps, 1 = 2 Mbps, 2 = 250 kbps
void rf24_set_data_rate(rf24_t *r, int32_t rate) {
    r->radio.setDataRate((rf24_datarate_e)rate);
}
 
// 0 = min, 1 = low, 2 = high, 3 = max
void rf24_set_pa_level(rf24_t *r, int32_t level) {
    r->radio.setPALevel((uint8_t)level);
}
 
// 0 = disabled, 1 = 8-bit, 2 = 16-bit
void rf24_set_crc_length(rf24_t *r, int32_t length) {
    r->radio.setCRCLength((rf24_crclength_e)length);
}
 
void rf24_set_payload_size(rf24_t *r, uint8_t size) {
    r->radio.setPayloadSize(size);
}
 
void rf24_set_auto_ack(rf24_t *r, bool enable) {
    r->radio.setAutoAck(enable);
}
 
// address must point to 5 bytes (the default address width).
void rf24_open_reading_pipe(rf24_t *r, uint8_t pipe, const uint8_t *address) {
    r->radio.openReadingPipe(pipe, address);
}
 
void rf24_start_listening(rf24_t *r) {
    r->radio.startListening();
}
 
void rf24_stop_listening(rf24_t *r) {
    r->radio.stopListening();
}
 
// True if a received payload is waiting in the RX FIFO.
bool rf24_available(rf24_t *r) {
    return r->radio.available();
}
 
// Reads one payload into buf; length should match the configured payload size.
void rf24_read(rf24_t *r, void *buf, uint8_t length) {
    r->radio.read(buf, length);
}
 
} // extern "C"
 