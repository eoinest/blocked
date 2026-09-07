# Printable enclosure and mounting

This is a **46 × 42 × 22 mm** case for the selected S2 Mini V1.0.0 board, a Gateron Baby Kangaroo 2.0 switch, and a purchased **1.5u Tab keycap** printed with `blocked`.

**Status: captive-nut prototype, not physically fitted.** The current Blender/STL files use the four screws and four nuts in the ordered Maierke kit. The board attaches through its two dedicated mounting holes; all 32 GPIO holes remain separate. Read the [component accuracy record](component-accuracy.md) before treating the models as dimensions for your purchased parts.

![Assembled Blender model](../enclosure/preview.png)

## How the parts mount

- **PCB:** two M1.6 screws pass through the two large holes at the antenna end into side-loaded M1.6 hex nuts in the base standoffs. All 32 electrical header holes remain separate from the mount.
- **Switch:** its flange bears on the lid, two clips latch beneath the 1.5 mm plate, and the square aperture prevents rotation. Two underside ribs stiffen the lid without thickening the clip land.
- **Keycap:** the purchased Tab cap presses onto the centred MX cross stem. See the [complete key mounting guide](key-mounting.md) for the section view, fit checks and removal procedure.
- **Case:** two M2 socket-cap screws enter from underneath through flat-bottom head recesses and engage side-loaded hex nuts in the lid posts.
- **Desk:** four adhesive-backed rubber feet fit the bottom pockets. Their exposed side grips the desk by friction.

![Blender mounting view](../enclosure/mounting.png)

The cutaway exposes the mounting hardware for explanation. Print the full base and lid meshes. The board is supported at its two mounting holes, so the USB end is cantilevered; verify resistance to cable insertion and removal on the real assembly before gifting it.

## Screws and nuts from the ordered kit

