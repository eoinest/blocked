# Printable enclosure

This is a **46 × 42 × 22 mm** two-piece case for a **headerless LOLIN S2 mini**, a standard full-height MX switch, and a purchased **1.5u keycap, approximately 28 mm wide**. The assembled render is about 34 mm tall including its illustrative keycap. The recommended switch and wiring are covered in [hardware.md](hardware.md).

The revised design takes visual cues from the [physical Cursor Tab button](https://www.linkedin.com/posts/jonathanbraude_the-cursor-tab-has-arrived-activity-7358934314186657793-v_f7): a satin silver pedestal, an ivory sculpted key, a small dark legend, and a clean top without visible fasteners. These are our own enclosure dimensions and geometry; the design does not reproduce Cursor branding. The keycap is 10 mm wider than the original 1u concept, with a tapered skirt and shallow dish shown in the reference model.

![Assembled Blender model](../enclosure/preview.png)

**Status: digitally checked prototype, not physically fit-tested.** The three STL files have one connected solid each, positive volume, and zero non-manifold edges. That verifies mesh topology; it does not verify your board, switch clips, cable, printer tolerances, or assembly. Start with the switch coupon and measure the actual board before printing the full case.

## Files and editing in Blender

- [blocked.blend](../enclosure/blocked.blend) is the editable Blender model. Open it in Blender, expand `PRINTABLE`, and select `base` or `lid` for mesh editing. `REFERENCE ONLY` contains approximate purchased parts; `STUDIO` contains the camera and lights. The fit coupon is hidden in the viewport and can be unhidden from the Outliner. The saved view opens on the assembled camera composition.
- [base.stl](../enclosure/stl/base.stl), [lid.stl](../enclosure/stl/lid.stl), and [fit-coupon.stl](../enclosure/stl/fit-coupon.stl) are exported in **millimeters**, oriented for printing. The lid STL is upside down relative to assembly, with its top face on the print bed.
- [parameters.json](../enclosure/parameters.json) and [build.py](../enclosure/build.py) are the parametric source. The script builds Blender meshes and renders the scene. It also generates [blocked.scad](../enclosure/blocked.scad) from the same geometry tree for an optional OpenSCAD workflow.
- [mesh-validation.json](../enclosure/mesh-validation.json) records dimensions, topology, and volume for the exported meshes. The STL exports include the lid's modeled perimeter chamfer and the base's inset bottom band. They exclude the additional render-only edge highlights and all reference objects.

From the repository root, regenerate all geometry with the installed Blender:

```sh
# macOS; change the executable path for another installation or OS.
/Applications/Blender.app/Contents/MacOS/Blender \
  --background --factory-startup --threads 4 \
  --python enclosure/build.py -- --export
```

Use Blender 4 or newer; the included artifacts were generated in Blender 5.2.1. No Python packages or add-ons are required. Regeneration overwrites the generated `.blend`, `.scad`, STL files, images, and validation report, so save manual Blender edits under another filename first. Edit the JSON for repeatable dimensional changes. Its parameters are intended for small fit adjustments; substantial size changes also require checking the locator, pad, and screw layout in the script.

To regenerate only the optional OpenSCAD file, run `python3 enclosure/build.py`. In OpenSCAD choose `part = "base"`, `"lid"`, or `"fit-coupon"`, render, and export. Blender is the main design and preview workflow.

## Mechanical layout

| Feature | Default geometry |
| --- | --- |
| Body envelope | 46 mm wide × 42 mm deep × 22 mm high |
| Base | 20.5 mm high; 2 mm wall and floor; 3 mm outside corner radius |
| Lid and switch flange | 1.5 mm plate, 14.1 × 14.1 mm square MX aperture |
| Top edge | 0.3 mm high perimeter chamfer; the switch flange remains 1.5 mm |
| Lid registration skirt | 2 mm deep; 0.3 mm clearance per side; 1.2 mm wall |
| Lid screws | Two M2 × 8 mm, 90° countersunk machine screws, inserted from underneath into printed lid posts |
| Screw locations | x = ±18 mm, y = 0; 5.4 mm post outside diameter |
| Screw holes | Lid post: 1.7 mm blind pilot, 9 mm deep; base floor: 2.2 mm clearance and about 4.2 mm underside head recess |
| Lid post reach | Ends 2.3 mm above the outside bottom, leaving 0.3 mm above the 2 mm floor |
| Lower edge | Bottom 0.8 mm is inset by 0.4 mm per side; dark color is an optional finish |
| Board envelope | 25.4 mm across x × 34.3 mm along y; center y = +1.5 mm |
| PCB support | Four 3.5 mm square pedestals, 2.5 mm above inside floor, plus 1 mm insulating adhesive foam |
| Nominal PCB underside | 5.5 mm above outside bottom after adding foam |
| Rear cable opening | 16 mm wide × 10 mm high, bottom 4 mm above outside bottom |
| Desk pad recesses | Four 8 × 8 mm rounded pockets, 0.5 mm deep |

The positive-y side is the USB side; the board keeps its original orientation and the opening is at the rear. The base contains narrow side locators and a front stop; foam adhesive on the four support pads retains the board vertically. There is no metal board bracket and no screw passes through the PCB. Two posts descend from the lid beside the board. The screws enter through the bottom and engage those posts, leaving the visible top free of screw holes. The switch snaps into the lid, with its two soldered wires routed down beside the PCB. This stack stays small without requiring a USB adapter or a custom circuit board.

At the default dimensions, the posts have 2.6 mm clearance to the bare PCB edge and 0.3 mm clearance to the inside case wall. An 8 mm countersunk screw, measured including its head, reaches about 5.7 mm into each post's 9 mm pilot. Check that your actual screw heads sit flush before relying on these nominal values.

The official WEMOS documentation specifies the [S2 mini board footprint](https://www.wemos.cc/en/latest/s2/s2_mini.html) as 34.3 × 25.4 mm, with a [dimension drawing](https://docs.wemos.cc/en/latest/_static/files/dim_s2_mini_v1.0.0.pdf). The Gateron [Baby Kangaroo 2.0 manufacturer drawing](https://gateron.com/u_file/2308/29/file/GATERONBabyKangaroo20Switch-b4b5.pdf) is the switch reference. The 14.1 mm opening includes a small print allowance; choose its actual value with the coupon rather than assuming all printed MX plates fit identically.

![Exploded Blender model, rear view](../enclosure/exploded.png)

The ivory keycap, clear switch envelopes, blue PCB, and USB shell are visual references, **not manufacturing models**. The keycap has no functional MX socket and is not exported as an STL; purchase a 1.5u MX cap such as the one linked in the hardware guide. Its exact profile and final assembled height depend on the cap you choose. The PCB reference uses the published footprint but assumes a 1.6 mm board thickness. It omits components, solder joints, buttons, antenna details, switch pins, wires, foam, and fasteners. Do not use these reference meshes as collision proof or print them as working purchased parts.

## Measure and print a coupon first

1. Confirm your board is actually the 34.3 × 25.4 mm S2 mini layout. S2/S3/C3 boards and clones can differ. Remove headers for this case; it is not sized for Dupont plugs or stacked headers.
2. Measure PCB thickness, the tallest components on both sides, USB socket location, and your cable's overmold. With nominal foam, the PCB bottom is 5.5 mm above the desk-side case surface. The USB opening spans z = 4–14 mm. Check that the plug can fully seat through the opening; the PCB's nominal USB end is about 2.35 mm inside the outer rear wall.
3. Print the coupon at 100% scale, with 0.1 mm layers so the 1.5 mm flange prints accurately. Its holes are **14.0, 14.1, 14.2 mm**, marked with **one, two, three** small edge notches respectively. Start with the middle hole. The switch should press in firmly and its retaining clips should latch underneath without cracking the plate. Change `switch_opening` to the best fit and regenerate if needed. Lightly remove first-layer elephant's foot before judging fit.
4. Inspect the four proposed pad positions on the actual PCB: x = ±10.5 mm; y = −12 and +15 mm, relative to case center. Move `support_x` / `support_y_offset` if a pad would touch a component, an underside solder joint, or a wire. The adhesive must land on suitable clear, flat PCB areas. Keep bare metal and solder off the plastic supports; use electrically insulating foam, never conductive foam.
5. Check the switch's lowest pin/center-post point and tallest PCB component with the parts dry-stacked. Target at least **2 mm clearance**, including solder and insulated wires. If needed, increase `base_height` instead of compressing or bending the assembly together. This is especially important with a five-pin switch and bulky solder joints.

## Printing

PETG is a useful first choice for the lid's repeated switch insertion and screw bosses; PLA is fine for a desk prototype. Use a 0.4 mm nozzle, 0.1 mm layers for the lid/coupon, and 0.16–0.2 mm layers for the base. Start with four walls, five floor layers, and 20–30% infill. Check the slicer's wall paths around the switch hole and screw heads.

Print the base floor-down and the lid top-down as supplied in the STLs. The base's rear USB opening requires a 16 mm bridge, and its underside pad pockets require short 8 mm bridges. A tuned printer can do these without supports; use local support under the USB bridge if your printer cannot bridge cleanly, and remove it before inserting the board. No internal support should remain around the PCB. The lid's registration skirt faces upward during printing.

The supplied lid mesh is **19.7 mm tall on the print bed** because the long screw posts point upward when it is printed top-down. The assembled case is still 22 mm tall because the posts and registration skirt fit inside the base. The posts print vertically without support. The base's bottom inset forms only a 0.4 mm overhang at 0.8 mm height.

The render shows a satin silver finish with a charcoal inset band and ivory purchased cap. A printed plastic case will not inherently look like machined aluminum: silver filament gives a simpler approximation, or sand/prime and apply a suitable metallic finish. The dark bottom band can be painted or printed with a color change in the first 0.8 mm. Color is optional and does not affect assembly.

## Assembly and desk grip

1. Flash and test the board while it is accessible. Solder the switch wires with the board unplugged, use heat-shrink over exposed switch terminals, and leave a small service loop. Fit the switch into the lid before wiring it if that makes the leads easier to handle.
2. Dry-fit the empty lid onto the base. The skirt and long posts should slide into place without bowing or rubbing the walls. With the lid removed, run each M2 screw gently into its underside post once to form a thread, back it out, and remove debris; stop if a post starts splitting or excessive force is needed. Printed pilot sizes depend on material and printer; enlarge carefully rather than forcing a screw. The base's screw clearance holes should allow the screws to pass freely.
3. Cut four small pieces of 1 mm thick, electrically insulating double-sided foam tape to the support tops. Place them only where the measured board has clear contact areas. Locate the board with USB facing the opening and press it onto the foam. Foam retention is a prototype choice; verify it resists cable insertion without the board moving. The tape linked in the BOM is sold for PCB mounting but is not advertised as removable; expect to replace it when servicing the board. Keep adhesive off controls and components.
4. Route the insulated leads clear of the switch's travel, switch center post, PCB components, posts, and lid skirt. Seat the lid, hold the assembly together, and insert the two M2 × 8 mm countersunk screws **from the underside**, stopping as soon as their heads are flush. Avoid overtightening the printed posts or floor. Fit the purchased 1.5u keycap and verify full travel and return, including off-center presses. The extra width can make wobble more noticeable; a 1.5u centered MX cap generally uses one switch, but test the exact cap and switch combination.
5. Cut the BOM's Type D rubber pads into four 8 × 8 mm feet, rounding their corners to fit the underside pockets. A 1 mm pad projects about 0.5 mm below the case. Rubber feet provide friction; they do not stick the object to the desk. If you want desk adhesion, use small removable double-sided gel pads instead, checking compatibility with the desk finish. Keep the two functions distinct when buying pads.
6. Plug in the actual cable and press repeatedly. The case should stay seated, the cap should clear the lid throughout travel, and neither the board nor USB socket should shift. Unplug and inspect the first assembly for pin contact or pinched wires before treating the gift as finished.

BOOT and RESET remain internal; removing the two underside screws provides service access. The foot pockets do not cover those screws. Headers, a battery, LEDs, and hot-swap sockets are intentionally outside this version's mechanical envelope. The final fit still requires a real printed coupon and a board-in-case trial.
