# Key Command firmware

This is a separate ESP32-S2 Mini firmware for the Key Command companion app. It
does not change or share source dependencies with `firmware/blocked_key`. Connect
a normally-open switch between **GPIO 4 and GND**; the internal pull-up supplies
the input bias. Actions are configured and executed on the Mac. The board never
receives shell commands, stores credentials, or connects to Wi-Fi.

## Build and explicitly select a board to flash

Use Arduino CLI **1.3.1**. `sketch.yaml` pins Arduino ESP32 **3.3.1**, LOLIN S2 Mini,
and USB CDC On Boot disabled; the sketch creates its own USB CDC interface.

From the repository root:

```sh
ARDUINO_NETWORK_CONNECTION_TIMEOUT=600s arduino-cli compile --profile s2-mini --build-path /tmp/key-command-build firmware/key_command
```

Compilation does not flash anything. To install it on an additional board, close
apps holding that board's serial port, hold **BOOT**, tap **RESET**, then release
BOOT. Run `arduino-cli board list` and identify that board's current port. The
following upload replaces that board's existing firmware; use its actual port:

```sh
arduino-cli upload --profile s2-mini --input-dir /tmp/key-command-build --port /dev/cu.usbmodemYOUR_NEW_BOARD firmware/key_command
```

Tap RESET afterward. Do not select the existing Blocked board unless you intend
to replace its firmware. There is no automatic port selection or upload step.

## Protocol version 1

ASCII lines use LF or CRLF. Open at nominal **115200, 8N1**, asserting **both DTR
and RTS**. USB product name is `Key Command`; VID/PID remain the board defaults
(Espressif VID `0x303A`). The USB serial string is the same 12-character uppercase
hex ID returned by the handshake, derived from the factory eFuse base MAC. It
remains stable across reset and firmware uploads on that chip. This identifier
is for associating settings with a board, not authentication.

| Direction | Line | Meaning |
| --- | --- | --- |
| Host → board | `KEY_COMMAND_HELLO` | Start/restart production session. |
| Board → host | `KEY_COMMAND 1 AABBCCDDEEFF` | Version and example device ID. |
| Board → host | `PRESS 1` | One new physical press; unsigned 32-bit counter. |
| Host → board | `KEY_COMMAND_TEST` | Start/restart diagnostics; suppress presses. |
| Board → host | `KEY_COMMAND_TEST 1 AABBCCDDEEFF` | Diagnostic identity; followed by a state snapshot. |
| Board → host | `STATE UP` or `STATE DOWN` | Diagnostic released/pressed state. |

Plain `HELLO` and `TEST` are ignored, so the Blocked app cannot activate this
firmware. Commands must match exactly. Unknown lines, non-ASCII/control bytes,
embedded CR, and lines longer than 63 characters are discarded through the next
LF. A single trailing CR is accepted. Parsing consumes at most 64 received bytes
per loop so continuous input cannot prevent button sampling.

Every production handshake requires a **25 ms stable release**, followed by a
**25 ms stable press**, before emitting an event. A held button never repeats.
Booting, reconnecting, or handshaking while held produces no action. Disconnection
clears mode and partial input; a new handshake is required. Offline presses are
discarded. The sequence increases only for production events, persists across
handshakes while powered, resets at reboot, and wraps modulo 2³². It is not a
delivery queue; hosts should deduplicate within a session and never replay old
events after reconnecting.

Diagnostics sends an immediate raw input snapshot, then debounced transitions
and a heartbeat 1,000 ms after the last state report. It never emits `PRESS` or
advances its counter. `KEY_COMMAND_HELLO` returns to production with a fresh
release-before-arm requirement. Serial reboot shortcuts are disabled; use the
physical BOOT/RESET controls to enter the downloader.

## Portable checks

```sh
c++ -std=c++17 -Wall -Wextra -Werror -fsanitize=address,undefined firmware/tests/key_command_test.cpp -o /tmp/key-command-test
/tmp/key-command-test
```

These exercise exact handshakes and cross-product isolation, oversized/binary
input and parser recovery, partial commands across disconnection, held boot,
contact bounce, no repeat, release-before-arm, offline suppression, diagnostics,
mode changes, heartbeats, and unsigned clock wrap. They do not emulate USB or
prove physical switch wiring. No board is flashed by the tests.

Verified locally with CLI 1.3.1 and the pinned ESP32 3.3.1 profile: **302,342 bytes
flash**, **34,752 bytes global RAM**. All portable checks passed with address and
undefined-behavior sanitizers, and the existing Blocked tests also passed. The
profile installer reported an unavailable unrelated RISC-V download; the cached
Xtensa/S2 tools completed compilation successfully. No board was flashed. Local
compiled images and their source hashes are in the ignored
`firmware/dist/key-command/` directory, with metadata in `build-info.json`.

The local distribution copy is
`key-command/dist/KeyCommand-ESP32-S2-0.1.0.bin`, with a `.bin.sha256` sidecar.
This is a **4 MiB merged image for ESP32-S2**, written at flash offset **0x0**
if using an external flashing tool. Its embedded bootloader at `0x1000`, partition
table at `0x8000`, and application at `0x10000` were compared byte-for-byte with
the actual build outputs. Do not upload this merged image at the application's
`0x10000` offset. The Arduino upload command above selects the separate images
and their offsets automatically.

Implementation references: [pinned Espressif USB API](https://github.com/espressif/arduino-esp32/blob/3.3.1/cores/esp32/USB.h),
[pinned USB implementation](https://github.com/espressif/arduino-esp32/blob/3.3.1/cores/esp32/USB.cpp),
and [pinned board definitions](https://github.com/espressif/arduino-esp32/blob/3.3.1/boards.txt).
