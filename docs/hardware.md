# Build the physical key

For the gift, my pick is one **Gateron Baby Kangaroo 2.0**, a **1.5u MX-compatible keycap** printed or engraved with `blocked`, and your S2 Mini. Gateron describes an early, strong tactile action with nominal 59 ± 8 gf operating force and a five-pin MX structure. That is a good direction for a deliberate, satisfying one-purpose press; the exact feel still needs a sample in your hand. [Gateron product page](https://www.gateron.com/products/gateron-baby-kangaroo-20-tactile-switch-set)

**CHERRY MX2A Brown** is the easy-to-source, gentler alternative. It has 2 mm pre-travel and 4 mm total travel; CHERRY lists 45 cN actuation and 55 cN at the tactile peak. It is a soft bump, so choose the Baby Kangaroo if the gift should feel more emphatic. The wider 1.5u cap still uses one centered switch; choose a cap with a single centered MX stem and check off-center presses. [CHERRY Brown specifications](https://www.cherry.de/fr-fr/produit/mx2a-brown)

Feel is personal. A single-switch sample or small tester is more useful than buying an entire keyboard's worth for this project. The printed enclosure changes the sound too. Use a manufactured cap for the nicest finger surface and durable stem; an FDM cap is fine for experimenting with the legend and shape. Choose standard MX switches with **metal electrical contacts**; optical, Hall-effect, and inductive variants require different electronics.

## Switch shortlist

| Choice | Feel and action | Enclosure/keycap impact |
| --- | --- | --- |
| **Gateron Baby Kangaroo 2.0 — gift recommendation** | Strong early tactile bump; manufacturer rates operation at 59 ± 8 gf. | Five-pin MX structure, same two-contact wiring. Validate plate coupon and cap clearance. [Manufacturer](https://www.gateron.com/products/gateron-baby-kangaroo-20-tactile-switch-set), [drawing](https://gateron.com/u_file/2308/29/file/GATERONBabyKangaroo20Switch-b4b5.pdf) |
| **Kailh BOX White — crisp click** | Click bar, nominal 45 gf operation and 55 gf tactile force, 3.6 mm total travel. | Standard-height MX-style option; sample first if noise matters. [Manufacturer](https://www.kailh.net/collections/all-products/products/kailh-box-switch-set) |
| **Kailh BOX Jade — emphatic click** | Thick click bar, nominal 50 gf operation and 75 gf tactile force, 3.6 mm total travel. | A firmer, louder-feeling choice for the joke; verify snap fit. [Manufacturer](https://www.kailh.net/products/kailh-box-thick-clicky-switch-set) |
| **CHERRY MX2A Brown — mild alternative** | Soft tactile bump; 2 mm to actuation, 4 mm total. | Standard MX plate and cap. [Manufacturer](https://www.cherry.de/en-us/product/mx2a-brown) |
| **CHERRY MX2A Blue — familiar click** | Tactile and audible click; 2.2 mm pre-travel, 4 mm total. | Same standard MX family; validate the snap fit with the coupon. [Manufacturer](https://www.cherry.de/en-us/product/mx2a-blue) |
| **Kailh Choc V2 Brown — thinner redesign** | Tactile; 1.3 ± 0.3 mm pre-travel, 3.2 ± 0.25 mm total, nominal 45 ± 10 gf operation. | Requires a Choc-specific mounting redesign and verified cap clearance. An MX-style stem does not make the whole housing MX-compatible. [Manufacturer](https://www.kailh.net/products/kailh-choc-v2-low-profile-switch-set) |

The included enclosure targets standard MX. Low-profile switches save less overall height when the S2 Mini remains stacked underneath; a side-by-side board layout can make a flatter but wider version. Do not substitute Choc V1 caps or mounts for V2 by assumption.

## Wider keycap

The revised design uses a **1.5u Tab-width cap**, with a tapered ivory body and
a small lowercase `blocked` legend at the front-left of the top surface. Tab
is a standard 1.5u position in [Omnitype's size guide](https://intercom.help/omnitype/en/articles/5121683-keycap-sizes).
The render uses an approximately 28 mm-wide cap, compared with the original
18 mm square reference; exact dimensions depend on the purchased cap.

[Signature Plastics sells individual blank DSA 1.5u caps](https://spkeyboards.com/products/sp-dsa-1-5-space),
so a whole keycap set is not needed. DSA gives a lower, uniform profile; a
[blank SA 1.5u cap](https://spkeyboards.com/products/sp-sa-1-5-space) gives a taller,
more sculpted option. Select a light color and a single centered MX stem, and
confirm stock and the chosen profile before ordering. The Blender cap is a
visual reference, not an exact model of either supplier's cap.

Use a small vinyl/waterslide legend for the prototype or ask a custom keycap
printer to print `blocked` in charcoal at the front-left. The housing still
holds one switch and the wiring is unchanged. Check that the cap returns
freely when pressed near either end; do not substitute a 2u cap without
revisiting stabilizers and clearances.

## Parts

| Quantity | Part | Notes / source |
| --- | --- | --- |
| 1 | ESP32-S2 Mini, preferably headerless | Existing board. The reference is LOLIN S2 Mini: USB-C, 3.3 V GPIO, 34.3 × 25.4 mm. [WEMOS](https://docs.wemos.cc/en/latest/s2/s2_mini.html) |
| 1 (+ spare) | Mechanical MX switch | Baby Kangaroo 2.0 sample/small pack, or CHERRY MX2A Brown e.g. [single-switch listing at SparkFun](https://www.sparkfun.com/cherry-mx2a-keyswitch-brown.html). Check current availability; no purchase is required to build the software. |
| 1 | 1.5u MX cross-stem keycap | Ivory/white, centered single stem, sculpted or uniform profile; add a small charcoal `blocked` legend. See the keycap notes above. |
| 2 | Short insulated stranded wires | About 28–30 AWG; cut to fit with enough slack to lift the lid. |
| As needed | Heat-shrink and thin insulating tape | Cover switch joints and any exposed wire. Avoid conductive metallic tape. |
| 4 small squares | 1 mm insulating double-sided foam tape | Retains the board on the support pads. Place only against clear PCB areas after inspecting both sides. |
| 1 | Data-capable USB-C cable | Short flexible cable and slim plug suit a small desk key. |
| 2 | M2 × 8 mm 90° countersunk screws | Match the supplied enclosure; see [enclosure guide](enclosure.md). |
| 1 set | Printed enclosure parts | [Enclosure source and assembly guide](enclosure.md). |
| 4 | Thin adhesive silicone feet | 8 mm square × 1 mm thick to suit the enclosure recesses; these stop sliding without bonding the whole key to the desk. |
| Optional | Small removable double-sided adhesive pad | For true desk attachment. Test on the desk finish first; avoid permanently bonding the lid shut. |

A USB-powered one-switch build needs **no battery, external resistor, diode, keyboard PCB, or separate USB interface board**. A diode matters for keyboard matrices; there is no matrix here. Hot-swap sockets are optional, but unsupported loose sockets are less robust than two soldered wires for this small gift.

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

1. Fit the switch in the printed plate coupon first. Leave the keycap off while soldering.
2. Tin the wire ends and the two switch terminals, then solder one wire to each. Follow the switch manufacturer's soldering limits; avoid holding heat on the plastic body. Use the soldering kit's stand, ventilation and eye protection.
3. Solder the other wire ends to GPIO4 and GND on the board. Short stripped ends and small joints are easier to insulate in the enclosure. No headers are needed.
4. Cover bare joints with heat-shrink or insulating tape, inspect for solder bridges, and check that pressing the key closes only the intended GPIO-to-ground path.
5. Flash and test with the enclosure open, then route wires clear of the stem, plate clips, USB connector and screws. Leave a little lid service slack without allowing wire to sit on top of board components.

## Check your particular S2 Mini

The [reference board dimensions](https://docs.wemos.cc/en/latest/_static/files/dim_s2_mini_v1.0.0.pdf) and pin labels describe the WEMOS/LOLIN design. Boards sold as “S2 Mini” can differ in PCB outline, USB socket position, component heights, and assembly quality. Measure your board and inspect both sides before printing the finished shell. The included design assumes no tall soldered headers; foam and support positions must not crush components or bridge solder joints. A board with a USB-to-UART bridge rather than native S2 USB will not enumerate as this firmware expects.

The USB socket must have clearance for the **cable's molded plug**, not only the metal connector. Test that the cable seats fully before tightening the case. Keep access to the board's BOOT and RESET buttons during development. See [firmware build/flash instructions](../firmware/README.md).

## First bench test — still required

This project has not yet been soldered or physically printed and fitted. Complete these checks before using the gift for real reviews:

- With the Mac companion in dry-run mode, connect the board while the key is held. There should be **no action**. Release it and make a fresh press.
- Check one event per press, no repeated event while held, and deliberate separate presses working normally.
- Unplug, hold the key, reconnect: again no action until release then press. Repeat after sleep/wake and restarting the companion.
- Open a throwaway PR in the frontmost Chrome window and inspect the dry-run target. Then try another Chrome tab, another window, and a different foreground app; verify the selected target and guard behavior.
- Only after the preview is correct, enable live actions and press on a test PR that the authenticated user did **not** author. Verify one review with body exactly `blocked`.
- Finally fit the lid, confirm the key travels freely and the cable seats fully, then add the feet or removable desk pad.
