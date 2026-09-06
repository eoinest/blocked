#!/usr/bin/env python3
"""Check nominal assembly solids in Blender; this cannot certify physical fit.

blender --background --python enclosure/check-assembly.py
Run after build.py -- --export. The saved assembly is checked, not the renders.
"""
import hashlib
import json
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(ROOT / 'blocked.blend'))
bpy.context.view_layer.update()


def bounds(obj):
    points = [obj.matrix_world @ Vector(p) for p in obj.bound_box]
    return [(min(p[i] for p in points), max(p[i] for p in points)) for i in range(3)]


def intersection_volume(first, second):
    a, b = bounds(first), bounds(second)
    if any(min(a[i][1], b[i][1]) - max(a[i][0], b[i][0]) <= 1e-5 for i in range(3)):
        return 0.0
    duplicate = first.copy()
    duplicate.data = first.data.copy()
    bpy.context.scene.collection.objects.link(duplicate)
    duplicate.hide_set(False)
    duplicate.modifiers.clear()
    original_modifiers = [(m, m.show_viewport) for m in second.modifiers]
    for modifier, _ in original_modifiers:
        modifier.show_viewport = False
    try:
        modifier = duplicate.modifiers.new('Independent nominal interference check', 'BOOLEAN')
        modifier.operation = 'INTERSECT'
        modifier.solver = 'EXACT'
        modifier.object = second
        bpy.context.view_layer.objects.active = duplicate
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        mesh = bmesh.new()
        mesh.from_mesh(duplicate.data)
        volume = abs(mesh.calc_volume(signed=True))
        mesh.free()
        return volume
    finally:
        bpy.data.objects.remove(duplicate, do_unlink=True)
        for modifier, enabled in original_modifiers:
            modifier.show_viewport = enabled


objects = list(bpy.data.objects)
base, lid, board = (bpy.data.objects[n] for n in ('base', 'lid', 'PCB_S2_MINI'))
headers = [o for o in objects if o.name.startswith('HEADER_KEEPOUT_')]
assert len(headers) == 32, f'Expected 32 header access regions, found {len(headers)}'
switch = [o for o in objects if o.type == 'MESH' and o.name.startswith('Gateron ')]
assert len(switch) >= 8, 'Switch housing, stem, electrical and locating pins must be present'
latches = [o for o in objects if o.name.startswith('SWITCH_SNAP_LATCH_')]
assert len(latches) == 2, 'Both plate-retaining latches must be represented'
switch += latches
service = [o for o in objects if o.name.startswith(('SWITCH_LATCH_SERVICE_KEEPOUT_', 'SWITCH_SOLDER_SERVICE_KEEPOUT'))]
assert len(service) == 3, 'Latch and solder service regions must be present'
travel = [bpy.data.objects[n] for n in ('KEYCAP_FULL_TRAVEL_SHELL', 'KEYCAP_FULL_TRAVEL_SOCKET', 'STEM_FULL_TRAVEL')]
cap = next(o for o in objects if o.name.startswith('1.5u ivory keycap'))
socket = next(o for o in objects if o.name.startswith('KEYCAP_MX_SOCKET'))
components = [o for o in objects if o.type == 'MESH' and (
    'photo-located envelope' in o.name or 'photo-estimated package' in o.name
    or o.name.startswith(('USB-C socket', 'RESET actuator', 'BOOT actuator')))]
assert len(components) >= 7, 'Populated board reference objects are missing'
plug = next(o for o in objects if o.name.startswith('USB_PLUG_KEEPOUT'))
pairs = [(base, lid), (board, base), (board, lid)]
pairs += [(header, case) for header in headers for case in (base, lid)]
pairs += [(part, case) for part in switch + components + [plug] for case in (base, lid)]
pairs += [(part, obstacle) for part in switch for obstacle in [board] + components]
# Service access is checked with the lid removed; the base is not an obstacle in that state.
pairs += [(region, lid) for region in service]
pairs += [(part, case) for part in [cap, socket] + travel for case in (base, lid)]

results = []
for first, second in pairs:
    volume = intersection_volume(first, second)
    results.append({'first': first.name, 'second': second.name,
                    'intersection_mm3': round(volume, 6)})
failures = [r for r in results if r['intersection_mm3'] >= 0.001]
report = {
    'status': 'FAIL' if failures else 'PASS',
    'blend_sha256': hashlib.sha256((ROOT / 'blocked.blend').read_bytes()).hexdigest(),
    'blender_version': bpy.app.version_string,
    'scope': 'Nominal un-beveled solids only. All 32 modeled header access cylinders clear case parts. '
             'Switch references, populated PCB envelopes, and assumed USB plug checked against case and each other as listed. '
             'Includes latch/service clearance to the reinforced lid and illustrative cap clearance to case at rest and full travel.',
    'limits': 'Unmeasured clone, photo-derived components and cable envelope; not physical fit certification. '
              'Actual keycap socket/skirt fit, socket-to-switch internal nesting, clip strength, solder joints, wire bends, screw thread form, heat-set strength and USB insertion flex excluded. '
              'Press-fit insert/plastic overlap is intentional and excluded.',
    'checked_pairs': len(results),
    'failures': failures,
    'results': results,
}
(ROOT / 'assembly-validation.json').write_text(json.dumps(report, indent=2) + '\n')
print('ASSEMBLY_VALIDATION ' + json.dumps({k: v for k, v in report.items() if k != 'results'}))
assert not failures, 'Nominal assembly contains unintended intersections; see assembly-validation.json'
