#!/usr/bin/env python3
"""Check nominal assembly solids in Blender; this cannot certify physical fit.

blender --background --python enclosure/check-assembly.py
Run after build.py -- --export. The saved assembly is checked, not the renders.
"""
import hashlib
import json
import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parent
P = json.loads((ROOT / 'parameters.json').read_text())
C = json.loads((ROOT / 'component-models.json').read_text())
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


audits = []
temporary_probes = []


def audit(name, passed, **evidence):
    audits.append({'check': name, 'status': 'PASS' if passed else 'FAIL', **evidence})


def cylinder_probe(name, radius, bottom, top, x, y):
    """Independent cylindrical access gauge; never added to the saved assembly."""
    bpy.ops.mesh.primitive_cylinder_add(vertices=96, radius=radius, depth=top-bottom,
                                        location=(x, y, (bottom+top)/2))
    obj = bpy.context.object
    obj.name = 'AUDIT_' + name
    temporary_probes.append(obj)
    return obj


def center(obj):
    return [(low + high)/2 for low, high in bounds(obj)]


def near(actual, expected, tolerance=0.01):
    return abs(actual-expected) <= tolerance


def solid_volume(obj):
    mesh = bmesh.new()
    mesh.from_mesh(obj.data)
    mesh.transform(obj.matrix_world)
    volume = abs(mesh.calc_volume(signed=True))
    mesh.free()
    return volume


def annular_support(name, case, x, y, inner_radius, outer_radius, bottom, top):
    """Require the entire independent bearing-ring gauge to remain plastic."""
    outer = cylinder_probe(name, outer_radius, bottom, top, x, y)
    bore = cylinder_probe(name+'_bore', inner_radius, bottom-0.1, top+0.1, x, y)
    modifier = outer.modifiers.new('Independent support gauge bore', 'BOOLEAN')
    modifier.operation = 'DIFFERENCE'
    modifier.solver = 'EXACT'
    modifier.object = bore
    bpy.context.view_layer.objects.active = outer
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    volume = solid_volume(outer)
    supported = intersection_volume(outer, case)
    audit(name, volume > 0 and supported >= volume-0.001,
          gauge_volume_mm3=round(volume, 6), plastic_volume_within_gauge_mm3=round(supported, 6),
          tested_support_thickness_mm=round(top-bottom, 3),
          gauge_inner_radius_mm=inner_radius, gauge_outer_radius_mm=outer_radius,
          scope='Continuous nominal plastic around screw axis; not print-strength or load certification')


