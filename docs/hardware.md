# Build the physical key

For the gift, my pick is one **Gateron Baby Kangaroo 2.0**, a **1.5u MX-compatible keycap** printed or engraved with `blocked`, and your S2 Mini. Gateron describes an early, strong tactile action with nominal 59 ± 8 gf operating force and a five-pin MX structure. That is a good direction for a deliberate, satisfying one-purpose press; the exact feel still needs a sample in your hand. [Gateron product page](https://www.gateron.com/products/gateron-baby-kangaroo-20-tactile-switch-set)

**CHERRY MX2A Brown** is the easy-to-source, gentler alternative. It has 2 mm pre-travel and 4 mm total travel; CHERRY lists 45 cN actuation and 55 cN at the tactile peak. It is a soft bump, so choose the Baby Kangaroo if the gift should feel more emphatic. The wider 1.5u cap still uses one centered switch; choose a cap with a single centered MX stem and check off-center presses. [CHERRY Brown specifications](https://www.cherry.de/fr-fr/produit/mx2a-brown)

Feel is personal. A single-switch sample or small tester is more useful than buying an entire keyboard's worth for this project. The printed enclosure changes the sound too. Use a manufactured cap for the nicest finger surface and durable stem; an FDM cap is fine for experimenting with the legend and shape. Choose standard MX switches with **metal electrical contacts**; optical, Hall-effect, and inductive variants require different electronics.

## Shopping list and keycap

Use the condensed [BOM](../BOM.md) for quantities and the chosen parts.
The selected cap is **Max Keyboard’s custom-printed OEM-profile 1.5u Tab cap**,
white with black `blocked` on top; [exact order settings and artwork](../keycap/README.md)
are included. The Blender cap remains an approximate visual reference, so check
full travel and off-center presses with the purchased cap.

[Switch alternatives](switch-research.md) are kept separately from the shopping
list. The build needs no battery, keyboard PCB, stabilizer, diode, or external
resistor.

For the mechanical connection, follow the [key mounting guide](key-mounting.md):
flange on top of the lid, both switch clips latched underneath, and the cap
pressed straight onto the centred MX stem. The lid ribs carry the key load;
wires and ESP32 pins do not support the switch.

## Wiring

Unplug USB before soldering. The only two connections are:

```text
          ESP32-S2 Mini                         MX switch

  3.3 V -- internal pull-up -- GPIO4 / pad 4 ---- metal contact A
                                                 /  normally open
                              GND ------------- metal contact B

  USB-C ==================== Mac (power + native USB data)
```

The two switch contacts have no polarity. Pressing the switch connects GPIO4 to ground, which the firmware reads as LOW. The released input reads HIGH through `INPUT_PULLUP`. **Do not wire the switch to 5 V, VBUS, or 3V3.** Do not use the board's BOOT button/GPIO0 for the gift key. GPIO19 and GPIO20 are USB D− and D+ and must remain reserved for USB. The reference firmware uses **GPIO4**, the pad marked `4` or `IO4`, not the fourth physical pad from an edge. [Official schematic](https://docs.wemos.cc/en/latest/_static/files/sch_s2_mini_v1.0.0.pdf)

A “3-pin” MX switch has two metal electrical terminals and one plastic locating post. A “5-pin” version adds two plastic stabilizing posts. Solder to the **metal terminals**, not the plastic posts or optional LED contacts. With the board unplugged, a multimeter across the switch terminals should show open circuit when released and continuity when pressed.

1. Verify the switch and cap on the printed plate coupon first, then clip the switch into the final lid. Leave the keycap off while soldering and support the lid without loading the stem.
2. Tin the wire ends and the two switch terminals, then solder one wire to each. Follow the switch manufacturer's soldering limits; avoid holding heat on the plastic body. Use the soldering kit's stand, ventilation and eye protection.
3. Solder the other wire ends to GPIO4 and GND on the board. Short stripped ends and small joints are easier to insulate in the enclosure. No headers are needed.
4. Cover bare joints with heat-shrink or insulating tape, inspect for solder bridges, and check that pressing the key closes only the intended GPIO-to-ground path.
5. Flash and test with the enclosure open, then route wires clear of the stem, plate clips, USB connector and screws. Leave a little lid service slack without allowing wire to sit on top of board components.

## Check your particular S2 Mini

The [reference board dimensions](https://docs.wemos.cc/en/latest/_static/files/dim_s2_mini_v1.0.0.pdf) and pin labels describe the WEMOS/LOLIN design. The [selected seller listing](https://www.aliexpress.us/item/3256812318584460.html) shows an S2 Mini V1.0.0 with two dedicated mounting holes near the antenna. The revised enclosure uses those holes with M1.6 screws; it does not cover or fasten through the 32 electrical header holes. Boards sold as “S2 Mini” can differ in PCB outline, USB socket position and component heights. Measure the actual board and inspect both sides before printing the finished shell. See the [mounting layout](enclosure.md) and [component accuracy record](component-accuracy.md). The included design assumes no tall soldered headers. A board with a USB-to-UART bridge rather than native S2 USB will not enumerate as this firmware expects.

The USB socket must have clearance for the **cable's molded plug**, not only the metal connector. Test that the cable seats fully before tightening the case. Keep access to the board's BOOT and RESET buttons during development. See [firmware build/flash instructions](../firmware/README.md).

## First bench test — still required

This project has not yet been soldered or physically printed and fitted. Complete these checks before using the gift for real reviews:

- With the Mac companion in dry-run mode, connect the board while the key is held. There should be **no action**. Release it and make a fresh press.
- Check one event per press, no repeated event while held, and deliberate separate presses working normally.
- Unplug, hold the key, reconnect: again no action until release then press. Repeat after sleep/wake and restarting the companion.
- Open a throwaway PR in the frontmost Chrome window and inspect the dry-run target. Then try another Chrome tab, another window, and a different foreground app; verify the selected target and guard behavior.
- Only after the preview is correct, enable live actions and press on a test PR that the authenticated user did **not** author. Verify one review with body exactly `blocked`.
- Finally fit the lid, confirm the key travels freely and the cable seats fully, then add the feet or removable desk pad.
