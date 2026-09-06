# Component dimensions and model accuracy

The enclosure now mounts the S2 Mini through its **two dedicated mounting holes**. The previous edge fingers were removed because the simplified board model did not expose the electrical pin layout. A clean intersection test against an empty PCB outline was insufficient.

The current references include more of the physical parts, but **the complete assembly is not yet an exact, measured model of the purchased hardware**. The table below separates published dimensions from derived coordinates and dimensions still needing measurement. The machine-readable record is [component-models.json](../enclosure/component-models.json).

## The selected board

The user supplied [AliExpress item 3256812318584460](https://www.aliexpress.us/item/3256812318584460.html). On inspection, the listing identified **Nextronics Store**, brand **XYCJJCXL**, and **S2 Mini V1.0.0**. Its photographs show a purple board with two large mounting holes at the antenna end and four columns of electrical headers. This is a visual match to the LOLIN layout, not confirmation that the seller uses LOLIN's exact PCB or components. The listing's AI-generated summary is not a mechanical specification.

| Feature | Model input | Evidence / confidence |
| --- | --- | --- |
| PCB outline envelope | 25.4 × 34.3 mm | Explicitly dimensioned in the [LOLIN drawing](https://docs.wemos.cc/en/latest/_static/files/dim_s2_mini_v1.0.0.pdf). Seller-board match still needs checking. |
| Dedicated mounting holes | Ø2.0 mm, 20.4 mm centre spacing, 2.5 mm side setback | Explicit dimensions in the same drawing; separate from the electrical holes. |
| Hole setback from antenna edge | Approximately 3.30 mm | Derived from vector geometry in the drawing, **not a dimension callout**. Measure before final printing. |
| Mount coordinates in the case | x = ±10.2 mm, y = −12.35 mm | Derived from that setback, with PCB centre y = +1.5 mm and USB toward +y. |
| PCB thickness | 1.6 mm provisional | Not specified by the available official mechanical drawing. Measure the actual board. |
| Electrical headers | 4 columns × 8 holes, nominal 2.54 mm pitch | [Official top photograph](https://docs.wemos.cc/en/latest/_static/boards/s2_mini_v1.0.0_1_16x16.jpg), [bottom photograph](https://docs.wemos.cc/en/latest/_static/boards/s2_mini_v1.0.0_2_16x16.jpg), and [schematic J2–J5](https://docs.wemos.cc/en/latest/_static/files/sch_s2_mini_v1.0.0.pdf). The nominal grid alignment and drill/pad diameters are reference inputs, not a manufacturer fabrication drawing. |
| USB socket, buttons, chip and passives | Photo-based positions and clearance envelopes | Their exact placements, package variants and assembled heights are not fully documented. Detailed appearance does not make those dimensions verified. |

No manufacturer-authored S2 Mini PCB/Gerber/STEP source was found in the [official documentation repository](https://github.com/wemos/docs). The [OpenHornet community footprint](https://github.com/jrsteensen/OpenHornet/blob/c259a65a1759801a2affea817fd99f6a14f1e1fe/ECAD/lib/OH_Footprints.pretty/S2_MINI.kicad_mod) is useful for comparison, but places the hole setback at 3.21 mm and offsets the outline from the header grid. It is not used as proof of manufacturer accuracy or imported into this project.

## Other components

| Part | What is supported | What remains unverified |
| --- | --- | --- |
| Gateron Baby Kangaroo 2.0 | Housing, mounting interface, locating posts, metal pins and travel are based on the [Gateron drawing](https://gateron.com/u_file/2308/29/file/GATERONBabyKangaroo20Switch-b4b5.pdf), part KS-9LKA10B059NW-D110. | Fine molded details, actual clip fit, solder blobs and the purchased switch's tolerances. The model is reconstructed from the drawing, not Gateron's original solid CAD. |
| Max Keyboard 1.5u Tab cap | The [vendor selection](https://maxkeyboard.com/custom-art-icon-or-text-cherry-mx-keycaps.html) specifies R3 1x1.5, MX compatibility and top printing. The [profile guide](https://maxkeyboard.com/mechanical-keycap-layout-and-size-chart.html) identifies OEM row profiles. | Exact outside dimensions, front/back heights, dish, skirt clearance and stem-socket position/depth. No exact CAD was found. The rendered cap remains an approximation; [vendor information request](../keycap/dimensions-request.md). |
| M2 × 8 case screws | BelMetric MSF2X8SS: M2 × 0.4, 8 mm overall length, Ø3.8 × 1.2 mm head, PH1, 90° countersink. [Manufacturer drawing](https://belmetric.com/content/A-PDF_Drawings/MSF2X8SS.pdf). | Detailed thread/recess geometry is not a substitute for testing the physical screws. |
| M1.6 × 4 PCB screws | CNC Kitchen: M1.6 × 0.35, 4 mm under-head length, Ø2.93 × 1 mm head, TX5. [Selected part](https://cnckitchenus.store/products/m1-6-screw-tx5-stainless-steel-aisi-304-low-head?variant=48314244333668). | Actual board thickness controls thread engagement. |
| Brass inserts | Selected [M2 × 3](https://cnckitchenus.store/products/heat-set-insert-m2-x-3-100-pieces) is Ø3.6 mm; [M1.6 × 2.5](https://cnckitchenus.store/products/heat-set-insert-m1-6-100-pieces-kopie) is Ø2.5 mm. Model seats follow these parts. | Printed bore shrinkage, heat-set installation and pull-out resistance need the coupons. Rendered knurl/thread details are illustrative. |
| Feet, wire and USB cable | Foot dimensions follow the cut-to-size BOM; wire paths and cable space show routing intent. | Cable overmold dimensions, exact wire lengths/bends and finished solder joints require the actual parts. |

## Measurements needed before declaring fit

The [key mounting guide](key-mounting.md) adds Gateron's specified plate and
aperture tolerances, lid reinforcement, clip retention and service procedure.
The hollow cap, socket and latch shapes in Blender explain the interfaces;
their unspecified dimensions remain approximations. The ribs are original
enclosure geometry, not a modification to the purchased switch.

1. **PCB:** overall size and thickness; both hole diameters; hole centre spacing; hole centre setback from the antenna edge. Measure from the edge to a hole's near edge and add half its diameter to obtain the centre setback.
2. **Populated board:** USB socket width, height and overhang; maximum top/bottom component height; button protrusions; solder-joint clearance. Keep all 32 electrical holes accessible.
3. **Keycap and switch:** cap stem seating depth, skirt clearance at full travel, overall heights and the switch's lowest pin after soldering. Target at least 2 mm from switch pins/solder to the tallest board component.
4. **Cable:** plug overmold width/height and enough insertion depth to seat fully through the rear wall.

Use those measurements to update the corresponding model inputs, regenerate in Blender, rerun the interference checks, and dry-fit a print. Manufacturer nominal dimensions and mesh checks alone cannot establish the final fit of a third-party board and custom keycap.