All four screws and four nuts come from the [Maierke assortment already ordered](https://www.amazon.com/dp/B0GKFMJH24?th=1). No heat-set inserts or washers are used.

| Quantity | Part | Installation |
| --- | --- | --- |
| **2** | M1.6 × 4 mm socket-cap screws, nominal pitch 0.35 mm | Down through the PCB's dedicated Ø2 mm holes into the base nuts |
| **2** | M1.6 hex nuts, listed width 3.5 mm across flats | Slide into the inward-facing slots in the base posts before fitting the board |
| **2** | M2 × 8 mm socket-cap screws, nominal pitch 0.4 mm | Up from the flat-bottom recesses beneath the base into the lid nuts |
| **2** | M2 hex nuts, listed width 4 mm across flats | Slide into the inward-facing slots in the lid posts before closing the case |

Both screw lengths are measured **under the head**. Both nominal socket sizes take a **1.5 mm hex key**; check the delivered parts. The model allows Ø3.2 × 1.7 mm PCB heads and Ø4.0 × 2.1 mm case heads. Actual kit head dimensions and nut thicknesses remain unmeasured: use the [fastener audit](fastener-fit.md) and fit coupons.

The hex pockets prevent rotation while the screws clamp the assembly. Their insertion slots remain open, so **loose nuts can slide out during disassembly**; work over a tray and keep them seated when starting screws. No glue is required. M1.6 screws provide nominal 0.4 mm diametral clearance in the PCB holes. Do not enlarge the board holes or use GPIO holes for fastening.

## Geometry and coordinates

The origin is the case centre in x/y and the outside base bottom in z. USB faces **+y**; the antenna and PCB mounting holes face **−y**.

| Feature | Default |
| --- | --- |
| Case | 46 × 42 × 22 mm; base height 20.5 mm, lid plate 1.5 mm |
| Shell | 2 mm floor/walls; 3 mm outside corner radius |
| Switch aperture | 14.1 × 14.1 mm; tune with the switch coupon |
| Switch aperture / plate finished targets | Gateron: 14.00 +0.05/−0.02 mm aperture, 1.50 +0.01/−0.05 mm plate; CAD aperture compensates for print shrinkage |
| Lid reinforcing ribs | Two integral 12 × 9.1 × 2 mm ribs, x = 0, y = ±14.05 mm; clip land remains 1.5 mm |
| PCB envelope | 25.4 × 34.3 mm; centre y = +1.5 mm |
| PCB bottom / thickness | z = 5.5 mm / **1.6 mm provisional** |
| PCB mounting holes | Ø2.0 mm; x = ±10.2 mm, y = −12.35 mm |
| Hole provenance | 20.4 mm pitch and 2.5 mm side setback are dimensioned; **3.30 mm antenna-edge setback is derived from PDF vectors** |
| PCB standoffs | Ø6.4 mm pocket bodies; Ø5.2 mm contact collars from z = 4.7–5.5 mm |
| PCB nut pockets | AF3.7 mm × 1.5 mm high, z = 3.2–4.7 mm; 0.8 mm roof under the PCB |
| Lid posts | Ø7.2 mm; x = ±17 mm, y = 0; ends z = 4.3 mm |
| Lid nut pockets | AF4.2 mm × 1.8 mm high, z = 7.8–9.6 mm; screw relief to z = 11 mm |
| Base case-screw holes | Ø2.2 mm clearance; Ø4.4 mm × 2.2 mm flat-bottom head recesses |
| Local floor pads | Ø7.6 mm, top z = 4 mm; 1.8 mm plastic above the head recess |
| Lid registration skirt | 2 mm deep; 0.3 mm side clearance; 1.2 mm wall |
| Rear cable opening | 16 × 10 mm; z = 4–14 mm |
| Foot pockets | Four 8 × 8 mm rounded recesses, 0.5 mm deep |

The mounting-hole dimensions come from the [official LOLIN drawing](https://docs.wemos.cc/en/latest/_static/files/dim_s2_mini_v1.0.0.pdf). The [selected seller's board](https://www.aliexpress.us/item/3256812318584460.html) must still be checked against them. Set **board_mount_x**, **board_mount_y**, **board_mount_hole**, and **board_thickness** from your measurements if different.

The nominal PCB screw engages a 1.3 mm nut and protrudes 0.3 mm past it, leaving 0.7 mm to the blind relief bottom. The case screw engages a 1.6 mm nut and protrudes 0.8 mm, leaving 0.8 mm to the relief top. The base's local 4 mm thickness leaves a **1.8 mm bearing shoulder** above each 2.2 mm-deep head recess. The lid posts leave 0.3 mm to those local floor pads when the perimeter seats.

The PCB contact collars have approximately 0.99 mm nominal clearance to the nearest copper pad at board height. The wider pocket bodies below have much less clearance to the modeled wire-access envelope (about 0.19 mm). Actual pad geometry and solder joints need inspection. The [fastener audit](fastener-fit.md) records minimum walls and dimensional assumptions; keep all relief bores clear and verify the screws clamp before bottoming out.

## Files and Blender workflow

- [blocked-print-plate.stl](../enclosure/stl/blocked-print-plate.stl): base and lid together, already oriented and separated by 6 mm; requires a 98 × 42 mm footprint before brim/support allowance.
- [blocked-print-plate-with-coupons.stl](../enclosure/stl/blocked-print-plate-with-coupons.stl): both case parts plus all three fit coupons; 108 × 90 mm footprint. Coupons are normally printed first to tune fit before committing to the case.
- [blocked.blend](../enclosure/blocked.blend): editable assembly. **PRINTABLE** contains the base, lid and coupons; reference collections contain the purchased-part models and clearance geometry.
- [base.stl](../enclosure/stl/base.stl) and [lid.stl](../enclosure/stl/lid.stl): millimetre units, oriented for printing. Lid is top-down.
- [fit-coupon.stl](../enclosure/stl/fit-coupon.stl): switch apertures 14.0, 14.1 and 14.2 mm, marked with one, two and three notches.
- [case-fastener-coupon.stl](../enclosure/stl/case-fastener-coupon.stl): M2 nut pockets AF4.1/4.2/4.3 mm paired with head bores Ø4.2/4.4/4.6 mm, all 2.2 mm deep; test the mounting stack with the actual M2 × 8 screw.
- [board-fastener-coupon.stl](../enclosure/stl/board-fastener-coupon.stl): M1.6 nut pockets AF3.3/3.5/3.7/3.8 mm, marked with one to four notches; includes an integral 1.6 mm PCB-thickness stand-in so an M1.6 × 4 screw tests engagement. Total coupon height is 7.1 mm; match this stand-in to the actual board thickness if different.
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

# Rebuild the combined print plates after regenerating individual STLs:
/Applications/Blender.app/Contents/MacOS/Blender \
  --background --factory-startup --threads 4 \
  --python enclosure/print-layout.py
```

Use Blender 4 or later; these files were generated with Blender 5.2.1. Regeneration overwrites the generated files, so save manual Blender edits separately. Purchased-part references are **not** printable replacements for the electronics, switch, cap, screws or nuts.

The independent [assembly checker](../enclosure/check-assembly.py) tests the saved Blender solids for case/PCB interference, access around all 32 electrical pads, switch/component collisions, and the assumed USB plug envelope. It also checks nut insertion paths, screw/head reliefs, continuous bearing material, and lid-off RESET/BOOT tool approaches. Its [report](../enclosure/assembly-validation.json) lists the tested pairs and exclusions. The checker has independent nominal fixtures: if measured parts require parameter changes, update those fixtures deliberately and rerun it. Keycap socket fit, solder joints, wire bends, printed pocket strength and cable-induced board flex still require actual parts.

## Print and assemble

1. **Measure the actual board first.** Check the dedicated hole pitch/setback, PCB thickness, component heights, USB position and cable overmold. The [accuracy record](component-accuracy.md) lists all unresolved dimensions. In particular, detailed photo-based board geometry is not proof of exact component clearance.
2. Print the switch and both fastener coupons in the intended material. The switch clips must latch and return freely. Nuts must slide into their pockets, resist rotation, and allow the screws to clamp without bottoming out. Choose the pocket fit using the notched variants and update the corresponding `*_nut_pocket_af` parameter. Measure nut thickness and head size too; across-flats clearance alone cannot validate the stack.
3. Print the base floor-down and lid top-down. Use a 0.4 mm nozzle, 0.1 mm layers for the lid/coupons and 0.16–0.2 mm for the base, starting with four walls and five floor layers. Inspect the slicer's nut-pocket bridges, bearing roofs/floors, and rear-opening bridge. Remove any support from pockets and bores. The lid is 17.7 mm tall in its print orientation. PLA is suitable for a desk prototype; PETG is another option.
4. **Fit the nuts before electronics.** Slide two M1.6 nuts into the inward-facing base slots and two M2 nuts into the inward-facing lid slots. Align the threads with the vertical screw holes and check the screws run freely. Remove debris. The slots remain open for service; hold the nuts seated during handling.
5. Flash and test the board. Clip the switch into the lid before connecting both ends of its wires, following the [key mounting guide](key-mounting.md). With USB unplugged, wire GPIO4 and GND to the switch, insulate exposed terminals and leave enough slack to remove the lid. Keep solder and wires clear of the mounting holes and screw heads.
6. Lower the PCB onto the two standoffs, align its large holes, and install the **two M1.6 × 4 mm screws from above**. Tighten gently until retained. The board must not bend and the screws must not touch adjacent components. Verify every electrical pin hole remains accessible.
7. Confirm both switch clips latch beneath the lid and the flange sits flat, following the [key mounting guide](key-mounting.md). Route the service loop and hand-seat the lid. Check switch pins and solder remain at least **2 mm** above the tallest PCB component. Close with the **two M2 × 8 mm socket-cap screws from underneath**, stopping when secure; heads should be flush or slightly recessed. Do not pull an obstructed lid shut with screws.
8. Fit the purchased Tab keycap and check full travel/return, including off-centre presses. Cut four 8 × 8 mm feet from the BOM's approximately 1 mm rubber sheet, round their corners, and attach them in the recesses.
9. Test cable insertion/removal and repeated presses. Because the USB end extends beyond the two-hole mount, inspect board flex and fastener stability. Unplug and reopen to check for rubbing or pinched wires before declaring the assembly ready.

## RESET / BOOT service access

**The first version uses disassembly, with no exterior button holes or extra
parts.** The two underside case screws remain clear of the feet. Remove those
screws and lift the lid with its switch and keycap still attached; the cap does
not need removal just to open the case. Support the lid beside the base rather
than leaving it hanging from its wires.

RESET restarts the board. BOOT (marked **0** on some S2 Minis) selects the ROM
downloader when held during reset. Hold BOOT, tap/release RESET, then release
BOOT once the USB downloader appears. See the [LOLIN instructions](https://docs.wemos.cc/en/latest/tutorials/s2/get_started_with_arduino_s2.html)
and [firmware flashing guide](../firmware/README.md#flash). This firmware disables
the serial-line reboot shortcut, so physical access is needed for later uploads
as well as first assembly. A routine restart can also be done by unplugging and
reconnecting USB, with BOOT released.

1. Quit the companion and disconnect USB before opening the case.
2. Remove the two case screws, support the lid, and expose the USB end of the
   board. Locate the actual RESET and BOOT actuator faces using the board labels.
   The current Blender references show side-facing buttons near the USB end;
   exact positions and travel on the purchased clone remain unmeasured.
   The nominal side gaps are about **8.75 mm at RESET** and **7.75 mm at BOOT**,
   with the actuator centres about **12.15 mm below the rim**. This favors a
   narrow tool over fingers. The modeled channels lie behind the electrical
   header rows and clear the case posts; keep wires out of these channels.
3. Confirm a finger or blunt nonconductive tip can reach each actuator without
   levering against the PCB or pulling the wire joints. Do not force a tool
   through the USB opening. If access is awkward, unplug USB and remove the two
   PCB mounting screws too; service the supported board outside the base.
4. Reconnect USB only once the board and lid are stable on a nonconductive work
   surface. Perform the BOOT/RESET sequence and upload. Disconnect USB again
   before refitting any screws and closing the case.

**Assembly acceptance check:** before finalizing wire lengths, demonstrate this
opening and flashing sequence. Leave enough service slack for the lid to clear
the buttons and be supported beside the base, and make sure that same slack
fits inside without touching clips, pins or screw posts. The wires in Blender
are illustrative routes, not a validated service loop. Lid-off finger/tool
access and board flex are also not yet physically verified.

If closed-case access becomes necessary, investigate **two recessed side-wall
holes**, aligned to the measured lateral actuators. Bottom holes cannot provide
a direct route through the PCB, and top holes do not align with these modeled
side-facing plungers. Hole locations, tool clearance and a travel limit must be
checked on the actual board before changing the printable base; no hole diameter
or location is released as fabrication-ready yet. Preserve access to both
controls and keep the GPIO pads and USB connector clear.

No headers, battery, hot-swap socket or extra circuit board are included in this envelope.

![Exploded Blender assembly](../enclosure/exploded.png)
