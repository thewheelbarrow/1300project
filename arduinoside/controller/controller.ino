#include <SPI.h>
#include <Wire.h>
#include <RF24.h>
#include <Adafruit_Sensor.h>
#include <Adafruit_ADXL345_U.h>

// ---- Radio settings (the Pi must use the same values) ----
const uint8_t CE_PIN = 8;
const uint8_t CSN_PIN = 7;
const uint8_t RADIO_CHANNEL = 76;
const byte ADDRESS[6] = "00001";  // 5 ASCII bytes: '0','0','0','0','1'

// ---- Buttons: wired between the pin and GND ----
const uint8_t BUTTON_PINS[3] = {2, 3, 4};  // bit0 = D2, bit1 = D3, bit2 = D4

// ---- Send rate: 50 packets per second ----
const unsigned long SEND_INTERVAL_MS = 20;

// 9-byte packet, little-endian (matches the AVR and the Pi's ARM)
struct __attribute__((packed)) Packet {
  uint16_t seq;      // increments every packet, wraps at 65535
  int16_t  x;        // raw ADXL345 counts (256 counts = 1g at +/-2g)
  int16_t  y;
  int16_t  z;
  uint8_t  buttons;  // bit0 = D2, bit1 = D3, bit2 = D4; 1 = pressed
};
static_assert(sizeof(Packet) == 9, "Packet must be 9 bytes");

RF24 radio(CE_PIN, CSN_PIN);
Adafruit_ADXL345_Unified accel = Adafruit_ADXL345_Unified();

uint16_t sequence = 0;
unsigned long lastSend = 0;

void setup() {
  for (uint8_t i = 0; i < 3; i++) {
    pinMode(BUTTON_PINS[i], INPUT_PULLUP);
  }

  // Retry forever until each chip responds.
  while (!accel.begin()) {
    delay(500);
  }
  accel.setRange(ADXL345_RANGE_2_G);

  while (!radio.begin()) {
    delay(500);
  }
  radio.setChannel(RADIO_CHANNEL);
  radio.setDataRate(RF24_1MBPS);
  radio.setCRCLength(RF24_CRC_16);
  radio.setPALevel(RF24_PA_LOW);  // lower current draw (no capacitor on the module)
  radio.setAutoAck(true);
  radio.setPayloadSize(sizeof(Packet));
  radio.openWritingPipe(ADDRESS);
  radio.stopListening();
}

void loop() {
  unsigned long now = millis();
  if (now - lastSend < SEND_INTERVAL_MS) {
    return;
  }
  lastSend = now;

  Packet p;
  p.seq = sequence++;
  p.x = accel.getX();
  p.y = accel.getY();
  p.z = accel.getZ();

  p.buttons = 0;
  for (uint8_t i = 0; i < 3; i++) {
    if (digitalRead(BUTTON_PINS[i]) == LOW) {  // LOW = pressed
      p.buttons |= (1 << i);
    }
  }

  radio.write(&p, sizeof(p));  // result ignored; the Pi detects drops via seq
}