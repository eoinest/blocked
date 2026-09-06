# Printable enclosure and mounting

This is a **46 × 42 × 22 mm** case for the selected S2 Mini V1.0.0 board, a Gateron Baby Kangaroo 2.0 switch, and a purchased **1.5u Tab keycap** printed with `blocked`.

**Status: revised prototype, not physically fitted.** The board now attaches through its two dedicated mounting holes. Earlier edge-retaining fingers have been removed. Read the [component accuracy record](component-accuracy.md) before treating the models as dimensions for your purchased parts.

![Assembled Blender model](../enclosure/preview.png)

## How the parts mount

- **PCB:** two M1.6 screws pass through the two large holes at the antenna end into brass inserts in the base standoffs. All 32 electrical header holes remain separate from the mount.
- **Switch:** its retaining clips engage the lid's 1.5 mm plate around the MX aperture.
- **Keycap:** the purchased Tab cap seats on the switch stem.
- **Case:** two countersunk M2 screws enter from underneath and engage brass inserts in the lid posts.
- **Desk:** four adhesive-backed rubber feet fit the bottom pockets. Their exposed side grips the desk by friction.

![Blender mounting view](../enclosure/mounting.png)

The cutaway exposes the mounting hardware for explanation. Print the full base and lid meshes. The board is supported at its two mounting holes, so the USB end is cantilevered; verify resistance to cable insertion and removal on the real assembly before gifting it.

## Exact screws and inserts

