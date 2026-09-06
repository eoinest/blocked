# ESP32-S2 firmware

The sketch turns one normally-open mechanical switch into a USB CDC serial device. It does not type keys, join Wi-Fi, or store GitHub credentials. The Mac app decides what a press does.

## Build

Install [Arduino CLI](https://arduino.github.io/arduino-cli/latest/installation/). Development uses CLI **1.3.1** and Arduino ESP32 **3.3.1**. The checked-in `sketch.yaml` pins the board core and USB settings; the first profile build downloads its dependencies.

From the repository root:

```sh
ARDUINO_NETWORK_CONNECTION_TIMEOUT=600s arduino-cli compile --profile s2-mini firmware/blocked_key
```

The first build downloads large tool archives for the ESP32 core; the longer network timeout avoids Arduino CLI's default 60-second download limit. [Arduino CLI configuration](https://arduino.github.io/arduino-cli/1.3/configuration/)

The profile uses `esp32:esp32:lolin_s2_mini`, **USB CDC On Boot = Disabled**, **USB MSC On Boot = Disabled**, and **USB DFU On Boot = Disabled**. CDC is disabled *on boot* because the sketch creates its own `USBCDC` interface with product name **Blocked Key** before calling `USB.begin()`; the running firmware still exposes USB serial. Do not enable the boot CDC instance as well.

For an entirely project-local tool cache (optional):

```sh
export ARDUINO_DIRECTORIES_DATA="$PWD/.arduino/data"
export ARDUINO_DIRECTORIES_DOWNLOADS="$PWD/.arduino/downloads"
export ARDUINO_DIRECTORIES_USER="$PWD/.arduino/user"
ARDUINO_NETWORK_CONNECTION_TIMEOUT=600s arduino-cli compile --profile s2-mini firmware/blocked_key
```

## Flash

Close the companion app and serial monitors first. Use a **data-capable** USB-C cable. Flashing replaces any existing MicroPython or other program on this board.

1. Hold the board's **0 / BOOT** button.
2. Tap and release **RST / RESET**, then release **0 / BOOT**. This selects the ROM USB downloader. Alternatively hold BOOT while plugging in USB, then release it.
3. Run `arduino-cli board list` and copy this board's `/dev/cu.usbmodem...` path.
4. Upload, replacing the example port:

```sh
arduino-cli upload --profile s2-mini --port /dev/cu.usbmodemYOUR_BOARD firmware/blocked_key
```

5. Tap RESET. The running device can have a different port path; the companion app discovers it again by USB product name.

The firmware disables serial-line reboot shortcuts, so use the physical BOOT + RESET sequence for subsequent uploads too. Keep both buttons accessible until the gift is assembled. If the board never appears, first try another known data cable and inspect the board's actual model and pinout. The original ESP32 lacks the ESP32-S2's native USB controller; a USB-C connector alone does not imply compatibility.

## Protocol version 1

ASCII lines ending in LF. Input also accepts CRLF. USB CDC uses nominal 115200 baud, 8 data bits, no parity, one stop bit; the host must assert **both DTR and RTS** for the pinned Espressif implementation's connected state. The board advertises the LOLIN/Espressif development-board USB identity plus product name `Blocked Key`.

| Direction | Line | Meaning |
| --- | --- | --- |
| Host → board | `HELLO` | Start or restart an application session. |
| Board → host | `BLOCKED_KEY 1` | Device identity and protocol version. |
| Board → host | `PRESS 1` | Fresh press; counter increments each event until reboot (32-bit unsigned wrap). |
| Host → board | `RESULT OK`, `RESULT DRY_RUN`, `RESULT ERROR` | Optional feedback, currently ignored by this firmware. |

After every handshake, the switch must remain released for **25 ms**, then pressed for **25 ms**, before an event can fire. Booting with the key held, holding it down, contact bounce, and reconnecting while held do not create presses. Events before a handshake or while disconnected are discarded. Unknown and oversized input lines are ignored. Sequence numbers are for session deduplication, not durable event delivery. The device does not retry actions.

`BLOCKED_KEY 1` identifies compatible firmware; it is not cryptographic authentication. The USB connection has the privileges of the locally configured companion app.

## Verification

Run the portable button-state regression checks:

```sh
c++ -std=c++17 -Wall -Wextra -Werror firmware/tests/button_gate_test.cpp -o /tmp/blocked-key-button-test
/tmp/blocked-key-button-test
```

The checks exercise contact bounce, no repeat while held, held boot, reconnect, short release, and unsigned clock wrap. They do not emulate USB hardware. Physical USB enumeration, electrical wiring, cable behavior, and actual switch feel still need a bench test on your board. Start with the companion app's dry-run mode; use the assembly checklist in [hardware.md](../docs/hardware.md).

References: [Espressif USB CDC API](https://docs.espressif.com/projects/arduino-esp32/en/latest/api/usb_cdc.html), [Espressif USB flashing guide](https://docs.espressif.com/projects/arduino-esp32/en/latest/tutorials/cdc_dfu_flash.html), [pinned board definitions](https://github.com/espressif/arduino-esp32/blob/3.3.1/boards.txt), [LOLIN Arduino instructions](https://docs.wemos.cc/en/latest/tutorials/s2/get_started_with_arduino_s2.html).
