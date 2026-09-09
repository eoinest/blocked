#include <Arduino.h>
#include <USB.h>
#include <USBCDC.h>
#include <esp_mac.h>
#include <atomic>
#include "ButtonSession.h"
#include "CommandParser.h"

#if !CONFIG_IDF_TARGET_ESP32S2
#error "Select LOLIN S2 Mini; this firmware targets ESP32-S2."
#endif
#if ARDUINO_USB_CDC_ON_BOOT
#error "Disable USB CDC On Boot: this sketch creates its own CDC interface."
#endif

constexpr uint8_t kButtonPin = 4;
USBCDC keySerial;
ButtonSession button;
CommandParser parser;
char deviceID[13];
std::atomic<uint32_t> disconnectEpoch{0};
uint32_t observedEpoch = 0;
uint32_t sequence = 0;

bool isPressed() { return digitalRead(kButtonPin) == LOW; }

void onCDCEvent(void *, esp_event_base_t, int32_t event, void *) {
  if (event == ARDUINO_USB_CDC_DISCONNECTED_EVENT) {
    disconnectEpoch.fetch_add(1, std::memory_order_relaxed);
  }
}

void resetSession() {
  parser.reset();
  button.disconnect(isPressed(), millis());
}

void sendOutput(ButtonSession::Output output) {
  switch (output) {
    case ButtonSession::Output::Press:
      keySerial.printf("PRESS %lu\n", static_cast<unsigned long>(++sequence));
      break;
    case ButtonSession::Output::StateUp: keySerial.print("STATE UP\n"); break;
    case ButtonSession::Output::StateDown: keySerial.print("STATE DOWN\n"); break;
    case ButtonSession::Output::None: break;
  }
}

void handleCommand(CommandParser::Command command) {
  if (command == CommandParser::Command::Hello) {
    button.hello(isPressed(), millis());
    keySerial.printf("KEY_COMMAND 1 %s\n", deviceID);
  } else if (command == CommandParser::Command::Test) {
    const auto snapshot = button.test(isPressed(), millis());
    keySerial.printf("KEY_COMMAND_TEST 1 %s\n", deviceID);
    sendOutput(snapshot);
  }
}

void setup() {
  pinMode(kButtonPin, INPUT_PULLUP);
  resetSession();
  // Factory eFuse base MAC: persistent per-chip identity, not a user credential.
  // Refuse to advertise a fabricated/shared identity if reading the eFuse fails.
  uint8_t mac[6];
  if (esp_efuse_mac_get_default(mac) != ESP_OK) {
    while (true) delay(1000);
  }
  snprintf(deviceID, sizeof(deviceID), "%02X%02X%02X%02X%02X%02X",
           unsigned(mac[0]), unsigned(mac[1]), unsigned(mac[2]),
           unsigned(mac[3]), unsigned(mac[4]), unsigned(mac[5]));
  USB.productName("Key Command");
  USB.serialNumber(deviceID);
  // Keep the LOLIN/Espressif board VID/PID. No custom vendor identity.
  keySerial.onEvent(onCDCEvent);
  keySerial.enableReboot(false);
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
    // Fixed budget even if an unconfigured host continuously sends bytes.
    for (unsigned count = 0; count < 64 && keySerial.available(); ++count) keySerial.read();
    delay(1);
    return;
  }
  for (unsigned count = 0; count < 64 && keySerial.available(); ++count) {
    handleCommand(parser.feed(static_cast<char>(keySerial.read())));
  }
  sendOutput(button.update(isPressed(), millis()));
  delay(1);
}