| Quantity | Part | Installation |
| --- | --- | --- |
| **2** | [CNC Kitchen M1.6 × 4 mm low-head TX5 screws](https://cnckitchenus.store/products/m1-6-screw-tx5-stainless-steel-aisi-304-low-head?variant=48314244333668), M1.6 × 0.35; Ø2.93 × 1 mm head | Down through the PCB's dedicated Ø2 mm holes. **4 mm excludes the head.** Use T5/TX5. |
| **2** | [M1.6 × 2.5 mm brass inserts](https://cnckitchenus.store/products/heat-set-insert-m1-6-100-pieces-kopie), Ø2.5 mm | Flush with the tops of the two base standoffs. |
| **2** | [BelMetric MSF2X8SS M2 × 8 mm countersunk screws](https://belmetric.com/phillips-flat-head-stainless-m2x0-4-coarse-din-965/), M2 × 0.4; Ø3.8 × 1.2 mm head, 90° | Up through the base into the lid. **8 mm includes the head.** Use PH1. |
| **2** | [CNC Kitchen TC-M2x3.0 M2 × 3 mm brass inserts](https://cnckitchenus.store/products/heat-set-insert-m2-x-3-100-pieces) (Ø3.6 mm) | Flush with the lower ends of the two lid posts. |

M1.6 screws provide nominal 0.4 mm diametral clearance inside the board's 2 mm mounting holes. **Do not drill out the PCB or use electrical header holes.** With a 1.6 mm PCB, a 4 mm screw engages approximately 2.4 mm of its 2.5 mm insert. Check your board thickness before choosing a different screw length.

Other inserts with the same thread can have different outside dimensions. Use the exact parts above or adjust the seats and post walls. Purchase quantities and links are in the [BOM](../BOM.md).

## Geometry and coordinates

The origin is the case centre in x/y and the outside base bottom in z. USB faces **+y**; the antenna and PCB mounting holes face **−y**.

| Feature | Default |
| --- | --- |
| Case | 46 × 42 × 22 mm; base height 20.5 mm, lid plate 1.5 mm |
| Shell | 2 mm floor/walls; 3 mm outside corner radius |
| Switch aperture | 14.1 × 14.1 mm; tune with the switch coupon |
| PCB envelope | 25.4 × 34.3 mm; centre y = +1.5 mm |
| PCB bottom / thickness | z = 5.5 mm / **1.6 mm provisional** |
| PCB mounting holes | Ø2.0 mm; x = ±10.2 mm, y = −12.35 mm |
| Hole provenance | 20.4 mm pitch and 2.5 mm side setback are dimensioned; **3.30 mm antenna-edge setback is derived from PDF vectors** |
| PCB standoffs | Ø5.2 mm, tops at z = 5.5 mm; M1.6 insert seats initially Ø2.4 mm × 3.5 mm deep |
| Lid posts | Ø6.4 mm; x = ±17.5 mm, y = 0; ends z = 2.3 mm |
| Lid insert seats | Ø3.4 mm × 3.2 mm deep; Ø2.4 mm screw-tip relief to 6.5 mm total depth |
| Base case-screw holes | Ø2.2 mm clearance, approximately Ø4.2 mm countersinks |
| Lid registration skirt | 2 mm deep; 0.3 mm side clearance; 1.2 mm wall |
| Rear cable opening | 16 × 10 mm; z = 4–14 mm |
| Foot pockets | Four 8 × 8 mm rounded recesses, 0.5 mm deep |

The mounting-hole dimensions come from the [official LOLIN drawing](https://docs.wemos.cc/en/latest/_static/files/dim_s2_mini_v1.0.0.pdf). The [selected seller's board](https://www.aliexpress.us/item/3256812318584460.html) must still be checked against them. Set **board_mount_x**, **board_mount_y**, **board_mount_hole**, and **board_thickness** from your measurements if different.

The M2 posts retain 1.4 mm nominal plastic wall around their inserts and 1.6 mm clearance to the PCB edge. The chosen countersunk head may seat about 0.15 mm below the countersink mouth, leaving approximately 0.65 mm screw-tip clearance. Keep the relief bores clear; screws must not bottom out before the lid seats.

## Files and Blender workflow

- [blocked.blend](../enclosure/blocked.blend): editable assembly. **PRINTABLE** contains the base, lid and coupons; reference collections contain the purchased-part models and clearance geometry.
- [base.stl](../enclosure/stl/base.stl) and [lid.stl](../enclosure/stl/lid.stl): millimetre units, oriented for printing. Lid is top-down.
- [fit-coupon.stl](../enclosure/stl/fit-coupon.stl): switch apertures 14.0, 14.1 and 14.2 mm, marked with one, two and three notches.
- [insert-coupon.stl](../enclosure/stl/insert-coupon.stl): M2 insert seats 3.2/3.3/3.4/3.5 mm, marked with one/two/three/four notches.
- [board-insert-coupon.stl](../enclosure/stl/board-insert-coupon.stl): M1.6 insert seats 2.2/2.3/2.4 mm, marked with one/two/three notches.
- [parameters.json](../enclosure/parameters.json), [component-models.json](../enclosure/component-models.json), and [build.py](../enclosure/build.py): design parameters, source/accuracy record, and Blender generator.
- [mesh-validation.json](../enclosure/mesh-validation.json): exported mesh dimensions and topology checks.
- [blocked.scad](../enclosure/blocked.scad): optional OpenSCAD geometry generated from the same source.

From the repository root:

```sh
/Applications/Blender.app/Contents/MacOS/Blender \
  --background --factory-startup --threads 4 \
  --python enclosure/build.py -- --export

/Applications/Blender.app/Contents/MacOS/Blender \
  --background --factory-startup --threads 4 \
  --python enclosure/check-assembly.py
```

Use Blender 4 or later; these files were generated with Blender 5.2.1. Regeneration overwrites the generated files, so save manual Blender edits separately. Purchased-part references are **not** printable replacements for the electronics, switch, cap, screws or inserts.

The independent [assembly checker](../enclosure/check-assembly.py) tests the saved Blender solids for case/PCB interference, access around all 32 electrical pads, switch/component collisions, and the assumed USB plug envelope. Its [report](../enclosure/assembly-validation.json) lists the tested pairs and exclusions. Keycap socket fit, solder joints, wire bends, insert strength and cable-induced board flex still require actual parts.

## Print and assemble

1. **Measure the actual board first.** Check the dedicated hole pitch/setback, PCB thickness, component heights, USB position and cable overmold. The [accuracy record](component-accuracy.md) lists all unresolved dimensions. In particular, detailed photo-based board geometry is not proof of exact component clearance.
2. Print the switch and both insert coupons in the intended material. The switch clips must latch and return freely. For inserts, choose a bore where the pilot just pre-seats with slight resistance before heating. The nominal M1.6/M2 bores are 2.2/3.2 mm; the initial CAD values add 0.2 mm for printer shrinkage. Update **board_insert_seat_diameter** / **insert_seat_diameter** after the coupon trial. See [CNC Kitchen's sizing guidance](https://www.cnckitchen.com/blog/are-our-heat-set-insert-datasheets-wrong).
3. Print the base floor-down and lid top-down. Use a 0.4 mm nozzle, 0.1 mm layers for the lid/coupons and 0.16–0.2 mm for the base, starting with four walls and five floor layers. Inspect the slicer's post walls and rear-opening bridge. The lid is 19.7 mm tall in its print orientation because the posts extend upward. PLA is suitable for a desk prototype; PETG is another option.
4. **Install inserts before electronics.** Heat-set two M1.6 inserts flush into the base posts and two M2 inserts flush into the lid posts. Keep them square, let them cool, and confirm the appropriate screws run freely. Remove debris and confirm the blind bores have tip clearance.
5. Flash and test the board. With USB unplugged, wire GPIO4 and GND to the switch, insulate exposed terminals and leave enough slack to remove the lid. Keep solder and wires clear of the mounting holes and screw heads.
6. Lower the PCB onto the two standoffs, align its large holes, and install the **two M1.6 × 4 mm screws from above**. Tighten gently until retained. The board must not bend and the screws must not touch adjacent components. Verify every electrical pin hole remains accessible.
7. Clip the switch into the lid, route the service loop, and hand-seat the lid. Check switch pins and solder remain at least **2 mm** above the tallest PCB component. Close with the **two M2 × 8 mm countersunk screws from underneath**, stopping when secure; heads should be flush or slightly recessed. Do not pull an obstructed lid shut with screws.
8. Fit the purchased Tab keycap and check full travel/return, including off-centre presses. Cut four 8 × 8 mm feet from the BOM's 1 mm Type D pads, round their corners, and attach them in the recesses.
9. Test cable insertion/removal and repeated presses. Because the USB end extends beyond the two-hole mount, inspect board flex and fastener stability. Unplug and reopen to check for rubbing or pinched wires before declaring the assembly ready.

BOOT and RESET remain accessible with the lid removed. The bottom feet do not cover the case screws. No headers, battery, hot-swap socket or extra circuit board are included in this envelope.

![Exploded Blender assembly](../enclosure/exploded.png)
