# Shopping list — one blocked button

For the two Amazon fastener kits already ordered, see the
[consolidated Amazon shopping plan](docs/amazon-shopping.md). The fewest-orders
route found is one Amazon checkout plus the custom Tab keycap order, **conditional
on revising and validating the enclosure for captive nuts and socket-head screws**.
The current Blender/STL files still use the heat-set inserts and screws below.

## Parts for the current CAD

| Need | Selected part | Purchase note |
| --- | --- | --- |
| 1 keycap | [Max Keyboard custom printed **1.5u Tab**](https://maxkeyboard.com/custom-art-icon-or-text-cherry-mx-keycaps.html) | Select **R3 1x1.5 (Tab / \|)**, White, TOP Print only; print `blocked`. **$11**. [Artwork + order settings](keycap/README.md). |
| 1 switch | [Gateron Baby Kangaroo V2](https://milktooth.com/products/baby-kangaroo) | **$5.50 per 10-pack**; use one, keep nine spares. |
| 2 case screws | [BelMetric M2 × 8 mm Phillips countersunk](https://belmetric.com/phillips-flat-head-stainless-m2x0-4-coarse-din-965/) | Select **8 mm**, SKU **MSF2X8SS**; **M2 × 0.4**, 90° head, 3.8 mm diameter, **PH1** driver. Length includes head. Insert from underneath to close the case. |
| 2 threaded inserts | [CNC Kitchen M2 × 3 mm heat-set inserts](https://cnckitchenus.store/products/heat-set-insert-m2-x-3-100-pieces) | **TC-M2x3.0**, **3.6 mm outside diameter**, **$11.50 / 100-pack**, US stock. Heat-set one into each lid post for the case screws. |
| 2 PCB screws | [CNC Kitchen M1.6 × 4 mm low-head TX5](https://cnckitchenus.store/products/m1-6-screw-tx5-stainless-steel-aisi-304-low-head?variant=48314244333668) | Select **M1.6x4 — 25 pcs**, **$3.80**; 2.93 mm head diameter, 1 mm head height. **4 mm is measured under the head**. These pass through the board's two dedicated 2 mm holes. |
| 2 PCB inserts | [CNC Kitchen M1.6 × 2.5 mm heat-set inserts](https://cnckitchenus.store/products/heat-set-insert-m1-6-100-pieces-kopie) | **2.5 mm outside diameter**, **$11.50 / 100-pack**. Heat-set into the two base standoffs. |
| 4 pads | [beekeeb rubber feet — Type D](https://shop.beekeeb.com/products/rubber-feet-for-split-keyboard) | Select **Type D**, **$1 / 9 pieces**, each **20 × 15 × 1 mm**; Hong Kong seller. Cut four **8 × 8 mm** pads and round the corners to fit the pockets. |

Keycap + switch pack + both insert packs + PCB screw pack: **$43.30 before case screws, feet, shipping and tax**.
Links and listed prices checked September 5, 2026. Quantities are for one
finished button; retailers may sell larger packs. Shipping/tax are additional.
The rubber feet grip the desk by friction; their adhesive attaches them to the
case. Feet ship internationally; postage can exceed their price. Reuse matching
supplies when possible. The PCB mounts through its **two dedicated holes**;
none of the 32 electrical pin holes are used for fastening. Check the
[board measurements](docs/component-accuracy.md) before the final print.

## Buy only if missing

| Need | Direct product link | Selection / quantity |
| --- | --- | --- |
| 1 USB data cable | [Adafruit USB-C to USB-C, 1 m](https://www.adafruit.com/product/4199) | For a Mac with USB-C. **$9.95**. For a USB-A port, use [this A-to-C cable](https://www.adafruit.com/product/4474) instead. |
| 2 short wires | [Adafruit 30 AWG silicone stranded wire](https://www.adafruit.com/product/3166) | **$4.95 / 50 ft spool**. Cut two short lengths; one color is sufficient. |
| Joint insulation | [Adafruit heat-shrink assortment](https://www.adafruit.com/product/4559) | **$9.95 / 280 pieces**. Use small tubing that covers each exposed switch joint. |
| Solder | [Adafruit 0.5 mm rosin-core lead-free solder](https://www.adafruit.com/product/2473) | **$12.50 / 50 g spool**; only a small amount needed. |
| Enclosure filament | [Overture PLA, Metallic Gray](https://overture3d.com/products/overture-pla?variant=46749457744126) | **1.75 mm / 1 kg**, **$25.29**; reuse existing gray PLA/PETG if available. Check your printer's filament diameter. |
| PCB screwdriver | [Wiha T5 precision screwdriver](https://www.wihatools.com/products/precision-torxr-t5-x-40mm-single-pack) | **$8.02**; reuse a T5/TX5 bit if owned. The case screws use PH1. |

The cable supports data, but its plug-body dimensions are not published on the
listing. Check it seats fully through the case's **16 × 10 mm rear opening**
before final assembly. Small supplies can share one Adafruit order.

## Already owned / print

- **Already owned:** ESP32-S2 Mini ([your exact listing](https://www.aliexpress.us/item/3256812318584460.html); [LOLIN reference](https://www.wemos.cc/en/latest/s2/s2_mini.html)), soldering kit, 3D printer. The seller's board is not verified as manufactured by LOLIN.
- **Print:** [base](enclosure/stl/base.stl) + [lid](enclosure/stl/lid.stl), with the
  [switch coupon](enclosure/stl/fit-coupon.stl), [M2 insert coupon](enclosure/stl/insert-coupon.stl), and [M1.6 insert coupon](enclosure/stl/board-insert-coupon.stl) first. No paint is required for this BOM.

Mounting and screw installation: [enclosure guide](docs/enclosure.md).
The switch uses its existing plate clips and the cap uses its MX socket;
the integral lid ribs add no purchased parts. [Key mounting and service](docs/key-mounting.md).
Electrical assembly: [hardware guide](docs/hardware.md).
