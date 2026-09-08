# USB-C socket collar and fit cradle

The revised **9.6 × 3.6 mm rounded opening, R1.65**, follows the nominal **9.2 × 3.2 mm, R1.45** metal socket with **0.2 mm clearance per side**. Its center is z = 8.7 mm. This is a socket-shaped collar inside a recess, replacing the previous plug-sized through-hole.

A **13.5 × 7.6 mm outer recess**, R0.7, gives the cable body room to approach the collar. Its exterior lead-in is 0.4 mm deep and widens by 0.25 mm per side. Four PCB supports and all bottom-entry screws are retained.

**Prototype fit condition:** the fully seated cable's plastic shoulder must sit at least **0.35 mm ahead of the actual socket lip**, assuming the modeled socket position. This is a required clearance, not a measurement of the user's cable. The physical board and seated cable must be tested before treating this as a confirmed fit.

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

USB-IF §3.2.1, note 7, printed page 46 recommends a **6.20 ± 0.20 mm effective receptacle shell length at system level**. This does not grant a universal 0.30 mm forward bezel allowance. The collar therefore remains conditional on the measured cable shoulder position.

## Collar depth and PCB clearance

The nominal PCB edge is at y = 18.65 mm and socket lip at y = 18.95 mm. The collar face sits at **y = 19.25 mm**, 0.30 mm ahead of that lip and 1.75 mm behind the case exterior. The cable shoulder must remain at or beyond y = 19.30 mm to provide 0.05 mm axial clearance.

The reinforced frame extends back to y = 18.05 mm. A backside PCB-edge relief ends at y = 18.75 mm, spanning z = 5.3–7.3 mm. It clears the nominal board and leaves a **0.5 mm lower lip**; the top and sides retain 1.2 mm depth. Inspect the small lip in the slicer and after printing. It must not press on the PCB or socket.

The actual socket's outer profile, height above the board and 0.3 mm overhang remain photo-derived assumptions. The collar's 0.2 mm clearance is a starting print allowance. It is not a zero-clearance press fit, nor proof that every clone or cable fits.

## Test the fit cradle before printing the case

[usb-fit-coupon.stl](../enclosure/stl/usb-fit-coupon.stl) is now a **30 × 42 × 14 mm cradle** with the same four PCB supports, two mounting holes, recessed collar and rear opening as the case. It replaces the previous three-hole cable gauge. Registering the actual board on its mounting holes lets this print test both the socket outline and cable seating depth.

1. On the Bambu A1, print the cradle floor-down with the same filament, nozzle and layer settings intended for the base. With a 0.4 mm nozzle, start with PLA, 0.16 mm layers and four walls. Inspect the thin collar lip and bridge above the port in the slicer; print dimensions are subject to extrusion and shrinkage.
2. With USB disconnected, rest the actual board on all four pads. Use the same two M1.6 × 6 mm bottom-entry screws and exposed M1.6 nuts. Do not pull the board into alignment by tightening the nuts.
3. The socket should enter the rounded collar freely, without bending the board or rubbing the metal shell. Check the underside relief clears the PCB and solder joints.
4. Compare the cable's fully seated position in the bare board against its position in the cradle. The plastic shoulder must not bottom against the collar before the plug seats. Check both plug orientations and USB enumeration. Enumeration alone does not prove full seating.
5. If the collar is tight or blocks seating, stop and update its dimensions from measurements before printing the full case. A tighter profile must not be obtained by forcing the connector against the board.

The combined STL with coupons includes this cradle. The nominal geometry audit checks the required shoulder plane and plug path; it explicitly does not certify that the actual cable meets that plane.
