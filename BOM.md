# Shopping list — one blocked button

The revised enclosure uses **four screws and four nuts from your ordered
Maierke kit**. No heat-set inserts or additional mounting hardware are needed.
The fewest-orders route found is one Amazon checkout plus the custom Tab keycap
order; separate Amazon sellers may ship separate parcels. See the
[consolidated shopping plan](docs/amazon-shopping.md).

This is a prototype: measure the delivered fasteners and print the fit coupons
before the finished shell. [Fastener dimensions and fit checks](docs/fastener-fit.md).

## Remaining purchases

| Need | Direct product link | Exact selection / quantity |
| --- | --- | --- |
| 1 keycap | [Max Keyboard custom printed **1.5u Tab**](https://maxkeyboard.com/custom-art-icon-or-text-cherry-mx-keycaps.html) | **R3 1x1.5 (Tab / \|)**, White, TOP Print only; lowercase `blocked`. **$11**. [Artwork + settings](keycap/README.md). |
| 1 switch | [Gateron Baby Kangaroo 2.0 — Amazon](https://www.amazon.com/dp/B0CM347W2W) | **Baby Kangaroo 2.0, 10Pcs**, 5-pin MX style. **$7.99**; use one. |
| 4 feet | [METFUIN adhesive rubber sheets — Amazon](https://www.amazon.com/dp/B0FJ8WV32F?th=1) | **Black, 1/25 Thick 6X6 inch, two sheets**, **$6.99**. Cut four 8 × 8 mm pads with rounded corners. Selected thickness is nominally 1.016 mm; verify on delivery. |

Total: **$25.98 before shipping/tax**, assuming supplies below are already owned.
Prices and selections checked September 5, 2026; prices may change. The feet's
adhesive attaches to the case; exposed rubber grips the desk by friction.

## Covered by your ordered kits

| Use | Quantity per button | Source |
| --- | --- | --- |
| PCB mounting | **2 × M1.6 × 4 socket-cap screws + 2 × M1.6 nuts** | [Maierke 1050-piece kit](https://www.amazon.com/dp/B0GKFMJH24?th=1), nuts listed as 3.5 mm across flats |
| Case closure | **2 × M2 × 8 socket-cap screws + 2 × M2 nuts** | Same Maierke kit, nuts listed as 4 mm across flats |
| M3 assortment | None needed for this design | [Weideer kit](https://www.amazon.com/dp/B0DS8HYF64?th=1); keep for other projects |

Both screw lengths are measured **under the head**. Use a **1.5 mm hex key**
if the delivered sockets match the nominal sizes. No washers are used in this
stack. PCB screws pass through its two dedicated mounting holes; all 32 GPIO
holes remain separate. The switch's plate clips and the cap's MX socket need
no extra screws, stabilizer, hot-swap socket or circuit board.

## Buy only if missing

| Need | Direct product link | Selection / quantity |
| --- | --- | --- |
| Two wires + joint insulation | [Fermerry wire and heat-shrink bundle — Amazon](https://www.amazon.com/dp/B089CXFH4H?th=1) | **30 AWG-6C, 25FT per color**, **$10.29**. Includes 18 pieces of Ø2.4 mm tubing; verify it shrinks tightly enough to stay over each joint. Leave a lid service loop. |
| USB data cable | [UGREEN USB-C to USB-C — Amazon](https://www.amazon.com/dp/B0BPXKJSWY) | **1.6 ft, 3-pack**, USB 2.0 data. Use one; reuse a suitable existing cable first. Price not verified. |
| Hex driver | [Wera 05073593001 metric hex-key set — Amazon](https://www.amazon.com/dp/B009ODV0OE) | Includes **1.5 mm**; reuse an existing matching driver if available. Price not verified. |
| Solder | [Adafruit 0.5 mm rosin-core lead-free solder](https://www.adafruit.com/product/2473) | **$12.50 / 50 g**; only a small amount needed. Check the soldering kit first. |
| Filament | [Overture PLA, Metallic Gray](https://overture3d.com/products/overture-pla?variant=46749457744126) | **1.75 mm / 1 kg**, **$25.29**; reuse existing PLA/PETG and check printer compatibility. |

The wire bundle brings the total to **$36.27 before shipping/tax**. Other
optional supplies are excluded. Check that the USB plug seats fully through
the **16 × 10 mm rear opening**; data capability alone does not establish
mechanical fit.

## Already owned / print

- **Owned:** ESP32-S2 Mini ([your listing](https://www.aliexpress.us/item/3256812318584460.html); [LOLIN reference](https://www.wemos.cc/en/latest/s2/s2_mini.html)), soldering kit, 3D printer. The seller's board is not verified as manufactured by LOLIN.
- **Print first:** [switch coupon](enclosure/stl/fit-coupon.stl), [M2 case-fastener coupon](enclosure/stl/case-fastener-coupon.stl), and [M1.6 board-fastener coupon](enclosure/stl/board-fastener-coupon.stl).
- **Print after fitting:** [base](enclosure/stl/base.stl) and [lid](enclosure/stl/lid.stl). No paint is required.

[Mounting and assembly](docs/enclosure.md) · [Key mounting](docs/key-mounting.md) ·
[Wiring](docs/hardware.md) · [Measurements still needed](docs/component-accuracy.md).
