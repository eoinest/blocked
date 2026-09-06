# Build it in stages

This project starts as an unassembled prototype. Build the electrical and
software loop on the desk before sealing anything in a printed case.

## 1. Check the board

Confirm it is an **ESP32-S2 Mini**, with native USB, and compare its shape and
pin labels with [the hardware guide](hardware.md). The enclosure is based on a
headerless LOLIN S2 Mini; measure clones before printing. Use a USB **data** cable.
An LED lighting up only proves the cable supplies power.

## 2. Check the switch and solder two wires

Print the switch coupon and lid first, following the [key mounting guide](key-mounting.md).
Check both retaining clips and cap travel on the coupon, then clip the switch
into the final lid before connecting both ends of its wires. The flange and
ESP32 are too large to thread through the switch aperture afterward.

With everything unplugged, use a multimeter's continuity mode across the two
metal switch contacts: open when released, connected when pressed. Wire one
contact to the documented button GPIO and the other to GND. The switch has no
polarity. Do not connect a switch contact to 5 V.

Tin the wire and contact first, solder briefly, insulate exposed switch contacts,
and leave a small service loop so the lid can lift off. Check for bridges before
plugging in. See [hardware](hardware.md) for the selected GPIO and pin cautions.

## 3. Flash and test dry-run

Follow [firmware setup](../firmware/README.md), then close any serial monitor so
the companion can own the USB port. Build and open
[Blocked.app](../companion/README.md). Connect the recipient's own GitHub account in the setup window and grant Chrome Automation permission during the companion setup.

Keep Blocked paused. Choose **Test next press (no review)**, focus a GitHub
pull request in Google Chrome and press the physical key. Confirm that the preview contains the expected PR,
action, and the exact body `blocked`.

## 4. Try the important edge cases

These are manual acceptance checks, **not a claim that they have passed on
physical hardware**. For each diagnostic press, keep Blocked paused and choose
**Test next press (no review)** again. Later presses remain paused:

| Check | Expected result |
| --- | --- |
| Plug in with the key released | Connects; no review event |
| Plug in while holding the key | No event until released and pressed again |
| Hold the key for several seconds | One event |
| Tap repeatedly | Debounce/cooldown suppress duplicates |
| Focus a different app while Chrome remains open | No review |
| Focus a normal GitHub page or an issue | No review |
| Open two Chrome windows with different PRs | Targets the front window's active tab |
| Switch to Files changed / Commits / Checks | Still identifies the same PR |
| Disconnect and reconnect USB | Reconnects without a stale press |
| Quit and reopen Blocked | Keeps enabled/paused intent; paused stays paused |
| Deny Automation or remove CLI authentication | Clear failure; no fallback target |
| Disconnect network during a live test | No automatic retry; inspect GitHub manually |

Only after dry-run works, enable live reviews and test once on a PR whose owner
has agreed to the test. The recipient must use their own GitHub CLI identity.
Do not use their own authored PR to test request-changes; GitHub restricts
self-reviews. Confirm the posted review reads exactly `blocked`.

## 5. Finish the case and check the assembly

Use [the enclosure guide](enclosure.md). With the switch coupon and lid already
checked, print the fastener coupons and remaining shell. Check the actual board, plug
overmold, screws, wire routing, and key travel. Nothing should flex the PCB or
press against a solder joint. Adjust the parameters if your printer or clone
board needs different clearances.

## 6. Finish the gift

Order the white **1.5u Tab-width keycap** using the [exact settings and artwork](../keycap/README.md),
with a small lowercase **blocked** legend at the front-left. The
revised render pairs it with a satin silver housing and a dark inset bottom
seam. Silver/gray filament gives the color; sanding, primer, and metallic paint
are optional finishing steps if you want to approach the render's finish.
Recess the adhesive pads so they barely protrude. Put the USB-C cable, the repo
URL, and the Mac setup instructions in the box.

The first build requires soldering, flashing, and local app setup. Once those
are done, everyday use is: open Blocked, enable live reviews, focus a PR, press.
