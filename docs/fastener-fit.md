# Exposed-nut fastener audit

This revision replaces the covered nut traps after feedback from the assembled prototype. Every screw enters from the bottom; every nut rests on an open top surface. The board nuts are exposed when the lid is removed, and case nuts are exposed on the lid.

## Nominal stack

All dimensions are millimetres; screw length is measured under the head.

| Feature | PCB | Case |
| --- | --- | --- |
| Quantity | 2 screws + 2 nuts | 2 screws + 2 nuts |
| Screw | **M1.6 × 6**, pitch 0.35 | **M2 × 20**, pitch 0.4 |
| Head envelope diameter × height | 3.2 × 1.7 | 4.0 × 2.1 |
| Bottom entry diameter | 3.6 | 4.4 |
| Head bearing height | z = 2.8 | z = 4.4 |
| Head bottom | z = 1.1 | z = 2.3 |
| Continuous plastic over head recess | 2.7 to PCB underside | 1.8 to local pad top |
| Nut bearing surface | PCB top z = 7.1 | Lid top z = 22.0 |
| Nut assumed AF × thickness | 3.5 × 1.3 | 4.0 × 1.6 |
| Nut top | z = 8.4 | z = 23.6 |
| Screw tip | z = 8.8 | z = 24.4 |
| Nominal protrusion beyond nut | **0.4** | **0.8** |
| Shaft clearance diameter | 1.8 in base, existing 2.0 PCB hole | 2.2 |

For both families: `tip = head_bearing_height + under_head_length` and `protrusion = tip − nut_top`. The modeled screws fully traverse the nut thickness. There is no blind screw-tip cavity. The case guide posts stop at z = 6.5, leaving 0.3 mm above the base pads; the case rim sets closure height.

The old **M1.6 × 4 / M2 × 8 screws are too short for these released stacks**. Check the [ordered Maierke kit](https://www.amazon.com/dp/B0GKFMJH24?th=1) for the new lengths; their inclusion has not been verified. Nut size/head geometry remain reference assumptions. Standard M1.6 nuts can have 3.2 mm rather than the kit-listed 3.5 mm flats; exposed seating removes dependence on a tight hex pocket, but nut bearing coverage and thickness still need checking.

Reference head envelopes and drives come from [Monster Bolts M1.6](https://monsterbolts.com/pages/m1-6-bolt-size), [M2](https://monsterbolts.com/pages/m2-bolt-size), and [Accu M1.6](https://www.accu.co.uk/metric-cap-head-screws/250388-SSCF-M1-6-3-A2-R360). Nut thickness ranges are recorded by [Westfield DIN934](https://www.westfieldfasteners.co.uk/Standards/Nut_Hex_M.html). These references do not certify the actual kit.

## Access and support

Hold the exposed nuts with fine pliers while using a 1.5 mm hex key from underneath. Remove the keycap for case-nut gripping: the approximately 0.69 mm nominal lateral cap gap is component clearance, not assured tool clearance. No captive slots, glue, heat-set inserts or washers are used.

Feet move to x = ±17, y = ±15, keeping the new PCB head entries clear. All four PCB support tops are at z = 5.5. Two screw posts use the documented mounting holes; two plain 2 × 1 mm USB-end contacts sit at (−9.5,17.9) and (11,17.9), based on bare regions in the official underside photo. Verify those regions against the actual clone and solder.

The independent Blender checker tests screw/nut dimensions and orientation, full engagement, bottom access, open vertical nut paths, continuous bearing material, four support contacts, GPIO clearance and component interference. It does not model real threads, nut chamfers, print distortion, solder joints, tightening torque, or cable load strength.

## Fit before final assembly

Print the updated fastener coupons in the case material/settings. Their middle station matches the nominal head bore; outer stations vary it by ±0.2 mm. Check actual screw length, free head entry, full nut engagement and flat PCB seating. Tighten gently while holding the nut; do not use tightening force to flatten a rocking board or an obstructed lid. Test BOOT/RESET access with the lid removed and inspect the four supports during cable insertion/removal.