def hex_pocket_probe(name, nut, across_flats, bottom, top, sweep_x=0, center_xy=None):
    x, y, _ = center(nut)
    points = [nut.matrix_world @ v.co for v in nut.data.vertices]
    corner = max(points, key=lambda p: math.hypot(p.x-x, p.y-y))
    angle = math.atan2(corner.y-y, corner.x-x)
    if center_xy is not None:
        x, y = center_xy
    radius = across_flats/math.sqrt(3)
    outline = sorted(set((x+dx+radius*math.cos(angle+i*math.pi/3), y+radius*math.sin(angle+i*math.pi/3))
                         for dx in (0, sweep_x) for i in range(6)))
    def cross(o, a, b):
        return (a[0]-o[0])*(b[1]-o[1])-(a[1]-o[1])*(b[0]-o[0])
    def half(points):
        chain = []
        for point in points:
            while len(chain) >= 2 and cross(chain[-2], chain[-1], point) <= 1e-9:
                chain.pop()
            chain.append(point)
        return chain
    outline = half(outline)[:-1]+half(reversed(outline))[:-1]
    count = len(outline)
    vertices = [(px, py, z) for z in (bottom, top) for px, py in outline]
    faces = [tuple(reversed(range(count))), tuple(range(count, 2*count))]
    faces += [(i, (i+1)%count, (i+1)%count+count, i+count) for i in range(count)]
    mesh = bpy.data.meshes.new('Independent hex-pocket gauge')
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new('AUDIT_'+name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    temporary_probes.append(obj)
    return obj


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

# Nominal hardware is checked against plastic, PCB and electrical access, but
# not against its deliberately mating threaded nut/screw partner.
hardware = [o for o in objects if o.type == 'MESH' and
            ('NUT_' in o.name.upper() or 'SCREW_' in o.name.upper())]
nuts = [o for o in hardware if 'NUT_' in o.name.upper()]
screws = [o for o in hardware if 'SCREW_' in o.name.upper()]
audit('Four captive nuts and four socket-cap screws modeled', len(nuts) == len(screws) == 4,
      nuts=[o.name for o in nuts], screws=[o.name for o in screws])
old_hardware = [o.name for o in objects if o.type == 'MESH'
                and ('heat-set' in o.name.lower() or 'PCB_INSERT_' in o.name
                     or 'countersunk' in o.name.lower())]
old_parameters = [name for name in P if 'insert' in name.lower()]
old_stls = [p.name for p in (ROOT / 'stl').glob('*insert*.stl')]
audit('Old heat-set and countersunk design removed', not old_hardware and not old_parameters and not old_stls,
      old_hardware_objects=old_hardware, old_parameters=old_parameters, old_stls=old_stls)
pairs += [(part, case) for part in hardware for case in (base, lid, board)]
pairs += [(part, region) for part in hardware for region in headers]
pairs += [(part, component) for part in hardware for component in components + switch]

# Audit fixtures describe the ordered hardware and chosen print allowances,
# independently of the generation tree. Hex pockets have an open loading side;
# the radial-wall lower bound below applies only to their unopened sides.
# Intentionally retuning parameters after a fit coupon requires reviewing and
# updating these fixtures too: they must not silently inherit a geometry error.
fastener_specs = [
    dict(prefix='CASE', nut_prefix='CASE_NUT_', screw_prefix='CASE_SCREW_', xs=(-17.0, 17.0), y=0.0,
         af=4.0, nut_thickness=1.6, pocket_af=4.2, pocket_bottom=7.8, pocket_top=9.6,
         nut_bottom=7.8, nut_top=9.4, post_radius=3.6,
         shaft_diameter=2.0, length=8.0, head_diameter=4.0, head_height=2.1,
         screw_bottom=0.1, screw_top=10.2, head_bottom=0.1, head_top=2.2,
         relief_diameter=2.2, relief_bottom=2.2, relief_top=11.0),
    dict(prefix='PCB', nut_prefix='PCB_NUT_', screw_prefix='PCB_SCREW_', xs=(-10.2, 10.2), y=-12.35,
         af=3.5, nut_thickness=1.3, pocket_af=3.7, pocket_bottom=3.2, pocket_top=4.7,
         nut_bottom=3.4, nut_top=4.7, post_radius=3.2,
         shaft_diameter=1.6, length=4.0, head_diameter=3.2, head_height=1.7,
         screw_bottom=3.1, screw_top=8.8, head_bottom=7.1, head_top=8.8,
         relief_diameter=1.8, relief_bottom=2.4, relief_top=7.1),
]
for spec in fastener_specs:
    param_prefix = 'board' if spec['prefix'] == 'PCB' else 'case'
    parameter_expectations = {
        param_prefix+'_nut_af': spec['af'],
        param_prefix+'_nut_thickness': spec['nut_thickness'],
        param_prefix+'_nut_pocket_af': spec['pocket_af'],
        param_prefix+'_nut_pocket_height': spec['pocket_top']-spec['pocket_bottom'],
        param_prefix+'_screw_diameter': spec['shaft_diameter'],
        param_prefix+'_screw_length': spec['length'],
        param_prefix+'_screw_clearance': spec['relief_diameter'],
        param_prefix+'_head_diameter': spec['head_diameter'],
        param_prefix+'_head_height': spec['head_height'],
        'board_post_radius' if spec['prefix'] == 'PCB' else 'boss_radius': spec['post_radius'],
    }
    audit(spec['prefix']+' audit fixture matches intended parameter revision',
          all(name in P and near(P[name], value) for name, value in parameter_expectations.items()),
          expected_parameters=parameter_expectations,
          remedy='After intentional fit-coupon retuning, review and update independent checker fixtures as well.')
    family_nuts = sorted((o for o in nuts if o.name.startswith(spec['nut_prefix'])), key=lambda o: center(o)[0])
    family_screws = sorted((o for o in screws if o.name.startswith(spec['screw_prefix'])), key=lambda o: center(o)[0])
    audit(spec['prefix']+' hardware pair count', len(family_nuts) == len(family_screws) == 2)
    for nut, screw, x in zip(family_nuts, family_screws, spec['xs']):
        nb, sb = bounds(nut), bounds(screw)
        nut_af = min(nb[0][1]-nb[0][0], nb[1][1]-nb[1][0])
        audit(nut.name+' dimensions and seating', near(nut_af, spec['af'], 0.02)
              and near(nb[2][0], spec['nut_bottom'], 0.02) and near(nb[2][1], spec['nut_top'], 0.02)
              and near(center(nut)[0], x) and near(center(nut)[1], spec['y']),
              modeled_af_mm=round(nut_af, 4), modeled_z_mm=[round(v, 4) for v in nb[2]],
              expected_af_mm=spec['af'], expected_thickness_mm=spec['nut_thickness'])
        vertices = [screw.matrix_world @ v.co for v in screw.data.vertices]
        head_vertices = [v for v in vertices if math.hypot(v.x-x, v.y-spec['y']) > spec['head_diameter']/2-0.05]
        head_z = [min(v.z for v in head_vertices), max(v.z for v in head_vertices)] if head_vertices else [0, 0]
        audit(screw.name+' ordered cap-head envelope', near(sb[2][0], spec['screw_bottom'], 0.06)
              and near(sb[2][1], spec['screw_top'], 0.06)
              and near(sb[0][1]-sb[0][0], spec['head_diameter'], 0.02)
              and near(head_z[0], spec['head_bottom'], 0.06) and near(head_z[1], spec['head_top'], 0.06)
              and near(center(screw)[0], x) and near(center(screw)[1], spec['y']),
              modeled_total_z_mm=[round(v, 4) for v in sb[2]], modeled_head_z_mm=[round(v, 4) for v in head_z],
              expected_shaft_length_mm=spec['length'], expected_head_height_mm=spec['head_height'],
              limit='Nominal unthreaded envelope; delivered hardware dimensions must be measured')
        gauge = cylinder_probe(f'{spec["prefix"]}_shaft_clearance_{x:+g}', spec['relief_diameter']/2-0.01,
                               spec['relief_bottom']+0.01, spec['relief_top']-0.01, x, spec['y'])
        pairs += [(gauge, obstacle) for obstacle in (base, lid, board)]
        pocket_gauge = hex_pocket_probe(f'{spec["prefix"]}_hex_pocket_{x:+g}', nut, spec['pocket_af']-0.02,
                                       spec['pocket_bottom']+0.01, spec['pocket_top']-0.01)
        pairs += [(pocket_gauge, obstacle) for obstacle in (base, lid)]
        loading_gauge = hex_pocket_probe(f'{spec["prefix"]}_nut_loading_sweep_{x:+g}', nut, spec['af']-0.01,
                                        spec['nut_bottom']+0.01, spec['nut_top']-0.01,
                                        sweep_x=-math.copysign(spec['post_radius']+spec['af']/math.sqrt(3)+0.5, x))
        pairs.append((loading_gauge, lid if spec['prefix'] == 'CASE' else base))
        if spec['prefix'] == 'CASE':
            head_gauge = cylinder_probe(f'CASE_head_counterbore_{x:+g}', 2.19, -0.1, 2.19, x, 0)
            pairs.append((head_gauge, base))
            annular_support(f'CASE_{x:+g} screw-head bearing shoulder', base, x, 0, 1.12, 1.98, 2.21, 3.99)
            annular_support(f'CASE_{x:+g} captive-nut bearing floor', lid, x, 0, 1.12, 1.90, 4.31, 7.79)
        else:
            annular_support(f'PCB_{x:+g} nut retention roof', base, x, spec['y'], 0.92, 1.65, 4.71, 5.49)
    pocket_depth = spec['pocket_top']-spec['pocket_bottom']
    radial_wall = spec['post_radius']-spec['pocket_af']/math.sqrt(3)
    tip_clearance = spec['relief_top']-spec['screw_top'] if spec['prefix'] == 'CASE' else spec['screw_bottom']-spec['relief_bottom']
    protrusion = spec['screw_top']-spec['nut_top'] if spec['prefix'] == 'CASE' else spec['nut_bottom']-spec['screw_bottom']
    audit(spec['prefix']+' nominal fit and remaining side wall',
          spec['pocket_af']-spec['af'] >= 0.19 and pocket_depth-spec['nut_thickness'] >= 0.19
          and radial_wall >= 1.0 and tip_clearance >= 0.5 and protrusion >= 0.29,
          nut_pocket_across_flats_clearance_mm=round(spec['pocket_af']-spec['af'], 3),
          nut_pocket_axial_clearance_mm=round(pocket_depth-spec['nut_thickness'], 3),
          unopened_side_radial_wall_lower_bound_mm=round(radial_wall, 3),
          screw_tip_clearance_to_blind_relief_mm=round(tip_clearance, 3),
          nominal_screw_protrusion_past_nut_mm=round(protrusion, 3),
          nominal_thread_engagement_mm=spec['nut_thickness'],
          scope='Analytical chosen dimensions cross-checked against hardware solids and relief/support gauges; '
                'does not establish printed strength, actual nut chamfers, thread runout, or installation torque')

# Board controls remain reachable after removing the lid, using the expressly
# modeled service approach. They do not imply fingertip clearance or access
# through a closed case, and do not include wires/solder added during assembly.
board_service = [o for o in objects if o.name.startswith(('RESET_SERVICE_KEEPOUT', 'BOOT_SERVICE_KEEPOUT'))]
audit('Both lid-off board-control service approaches modeled', len(board_service) == 2,
      objects=[o.name for o in board_service])
pairs += [(region, obstacle) for region in board_service for obstacle in [base, board] + hardware + components
          if not obstacle.name.startswith(('RESET actuator', 'BOOT actuator'))]

# The independently gauged nominal coupon stations also check that any isolated
# CSG triangle repair did not cap a functional bore, pocket, or loading mouth.
for family, name, x in [('CASE', 'case-fastener-coupon', 0.0), ('PCB', 'board-fastener-coupon', 6.0)]:
    coupon = bpy.data.objects.get(name)
    audit(name+' saved mesh present', coupon is not None and coupon.type == 'MESH')
    if coupon is None:
        continue
    spec = next(s for s in fastener_specs if s['prefix'] == family)
    nut = next((o for o in nuts if o.name.startswith(spec['nut_prefix'])), None)
    if nut is None:
        continue
    pocket = hex_pocket_probe(name+'_nominal_hex_void', nut, spec['pocket_af']-0.02,
                             spec['pocket_bottom']+0.01, spec['pocket_top']-0.01, center_xy=(x, 0))
    entry = hex_pocket_probe(name+'_nominal_nut_entry', nut, spec['af']-0.01,
                            spec['nut_bottom']+0.01, spec['nut_top']-0.01,
                            sweep_x=6.0, center_xy=(x, 0))
    bore = cylinder_probe(name+'_nominal_shaft_bore', spec['relief_diameter']/2-0.01,
                          0.01 if family == 'CASE' else 2.41,
                          10.99 if family == 'CASE' else 7.09, x, 0)
    pairs += [(gauge, coupon) for gauge in (pocket, entry, bore)]
    if family == 'CASE':
        head = cylinder_probe(name+'_nominal_head_counterbore', 2.19, -0.1, 2.19, x, 0)
        pairs.append((head, coupon))
    else:
        annular_support(name+' 1.6 mm PCB stand-in retained', coupon, x, 0, 0.92, 1.65, 5.51, 7.09)

# Verify the reference PCB's drilled features independently of the case cutouts.
# GPIO coordinates remain photo-derived; only mounting-hole diameter and X pitch
# are manufacturer dimensioned. The 3.30 mm Y offset is drawing-derived.
grid = C['board']['photo_inferred_header_grid']
expected_headers = sorted((x, P['board_center_y']-P['board_depth']/2
                           + grid['first_row_y_from_antenna_edge']+row*grid['row_pitch'])
                          for x in grid['column_x'] for row in range(grid['row_count']))
actual_headers = sorted((center(o)[0], center(o)[1]) for o in headers)
audit('32 modeled GPIO access axes preserved', len(actual_headers) == len(expected_headers) == 32
      and all(near(a[0], e[0]) and near(a[1], e[1]) for a, e in zip(actual_headers, expected_headers)),
      coordinate_basis='component-models.json photo-inferred 2.54 mm grid; physical clone unmeasured')
for index, (x, y) in enumerate(expected_headers):
    gauge = cylinder_probe(f'GPIO_drill_{index+1}', grid['hole_diameter']/2-0.01,
                           P['board_bottom']-0.1, P['board_bottom']+P['board_thickness']+0.1, x, y)
    pairs.append((gauge, board))
mount_y = P['board_center_y']-34.3/2+3.30
audit('PCB mounting uses the two dedicated 2 mm holes', near(P['board_mount_x'], 10.2)
      and near(P['board_mount_y'], mount_y) and near(P['board_mount_hole'], 2),
      hole_pitch_x_mm=2*P['board_mount_x'], hole_diameter_mm=P['board_mount_hole'],
      antenna_edge_offset_mm=P['board_mount_y']-(P['board_center_y']-P['board_depth']/2),
      provenance='WEMOS dimension PDF: 20.4 mm X pitch and 2 mm holes; 3.30 mm Y drawing-derived')
for x in (-10.2, 10.2):
    gauge = cylinder_probe(f'PCB_mount_drill_{x:+g}', 0.99, P['board_bottom']-0.1,
                           P['board_bottom']+P['board_thickness']+0.1, x, mount_y)
    pairs.append((gauge, board))

results = []
for first, second in pairs:
    volume = intersection_volume(first, second)
    results.append({'first': first.name, 'second': second.name,
                    'intersection_mm3': round(volume, 6)})
failures = [r for r in results if r['intersection_mm3'] >= 0.001]
audit_failures = [a for a in audits if a['status'] == 'FAIL']
report = {
    'status': 'FAIL' if failures or audit_failures else 'PASS',
    'blend_sha256': hashlib.sha256((ROOT / 'blocked.blend').read_bytes()).hexdigest(),
    'parameters_sha256': hashlib.sha256((ROOT / 'parameters.json').read_bytes()).hexdigest(),
    'checker_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
    'blender_version': bpy.app.version_string,
    'scope': 'Nominal un-beveled solids only. All 32 modeled header access cylinders clear case parts. '
             'Switch references, populated PCB envelopes, and assumed USB plug checked against case and each other as listed. '
             'Includes latch/service clearance to the reinforced lid and illustrative cap clearance to case at rest and full travel. '
             'Captive nut and cap-screw envelopes, hex-pocket voids, inward nut-loading sweeps, shaft reliefs, '
             'case head counterbores, continuous plastic bearing-ring gauges, and PCB drilled features are checked independently. '
             'RESET/BOOT service gauges are tested with the lid removed, excluding their intentional actuator contact.',
    'limits': 'Unmeasured clone, photo-derived components and cable envelope; not physical fit certification. '
              'Actual keycap socket/skirt fit, socket-to-switch internal nesting, clip strength, solder joints, wire bends, screw thread form, '
              'nut chamfers/thread runout, printed strength, tightening torque, and USB insertion flex excluded. '
              'Intentionally mating screw/nut thread regions are excluded from collision pairs. '
              'Nominal nut installation sweeps assume loading the base nuts before the PCB and the lid nuts with the lid removed. '
              'Service gauges do not certify finger access or unknown soldered wire routing.',
    'checked_pairs': len(results),
    'analytical_and_feature_checks': audits,
    'audit_failures': audit_failures,
    'failures': failures,
    'results': results,
}
(ROOT / 'assembly-validation.json').write_text(json.dumps(report, indent=2) + '\n')
print('ASSEMBLY_VALIDATION ' + json.dumps({k: v for k, v in report.items() if k != 'results'}))
for probe in temporary_probes:
    bpy.data.objects.remove(probe, do_unlink=True)
assert not failures and not audit_failures, 'Nominal assembly validation failed; see assembly-validation.json'
