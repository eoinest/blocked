# Test the soldered button over USB

**Blocked Button Tester** is a standalone Mac window showing live
**PRESSED / RELEASED**, hold duration, a press counter and recent events.
It has no GitHub CLI, Chrome automation or review action and works offline.

## First setup

1. Unplug USB while soldering. Connect board pad **4 / IO4** to either metal
   switch terminal, and **GND** to the other. Insulate joints and inspect for
   bridges. No external resistor is needed.
2. Upload the latest [firmware](../firmware/README.md#flash) once. This version
   includes the `TEST` command; older firmware needs updating. Hold **0 / BOOT**,
   tap **RESET**, release BOOT after USB reconnects, then upload. Tap RESET after
   uploading. Keep the lid open during setup.
3. Quit the normal **Blocked** menu-bar app and other serial monitors.
4. Open `companion/dist/Blocked Button Tester.app` and connect a **USB data cable**.
   It automatically finds firmware identifying itself as `Blocked Key`, including
   a board that was connected before the tester opened.

After that initial firmware upload, just plug in USB for ordinary testing;
no BOOT/RESET sequence is needed each time. The same firmware works with the
regular companion afterward: quit the tester and reopen Blocked.

## Expected behavior

| Action | Expected result |
| --- | --- |
| Plug in, switch released | Connected, RELEASED, no extra press |
| Push the switch | PRESSED, counter increases once |
| Keep holding | Hold timer runs; counter stays unchanged |
| Release | RELEASED |
| Press ten separate times | Counter increases by ten |
| Plug in with the switch held | PRESSED / HELD ON CONNECT, no counted press until release and a fresh press |
| Unplug | Live state clears; tester waits for reconnection |
| Reset counter while held | Zero until the next new press |

The display reports electrical input, not mechanical travel or joint strength.
The initial state is an immediate pin snapshot; subsequent changes are
debounced for 25 ms. Shorter presses may not register. The counter records
observed transitions while connected and does not recover offline presses.
The board sends a state heartbeat every second; the app clears a stale
connection after three seconds without valid responses.

**Stuck PRESSED:** release the switch, then check for an IO4-to-GND short,
bridged solder or a jammed switch. **Always RELEASED:** check for an open joint,
the wrong board pad or soldering to something other than the two metal switch
terminals. With USB unplugged, continuity should appear only when pressed.

**Waiting for USB:** check for a data cable and uploaded firmware. An Espressif
board found under another USB product name is shown as needing setup; the
tester does not send commands to arbitrary serial devices. **Firmware needs an
update:** the `Blocked Key` device did not answer `TEST`; upload current firmware.
**Port busy:** close the other serial app and click Reconnect.

## Build and verify

From the repository root:

```sh
bash companion/scripts/build-tester.sh
open "companion/dist/Blocked Button Tester.app"
```

This builds a universal Intel/Apple Silicon app for macOS 13+, signs it locally
and verifies its signature. It requires no GitHub credentials. It is a local
build, not a notarized distribution release.

Run `swift test` from `companion/` for protocol and companion tests. The new
protocol tests cover identity, held snapshots, one count per edge, heartbeat
repeats, malformed input and reconnects. [Firmware tests](../firmware/README.md)
cover debounce, diagnostic heartbeat and mode changes. Firmware compilation
uses the pinned ESP32 3.3.1 core. The real USB bench test still needs your board,
cable and soldered switch.

The tester sends `TEST`, accepts `BLOCKED_TEST 1`, then reads `STATE UP/DOWN`.
Firmware emits no production `PRESS` messages in diagnostic mode. The tester
obtains exclusive serial access and waits for you to quit the ordinary Blocked
app before opening the device. Its `ButtonTestCore` parser target has no
dependency on the review application.
