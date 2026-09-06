#include <Arduino.h>
#include <USB.h>
#include <USBCDC.h>
#include <atomic>
#include "ButtonGate.h"

#if !CONFIG_IDF_TARGET_ESP32S2
#error "This firmware targets ESP32-S2. Select LOLIN S2 Mini."
#endif
#if ARDUINO_USB_CDC_ON_BOOT
#error "Disable USB CDC On Boot: this sketch creates its own named CDC interface."
#endif

constexpr uint8_t kButtonPin = 4;  // Board pad marked 4 / IO4, never USB D+/D-.
USBCDC keySerial;
ButtonGate button;
std::atomic<uint32_t> disconnectEpoch{0};
uint32_t observedEpoch = 0;
uint32_t sequence = 0;
bool identified = false;
char command[64];
size_t commandLength = 0;
bool commandOverflow = false;

bool isPressed() { return digitalRead(kButtonPin) == LOW; }

void onCDCEvent(void *, esp_event_base_t, int32_t event, void *) {
  if (event == ARDUINO_USB_CDC_DISCONNECTED_EVENT) {
    disconnectEpoch.fetch_add(1, std::memory_order_relaxed);
  }
}

void resetSession() {
  identified = false;
  commandLength = 0;
  commandOverflow = false;
  button.reset(isPressed(), millis());
}

void handleCommand() {
  command[commandLength] = '\0';
  if (commandLength == 5 && memcmp(command, "HELLO", 5) == 0) {
    // Every handshake starts a fresh release-before-press window.
    button.reset(isPressed(), millis());
    identified = true;
    keySerial.print("BLOCKED_KEY 1\n");
  }
  // Optional RESULT OK / RESULT DRY_RUN / RESULT ERROR are intentionally ignored.
  // The app is the source of truth for whether the review reached GitHub.
}

void setup() {
  pinMode(kButtonPin, INPUT_PULLUP);
  resetSession();
  USB.productName("Blocked Key");
  // Retain the LOLIN/Espressif board VID/PID; no invented USB vendor identity.
  keySerial.onEvent(onCDCEvent);
  keySerial.enableReboot(false);  // Use physical BOOT + RESET when flashing.
  keySerial.setRxBufferSize(256);
  keySerial.setTxTimeoutMs(10);
  keySerial.begin(115200);
  USB.begin();
}

void loop() {
  const uint32_t epoch = disconnectEpoch.load(std::memory_order_relaxed);
  if (epoch != observedEpoch) {
    observedEpoch = epoch;
    resetSession();
  }
  if (!keySerial) {
    resetSession();
    while (keySerial.available()) keySerial.read();
    delay(1);
    return;
  }

  // Bounded work keeps a noisy host from starving switch sampling.
  for (unsigned count = 0; count < sizeof(command) && keySerial.available(); ++count) {
    const char next = static_cast<char>(keySerial.read());
    if (next == '\r') continue;
    if (next == '\n') {
      if (!commandOverflow) handleCommand();
      commandLength = 0;
      commandOverflow = false;
    } else if (!commandOverflow && commandLength < sizeof(command) - 1) {
      command[commandLength++] = next;
    } else {
      commandOverflow = true;  // Discard the whole oversized line, never its suffix.
    }
  }

  if (identified && button.update(isPressed(), millis())) {
    // Exactly one event per physical press; no retries or queued offline actions.
    keySerial.printf("PRESS %lu\n", static_cast<unsigned long>(++sequence));
  }
  delay(1);
}
