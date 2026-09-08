#include <Arduino.h>
#include <USB.h>
#include <USBCDC.h>
#include <atomic>
#include "ButtonSession.h"

#if !CONFIG_IDF_TARGET_ESP32S2
#error "This firmware targets ESP32-S2. Select LOLIN S2 Mini."
#endif
#if ARDUINO_USB_CDC_ON_BOOT
#error "Disable USB CDC On Boot: this sketch creates its own named CDC interface."
#endif

constexpr uint8_t kButtonPin = 4;  // Board pad marked 4 / IO4, never USB D+/D-.
USBCDC keySerial;
ButtonSession button;
std::atomic<uint32_t> disconnectEpoch{0};
uint32_t observedEpoch = 0;
uint32_t sequence = 0;
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
  commandLength = 0;
  commandOverflow = false;
  button.disconnect(isPressed(), millis());
}

void sendOutput(ButtonSession::Output output) {
  switch (output) {
    case ButtonSession::Output::Press:
      // Exactly one event per physical press; no queued offline actions.
      keySerial.printf("PRESS %lu\n", static_cast<unsigned long>(++sequence));
      break;
    case ButtonSession::Output::StateUp:
      keySerial.print("STATE UP\n");
      break;
    case ButtonSession::Output::StateDown:
      keySerial.print("STATE DOWN\n");
      break;
    case ButtonSession::Output::None:
      break;
  }
}

void handleCommand() {
  command[commandLength] = '\0';
  if (commandLength == 5 && memcmp(command, "HELLO", 5) == 0) {
    // Every handshake starts a fresh release-before-press window.
    button.hello(isPressed(), millis());
    keySerial.print("BLOCKED_KEY 1\n");
  } else if (commandLength == 4 && memcmp(command, "TEST", 4) == 0) {
    const auto snapshot = button.test(isPressed(), millis());
    keySerial.print("BLOCKED_TEST 1\n");
    sendOutput(snapshot);
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

  sendOutput(button.update(isPressed(), millis()));
  delay(1);
}
