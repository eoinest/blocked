# Print three complete buttons

Download [the single nine-part STL](../enclosure/stl/blocked-three-devices-blank-caps.stl).
It contains **three bases, three lids, and three blank 1.5u-style Tab keycaps** using the
latest socket-hugging USB collar. There are no engraved words or underside IDs
on any cap. No fit coupons or electronics are included in this plate.

The caps use **A2 Flat Tab**: 28 × 18 mm, rounded 2 mm corners, and the roomiest of the
existing three split MX socket fits. This is the recommended first trial from
[the keycap guide](../keycap/printed/README.md); actual switch fit remains unverified.

## Bambu Lab A1

- Import in **millimeters at 100% scale**. The nine parts occupy 98 × 162 mm, centered
  on the 256 × 256 mm bed, with at least 6 mm between parts.
- **Preserve their supplied positions and orientation.** Bases are floor-down;
  lids are top-down; keycaps are face-down with their sockets pointing upward.
  If Bambu Studio asks about multiple objects, keep all nine shells and their
  relative arrangement. Do not auto-orient them.
- Starting settings assume the stock **0.4 mm nozzle and regular PLA**: 0.12 mm
  layers, 0.20 mm first layer, Arachne walls, 4 walls, 100% infill, supports off.
  Use the correct filament and plate preset for your actual spool and bed.
- Slice and inspect the socket walls, open cross recesses, USB bridges and bottom
  screw recesses. A smooth plate gives the blank cap faces a smoother finish;
  textured PEI transfers its texture. No AMS is required.

Let the caps cool fully before trying them. Support the switch body and press
straight down gently; do not force, rotate or glue a tight cap. The existing
[F2 socket tester](../keycap/printed/stl/F2-socket-coupon.stl) can be printed first
if you have not yet established a fit. The narrow split socket walls remain a
physical print-strength and fit check.

The current snug USB collar is still a **prototype requiring a physical fit test**. Its dimensions
assume the board model and require sufficient clearance behind your fully seated
cable shoulder. Test the real board and cable in the
[registered USB cradle](../enclosure/stl/usb-fit-coupon.stl) before committing to
all three complete bases; see [USB fit details](usb-fit.md).

The [validation report](../enclosure/three-device-plate-validation.json) records
nine manifold, connected, positive-volume parts after reimporting the exported
STL; z0 contact, part separation, source hashes and open-socket probes also pass.
These are geometry checks, not a completed slice or physical print.

Rebuild without modifying any existing Blender scene:

```sh
/Applications/Blender.app/Contents/MacOS/Blender \
  --background --factory-startup --threads 4 \
  --python enclosure/two-device-plate.py -- --sets 3
```
