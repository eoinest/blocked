# USB-C opening and cable fit

The nominal opening is **13.5 mm wide × 7.6 mm high**, with **0.7 mm corner radii**, centered at **z = 8.7 mm**. It passes through the entire USB-side wall. An outer lead-in extends **0.4 mm** into the wall and widens the opening by **0.25 mm per side** at the exterior. These are prototype enclosure dimensions, not measurements of the user's board or cable.

The opening clears a cable plug's overmold, rather than tightly wrapping the receptacle's metal shell. There is no smaller inner web that could stop the cable shoulder before the plug seats. The existing PCB position, supports, mounting holes and USB-side controls remain the reference assembly geometry.

## What the primary sources establish

The [USB-IF Type-C Cable and Connector Specification, Release 2.4, October 2024](https://e2e.ti.com/cfs-file/__key/communityserver-discussions-components-files/196/USB-Type_2D00_C-Spec-R2.4-_2D00_-October-2024.pdf), hosted by Texas Instruments, gives these interface dimensions:

| Feature | Specified dimension | Location |
| --- | --- | --- |
| Plug metal width | 8.25 ± 0.03 mm | Figure 3-3, page 54 |
| Plug metal height | 2.40 ± 0.03 mm | Figure 3-3, page 54 |
| Plug metal length | 6.65 ± 0.10 mm | Figure 3-3, page 54 |
| Exposed plug shell | 6.51 mm minimum | Figure 3-3, page 53 |
| Plug overmold envelope | 12.85 mm maximum × 7.0 mm maximum | Figure 3-3, page 54 |
| Fully seated overmold-to-product clearance | 0.05 mm minimum axial gap; 0.05 mm each side in a recess | Informative Figure 3-82, page 147 |

The [USB-IF specification landing page](https://usb.org/usb-type-cr-cable-and-connector-specification) describes the standard and links its document library. The older 12.35 × 6.5 mm overmold allowance is not the envelope used here.

These dimensions do **not** identify the clone's receptacle. The [official WEMOS schematic](https://docs.wemos.cc/en/latest/_static/files/sch_s2_mini_v1.0.0.pdf) labels it `USB_C_16P`, without a connector manufacturer's part number. A receptacle's outside shell, PCB mounting height and length depend on the selected part. For example, [GCT USB4105](https://gct.co/connector/usb4105) has a published 3.31 mm profile and 7.35 mm body length; an [Amphenol receptacle drawing](https://cdn.amphenol-cs.com/media/wysiwyg/files/drawing/10168357.pdf) shows an 8.94 × 3.16 mm shell. Neither part is confirmed on the user's board.

## Why there is no tight inner bezel

The current illustrative model places the PCB edge at y = 18.65 mm and the socket lip at y = 18.95 mm, **2.05 mm behind** the exterior wall at y = 21 mm. Its 9.2 × 7.3 × 3.2 mm socket body and 0.3 mm PCB overhang are photo-based assumptions.

A 0.8 mm web starting just beyond the PCB at y = 18.75 mm would end at y = 19.55 mm, projecting 0.6 mm beyond the modeled socket lip. The standard's product-clearance recommendation does not establish that an actual seated cable leaves that much space ahead of this receptacle. A smaller opening there could let the metal tip enter while preventing complete electrical engagement. A future shell-shaped bezel needs the actual seated cable shoulder position, shell dimensions and board placement measured together.

## Corner clearance and coupon

For the nominal opening, a centered **12.85 × 7.0 mm rectangular envelope** fits inside the rounded corners, even without assuming the overmold itself is rounded. Straight-side margins are 0.325 mm horizontally and 0.300 mm vertically. At the closest corner, the distance from the corner-arc center is `sqrt(0.375² + 0.400²) = 0.5483 mm`, below the 0.7 mm radius, leaving approximately **0.1517 mm radial clearance**. These are CAD clearances; extrusion error and cable misalignment consume them.

The USB coupon is an upright **54 × 2 × 17.4 mm wall** on a **54 × 8 × 2 mm foot**. Its openings sit at z = 8.7 mm and reproduce the case's corner radius and entrance geometry. One, two or three notches on the top edge identify these openings:

| Notches | Width × height | Purpose |
| --- | --- | --- |
| 1 | 13.3 × 7.4 mm | Tight comparison; only about 0.010 mm nominal corner clearance to the full rectangular envelope |
| 2 | 13.5 × 7.6 mm | Nominal enclosure opening |
| 3 | 13.7 × 7.8 mm | More printing and cable clearance |

Print the coupon upright on its foot, using the same material and slicer settings as the case. This reproduces the case's vertical opening and bridging across its roof; printing the coupon flat would miss possible bridge sag. Choose an opening that admits the **actual cable overmold freely**, without forcing or scraping. The coupon checks opening size and print behavior; it cannot by itself prove axial seating against the board.

Before final assembly, seat the cable directly in the bare board and note its shoulder position. Repeat with the board mounted in the case: the shoulder must not stop on the enclosure before reaching the same seated position. Check both cable orientations, USB enumeration and light cable movement. If an unusually large overmold or printing variation does not fit, enlarge the opening rather than forcing the cable against the board connector. Exact clone fit remains unverified until this physical check is completed.
