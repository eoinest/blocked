# Consolidated shopping plan

Listings checked September 5, 2026. Prices exclude shipping and tax and can change.
No purchases have been made by the project.

The fewest-orders route found is **one Amazon checkout plus one Max Keyboard
order**, assuming solder, filament, a suitable driver and a USB data cable are
already available. It reuses the nuts and screws in the small fastener kit already
ordered. The revised Blender/STL files contain captive-nut pockets and flat-bottom
cap-head recesses. Measure the actual kit and fit the coupons before printing
the finished case. Separate Amazon sellers may
still ship in separate packages.

## Remaining purchases

| Buy once | Exact selection | Covers | Listed price |
| --- | --- | --- | --- |
| [Gateron Baby Kangaroo 2.0 switches — Amazon](https://www.amazon.com/dp/B0CM347W2W) | **10Pcs**, **Baby Kangaroo 2.0**, 5-pin mechanical MX style | One switch; nine spares. Same switch family selected for the model. Ships from Amazon, sold by kutethy at inspection. | **$7.99** |
| [METFUIN adhesive rubber sheets — Amazon](https://www.amazon.com/dp/B0FJ8WV32F?th=1) | Black, **1/25 Thick 6X6 inch**, two sheets | Cut four **8 × 8 mm** pads with rounded corners. Nominal thickness **1.016 mm**, close to the modeled 1 mm feet. Ships from Amazon. | **$6.99** |
| [Fermerry wire and insulation bundle — Amazon](https://www.amazon.com/dp/B089CXFH4H?th=1), **only if missing** | **30 AWG-6C**, **25FT** per color | Six colors of flexible tinned-copper silicone wire, **18 pieces of 2.4 mm heat-shrink tubing**, and 18 ties. Only two short wires and two joint sleeves are needed. Ships from Amazon, sold by Fermerry Technology. | **$10.29** |
| [Max Keyboard custom Tab keycap](https://maxkeyboard.com/custom-art-icon-or-text-cherry-mx-keycaps.html) | **R3 1x1.5 (Tab / \|)**, White, TOP Print only, `blocked` | One custom **1.5u Tab** cap, MX stem. Use the [existing artwork and settings](../keycap/README.md). Separate merchant order. | **$11.00** |

Amazon subtotal: **$14.98**, or **$25.27** with the wire bundle.
Including the custom cap: **$25.98**, or **$36.27** with the wire bundle,
before shipping/tax and any other missing supplies.

The rubber listing's selected variant is 1/25 inch; its generic dimensions table
disagrees. Check the delivered thickness before cutting. Its adhesive fixes the
feet to the case; the exposed rubber grips the desk by friction.

The wire listing specifies **0.8 mm insulation OD**, within the current 0.9 mm
wire envelope. The included tubing's shrink ratio is unpublished: check that it
stays over each soldered switch terminal without sliding and clears nearby
components. Do not count loose tubing as secure joint insulation.

No exact Amazon listing was verified for the required white, custom-printed
**1.5u Tab** cap. Personalized square caps and blank 1.5u caps do not meet that
requirement. A switch sampler also does not reliably include the selected switch;
the small matching pack is the useful purchase here.

## Reuse the ordered assortment

| Already ordered | Use per button | Compatibility status |
| --- | --- | --- |
| [Maierke 1050-piece M1.4/M1.6/M2/M2.5 socket-cap screw, nut and washer kit](https://www.amazon.com/dp/B0GKFMJH24?th=1) | **2 × M1.6 × 4 screws + 2 × M1.6 nuts** for the PCB; **2 × M2 × 8 screws + 2 × M2 nuts** for the case | The selected kit includes these threads and lengths. Nut thickness and screw-head dimensions still need measurement. The revised CAD includes nut pockets and flat-bottom screw recesses; physical fit is still unverified. |
| [Weideer 2322-piece M3 kit](https://www.amazon.com/dp/B0DS8HYF64?th=1) | No parts required for this enclosure | M3 is too large for the board's two dedicated mounting holes. Keep for other projects. |

Do not buy another fastener assortment for this route. The switch clips
into its printed plate and the cap presses onto the MX stem; neither needs extra
screws or a stabilizer.

## Revised mounting

The current enclosure replaces all four heat-set inserts with side-loading hex
nut pockets. The PCB still uses its two dedicated holes; the case closes with
socket-cap screws in flat-bottom recesses. Locally thickened floor pads retain
plastic above those recesses. No additional fasteners or washers are required.

Print the [M1.6 board coupon](../enclosure/stl/board-fastener-coupon.stl) and
[M2 case coupon](../enclosure/stl/case-fastener-coupon.stl) first. Both screws'
lengths exclude the heads. Verify head size, nut thickness, full engagement and
printed pocket fit against the delivered kit. The side slots remain open for
nut insertion/removal: handle the loose nuts carefully during disassembly.
See [assembly instructions](enclosure.md) and the [fastener audit](fastener-fit.md).

Check existing soldering supplies, filament, USB data cable and matching hex
driver before placing the Amazon order. These are excluded from the totals above.
Standard M1.6 and M2 socket-cap screws both take a **1.5 mm hex key**
([supplier sizing table](https://www.modelfixings.co.uk/tools.htm)); check the
delivered kit matches. If that size is missing from existing tools, the
[Wera 05073593001 nine-piece metric set on Amazon](https://www.amazon.com/dp/B009ODV0OE)
includes it. US price was not verified; add it to the same checkout only if needed.
