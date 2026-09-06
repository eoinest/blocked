# Captive-nut fastener fit audit

This audit covers the prototype for the ordered [Maierke assortment,
ASIN B0GKFMJH24](https://www.amazon.com/dp/B0GKFMJH24): two M1.6 × 4 socket-cap
screws with M1.6 nuts for the PCB, and two M2 × 8 socket-cap screws with M2 nuts
for the case. These parts replace the earlier heat-set inserts and countersunk
screws. No fastener from the kit has been measured for this design.

## Evidence and assumptions

All dimensions below are millimetres. Screw lengths exclude the head. The
figures are reference envelopes for a prototype coupon, not a certificate that
the Amazon kit conforms to DIN or ISO.

| Feature | M1.6 PCB fastener | M2 case fastener | Basis |
| --- | --- | --- | --- |
| Thread pitch | 0.35 | 0.40 | Standard coarse metric threads |
| Under-head length | 4 | 8 | Purchased kit selection |
| Socket-cap head diameter envelope | 3.14 | 3.98 | Supplier's DIN 912 / ISO 4762 size charts |
| Socket-cap head height | 1.60 | 2.00 | Supplier's DIN 912 / ISO 4762 size charts |
| Hex driver | 1.50 | 1.50 | Supplier's socket-cap charts |
| Nut width across flats used for this prototype | **3.50** | 4.00 | Kit listing selection; measure before printing |
| Nut thickness range used for checks | 1.05–1.30 | 1.35–1.60 | DIN 934 reference range, not measured kit thickness |

[Monster Bolts' M1.6 chart](https://monsterbolts.com/pages/m1-6-bolt-size) and
[M2 chart](https://monsterbolts.com/pages/m2-bolt-size) give the screw envelopes.
[Accu's M1.6 socket-cap drawing](https://www.accu.co.uk/metric-cap-head-screws/250388-SSCF-M1-6-3-A2-R360)
independently gives a nominal 3.0 mm head, 1.6 mm height, and 1.5 mm drive. The
larger diameter allowance above accommodates the supplier's stated outer head
envelope rather than assuming a perfectly smooth 3.0/3.8 mm cylinder.

[Westfield Fasteners' DIN 934 table](https://www.westfieldfasteners.co.uk/Standards/Nut_Hex_M.html)
gives the nut thickness ranges. **Its normal M1.6 nut has 3.2 mm across flats,
whereas the purchased kit was listed as 3.5 mm.** The model must follow the
actual nut, not silently substitute the standard 3.2 mm size. Do not use the
table's minimum across-corners dimension as a maximum pocket envelope.

A standard 3.2 mm-across-flats nut has a theoretical 3.695 mm corner diameter,
so it can rotate completely in a 3.7 mm-across-flats pocket. If the delivered
nut is that size, choose a smaller coupon fit and update the model. The larger
pocket is not a universal fit for both possible M1.6 nut sizes.

## Geometric checks

For a regular hexagonal pocket, the corner-to-corner size is
`across_flats / cos(30°)`. A 3.7 mm pocket therefore needs 4.272 mm across corners;
a 4.2 mm pocket needs 4.850 mm. A circular boss needs room for those corners as
well as the insertion slot. For example, a 6.4 mm boss around the 3.7 mm pocket
has 1.064 mm corner wall before an entry slot is cut. A 7.2 mm boss around a
4.2 mm pocket has 1.175 mm. These are geometric walls, not tested load ratings.

The nut must bear on plastic in the direction it is pulled: the **upper pocket
roof** for a PCB screw installed downward, and the **lower pocket floor** for a
case screw installed upward. An oversized cylindrical hole alone does not
capture a nut against rotation. A side-loading opening needs access with the
board/lid disassembled and must leave the load-bearing roof or floor intact.
The current slots face inward along x and remain open after assembly. They
retain rotation under screw clamping, but do not retain a loose nut in every
orientation. Work over a tray when opening the case; keep each nut seated while
starting its screw. No adhesive or heat-setting step is used.

Use the actual screw bearing surface to calculate tip position. With the board
top at 7.1 mm and a 4 mm screw, its tip is at `7.1 − 4 = 3.1 mm`. For an upward
8 mm case screw, tip height is `head bearing height + 8`; its head height is
additional. Reusing the previous countersunk screw calculation would shorten
the modeled socket-cap screw by its head height.

The official PCB drawing specifies 2 mm mounting holes. An M1.6 shank has
nominal 0.4 mm diametral clearance. Use only these two mounting holes; do not
drill them larger or place fasteners through electrical GPIO pads.

## Prototype load planes

Coordinates use the case bottom as z = 0, with USB toward +y. These nominal
checks use the 1.6 mm reference PCB and the assumed kit dimensions above.

| Check | PCB mount | Case closure |
| --- | --- | --- |
| Screw direction | Downward | Upward |
| Screw head bearing plane | PCB top z = 7.1 | Counterbore ceiling z = 2.2 |
| Screw tip | z = 3.1 | z = 10.2 |
| Loaded nut position | Top z = 4.7; bottom z = 3.4 | Bottom z = 7.8; top z = 9.4 |
| Pocket vertical opening | z = 3.2–4.7 | z = 7.8–9.6 |
| Nominal screw protrusion past nut | 0.3 | 0.8 |
| End of tip relief | z = 2.4 | z = 11.0 |
| Nominal clearance before bottoming | 0.7 | 0.8 |
| Plastic carrying axial nut load | 0.8 mm roof below PCB | 3.5 mm below nut to post bottom |

The case screws sit in 4.4 mm flat-bottom counterbores 2.2 mm deep. Local base
pads rise to z = 4.0, leaving **1.8 mm of plastic above the counterbore**. With
the conservative 2.1 mm modeled head height, the head bottom is 0.1 mm inside
the base. The lid posts start at z = 4.3, leaving a 0.3 mm assembly gap above
these pads; the outer lid/base interface sets closure height.

Case posts have 7.2 mm outside diameter at x = ±17, y = 0. Their nominal gap to
the straight inner wall is `21 − 17 − 3.6 = 0.4 mm`; their gap to the PCB edge is
`17 − 3.6 − 12.7 = 0.7 mm`. The larger 7.6 mm base pads stop at z = 4.0, below the
PCB, and have a 0.5 mm horizontal gap to its outline.

The shortest PCB screw engagement has less spare length than the case screws.
If the real PCB is thicker or the screw shorter, recalculate
`protrusion = screw_length − PCB_thickness − roof_thickness − nut_thickness`.
The nominal value is `4 − 1.6 − 0.8 − 1.3 = 0.3 mm`. Recheck both complete nut
engagement and bottom clearance rather than accepting a screw simply because
it tightens. The specified 1.05–1.30 mm nut range is not an additional length
tolerance for the screw or board.

## Source review result

The revised `geometry()` and parameters were independently reviewed on
2026-09-06. Constructing the geometry tree and recalculating the dimensions
above succeeded without writing or regenerating enclosure files. No negative
nominal clearance or screw-bottoming conflict was found in this mounting
layout. Mesh validation and renders are separate build outputs.

The PCB posts have **5.2 mm contact collars from z = 4.7–5.5**, above their
6.4 mm nut-pocket bodies. Using the reference header grid, the nearest pad
centre is 4.492 mm from a mounting-hole centre. This gives about **0.992 mm to
the modeled copper edge at collar height**. Below z = 4.7, the wider body has
only **0.192 mm clearance to the 1.1 mm-radius wire-access envelope**. The
collars improve contact clearance but do not make that lower gap larger; avoid
large solder blobs or wire loops in the narrow region.

The new posts are at the antenna end and the case midline. They do not extend
into the existing RESET/BOOT approach paths near the USB end. Both actuators
remain accessible by removing the lid, with board removal still available if
the actual clone or tool differs. The feet do not cover the two case screws.

The M1.6 coupon provides AF3.3/3.5/3.7/3.8 pockets, allowing the narrower standard
nut to be distinguished from the kit's listed AF3.5 nut. It includes an integral
1.6 mm stand-in for the PCB, placing the 4 mm screw's bearing plane at z = 7.1.
Update `board_thickness` if the real board differs; do not add another spacer
on top of the current coupon. The M2
coupon combines AF4.1/4.2/4.3 pockets with 4.2/4.4/4.6 mm counterbores. These
coupons check dimensions and insertion; the assembled case still establishes
the final two-part clamping load path.

## Before printing and assembly

1. Measure nut flats, corners, and thickness; screw head diameter/height and
   under-head length; and the real board thickness, hole pitch, and hole
   positions. Check the driver actually seats in both screw sizes.
2. Print the fastener coupons in the same material, orientation, layer height,
   and compensation settings as the case. Nuts should slide in without cracking
   their pockets, resist rotation, and remain accessible for replacement.
3. Confirm both screws engage the full nut thickness, leave tip clearance, and
   clamp their intended surfaces before tightening. An engaged screw must not
   bottom out against a blind bore or bottom surface first. Tighten by hand;
   neither the thin PCB nor the printed pocket is a torque-test fixture.
4. Inspect all 32 electrical pads from both PCB faces. Bosses, nut slots, screw
   heads, and solder must not contact them. The header grid and pad diameter in
   the reference board model are inferred, so a calculated small gap still
   needs confirmation on the actual board.
5. Confirm the case screw heads stay above the desk plane and the feet remain
   independent of screw access. Use flat-bottom head seats for socket-cap
   screws; the previous conical countersinks are unsuitable.
6. With the lid removed and supported by its wire service loop, locate and
   operate the actual RESET and BOOT actuators without pushing against the
   switch terminals, GPIO pins, or PCB. If the clone differs, unplug it and
   remove its two mounting screws for supported service outside the case.

The board is mounted at its antenna end, so cable insertion still loads a
cantilever. Check board flex and fastener stability with the real USB cable.
Reference meshes cannot establish the actual clone's component clearances or
the printed part's strength. See [PCB accuracy](component-accuracy.md) and
[RESET / BOOT service](enclosure.md#reset--boot-service-access).
