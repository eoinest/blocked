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


def box_probe(name, low, high):
    """Independent Cartesian gauge, in assembled coordinates."""
    bpy.ops.mesh.primitive_cube_add(size=1, location=tuple((a+b)/2 for a,b in zip(low,high)))
    obj = bpy.context.object
    obj.name = 'AUDIT_' + name
    obj.dimensions = tuple(b-a for a,b in zip(low,high))
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
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
audit('Four exposed nuts and four bottom-entry socket-cap screws modeled', len(nuts) == len(screws) == 4,
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
pairs += [(part, component) for part in hardware for component in components + switch + [cap, socket] + travel]

# Independent fixtures for the exposed-nut revision. All four screws point up.
# Changing CAD dimensions requires deliberately reviewing these checks too.
fastener_specs = [
    dict(prefix='CASE', nut_prefix='CASE_NUT_', screw_prefix='CASE_SCREW_', xs=(-17.0,17.0), y=0.0,
         af=4.0, nut_thickness=1.6, nut_bottom=22.0, nut_top=23.6,
         shaft_diameter=2.0, length=20.0, head_diameter=4.0, head_height=2.1,
         head_bottom=2.3, head_top=4.4, screw_top=24.4,
         clearance=2.2, head_bore=4.4, bearing_top=6.2),
    dict(prefix='PCB', nut_prefix='PCB_NUT_', screw_prefix='PCB_SCREW_', xs=(-10.2,10.2), y=-12.35,
         af=3.5, nut_thickness=1.3, nut_bottom=7.1, nut_top=8.4,
         shaft_diameter=1.6, length=6.0, head_diameter=3.2, head_height=1.7,
         head_bottom=1.1, head_top=2.8, screw_top=8.8,
         clearance=1.8, head_bore=3.6, bearing_top=5.5),
]
for spec in fastener_specs:
    prefix = 'board' if spec['prefix'] == 'PCB' else 'case'
    expected = {prefix+'_nut_af':spec['af'], prefix+'_nut_thickness':spec['nut_thickness'],
                prefix+'_screw_diameter':spec['shaft_diameter'], prefix+'_screw_length':spec['length'],
                prefix+'_screw_clearance':spec['clearance'], prefix+'_head_diameter':spec['head_diameter'],
                prefix+'_head_height':spec['head_height'], prefix+'_head_recess_depth':spec['head_top'],
                prefix+'_head_recess_diameter':spec['head_bore']}
    audit(spec['prefix']+' independent stack matches intended revision',
          all(name in P and near(P[name], value) for name,value in expected.items()), expected_parameters=expected)
    family_nuts=sorted((o for o in nuts if o.name.startswith(spec['nut_prefix'])),key=lambda o:center(o)[0])
    family_screws=sorted((o for o in screws if o.name.startswith(spec['screw_prefix'])),key=lambda o:center(o)[0])
    audit(spec['prefix']+' hardware pair count',len(family_nuts)==len(family_screws)==2)
    for nut,screw,x in zip(family_nuts,family_screws,spec['xs']):
        y=spec['y']; nb,sb=bounds(nut),bounds(screw)
        af=min(nb[0][1]-nb[0][0],nb[1][1]-nb[1][0])
        audit(nut.name+' exposed seating',near(af,spec['af'],.02)
              and near(nb[2][0],spec['nut_bottom'],.02) and near(nb[2][1],spec['nut_top'],.02)
              and near(center(nut)[0],x) and near(center(nut)[1],y),
              modeled_z_mm=nb[2],expected_seat_mm=spec['nut_bottom'])
        vertices=[screw.matrix_world @ v.co for v in screw.data.vertices]
        head=[v.z for v in vertices if math.hypot(v.x-x,v.y-y)>spec['head_diameter']/2-.05]
        audit(screw.name+' bottom-entry direction and length',bool(head)
              and near(min(head),spec['head_bottom'],.06) and near(max(head),spec['head_top'],.06)
              and near(sb[2][0],spec['head_bottom'],.06) and near(sb[2][1],spec['screw_top'],.06)
              and near(center(screw)[0],x) and near(center(screw)[1],y),
              head_z_mm=[min(head),max(head)] if head else [],tip_z_mm=sb[2][1],
              nominal_under_head_length_mm=spec['length'])
        bore=cylinder_probe(f'{spec["prefix"]}_through_bore_{x:+g}',spec['clearance']/2-.01,
                            spec['head_top']+.01,spec['nut_bottom']-.01,x,y)
        pairs += [(bore,o) for o in (base,lid,board)]
        head_access=cylinder_probe(f'{spec["prefix"]}_bottom_head_access_{x:+g}',spec['head_bore']/2-.01,
                                  -.5,spec['head_top']-.01,x,y)
        pairs.append((head_access,base))
        # A nut-sized vertical gauge proves there is no roof or side-loading trap.
        # PCB access assumes lid removed; case nut insertion clears the resting cap.
        access=cylinder_probe(f'{spec["prefix"]}_vertical_nut_access_{x:+g}',spec['af']/math.sqrt(3)+.05,
                              spec['nut_bottom']+.01,40,x,y)
        obstacles=[base,board]+components if spec['prefix']=='PCB' else [base,lid,cap,socket]+switch
        pairs += [(access,o) for o in obstacles]
        annular_support(f'{spec["prefix"]}_{x:+g} bottom-head bearing shoulder',base,x,y,
                        spec['clearance']/2+.02,spec['head_diameter']/2-.02,
                        spec['head_top']+.01,spec['bearing_top']-.01)
        if spec['prefix']=='CASE':
            annular_support(f'CASE_{x:+g} exposed-nut bearing land',lid,x,y,1.12,1.9,20.51,21.99)
        else:
            annular_support(f'PCB_{x:+g} nut bears on board',board,x,y,1.02,1.65,5.51,7.09)
    audit(spec['prefix']+' full nut engagement and recessed head',
          spec['screw_top']-spec['nut_top']>=.39 and spec['head_bottom']>=0,
          protrusion_past_nut_mm=round(spec['screw_top']-spec['nut_top'],3),
          thread_engagement_mm=spec['nut_thickness'],head_recess_above_floor_mm=spec['head_bottom'],
          limit='Nominal dimensions; delivered screw/nut/PCB thickness and print fit remain to be checked.')

# Four bearing regions, all at z=5.5; only the antenna pair have screw holes.
audit('Four-corner support dimensions',near(P['board_bottom'],5.5),board_bottom_mm=P['board_bottom'])
for x in (-10.2,10.2):
    annular_support(f'PCB antenna support {x:+g}',base,x,-12.35,1.02,2.4,5.4,5.49)
for name,x,y in [('left',-9.5,17.9),('right',11.0,17.9)]:
    bpy.ops.mesh.primitive_cube_add(size=1,location=(x,y,5.45))
    gauge=bpy.context.object; gauge.name='AUDIT_USB_CORNER_'+name
    gauge.dimensions=(1.98,.98,.08)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    temporary_probes.append(gauge)
    volume=solid_volume(gauge); filled=intersection_volume(gauge,base)
    audit('USB corner '+name+' solid support at matching height',filled>=volume-.001,
          expected_contact_center_mm=[x,y,5.5],contact_footprint_mm=[2,1],filled_mm3=round(filled,6))
    # Contact cannot extend above the underside of the PCB; general board/base
    # collision checks below enforce this. Small footprint is photo-derived.
    bpy.ops.mesh.primitive_cube_add(size=1,location=(x,y,5.55))
    contact=bpy.context.object; contact.name='AUDIT_USB_CORNER_BOARD_'+name
    contact.dimensions=(1.98,.98,.08)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    temporary_probes.append(contact)
    volume=solid_volume(contact); filled=intersection_volume(contact,board)
    audit('USB corner '+name+' contacts PCB underside',filled>=volume-.001,
          reference_board_material_mm3=round(filled,6),limits='Actual clone underside must be bare at contact patch.')

# Foot recesses must not cover any screw entry or driver approach.
for x in (-17.,17.):
    for y in (-15.,15.):
        for spec in fastener_specs:
            for sx in spec['xs']:
                dx=max(abs(sx-x)-4,0); dy=max(abs(spec['y']-y)-4,0)
                gap=math.hypot(dx,dy)-spec['head_bore']/2
                audit(f'Foot {x:+g},{y:+g} clears {spec["prefix"]} screw {sx:+g}',gap>=.99,
                      nominal_gap_mm=round(gap,3))
audit('Foot placement matches accessible screws',near(P.get('foot_x',0),17) and near(P.get('foot_y',0),15))

# Board controls remain reachable after removing the lid, using the expressly
# modeled service approach. They do not imply fingertip clearance or access
# through a closed case, and do not include wires/solder added during assembly.
board_service = [o for o in objects if o.name.startswith(('RESET_SERVICE_KEEPOUT', 'BOOT_SERVICE_KEEPOUT'))]
audit('Both lid-off board-control service approaches modeled', len(board_service) == 2,
      objects=[o.name for o in board_service])
pairs += [(region, obstacle) for region in board_service for obstacle in [base, board] + hardware + components
          if not obstacle.name.startswith(('RESET actuator', 'BOOT actuator'))]

# Tight socket collar: all dimensions below independently specify this revision.
# Plug clearance is CONDITIONAL on the actual seated shoulder reaching y>=19.30.
# Do not interpret a shifted keepout as proof that an unmeasured cable seats.
audit('USB socket collar dimensions and alignment',
      near(P['usb_width'],9.6) and near(P['usb_height'],3.6) and near(P['usb_bottom'],6.9)
      and near(P['usb_corner_radius'],1.65) and near(P['usb_face_y'],19.25)
      and near(P['usb_collar_back'],18.05) and near(P['usb_required_shoulder_y'],19.30),
      throat_mm=[9.6,3.6],center_z_mm=8.7,corner_radius_mm=1.65,
      scope='0.2 mm offset of the photo-derived shell; physical clone fit unverified')
usb_socket=next(o for o in components if o.name.startswith('USB-C socket'))
ub=bounds(usb_socket)
audit('USB socket reference remains aligned with collar',
      near(ub[1][1],18.95) and near(center(usb_socket)[0],0) and near(center(usb_socket)[2],8.7),
      reference_socket_front_y_mm=ub[1][1],reference_socket_center_z_mm=center(usb_socket)[2],
      collar_face_y_mm=19.25,required_cable_shoulder_y_mm=19.30,
      minimum_required_shoulder_gap_ahead_of_socket_mm=.35,
      limits='Required gap is NOT established by measurement or universally guaranteed by USB-IF.')
for label,w,h in [('maximum_overmold',12.85,7.0),('overmold_with_0_05_side_gap',12.95,7.1)]:
    gauge=box_probe('USB_CONDITIONAL_shoulder_path_'+label,(-w/2,19.30,8.7-h/2),(w/2,41,8.7+h/2))
    pairs += [(gauge,case) for case in (base,lid)]
# Negative control: a shoulder closer to the socket really WOULD hit the collar.
blocked=box_probe('USB_unqualified_shoulder_obstruction',(-6.425,18.95,5.2),(6.425,19.25,12.2))
obstruction=intersection_volume(blocked,base)
audit('Conditional seating limitation represented by actual collar obstruction',obstruction>.1,
      obstruction_mm3=round(obstruction,6),physical_seating_verified=False,
      required_action='Compare fully seated bare-board cable position with registered fit cradle.')
# Maximum plug metal rectangle sweeps through the throat; actual rounded metal
# corners are smaller. Mating socket internals are intentionally excluded.
gauge=box_probe('USB_metal_nose_swept_path',(-4.14,12.2,7.485),(4.14,41,9.915))
pairs += [(gauge,case) for case in (base,lid)]
for name,low,high in [
    ('width',(-4.79,18.8,8.69),(4.79,19.2,8.71)),
    ('height',(-.01,18.8,6.91),(.01,19.2,10.49)),
    ('outer_pocket',(-6.74,19.3,8.69),(6.74,20.5,8.71)),
    ('entry_width',(-6.94,20.95,8.6),(6.94,20.99,8.8)),
    ('entry_height',(-.1,20.95,4.71),(.1,20.99,12.69)),
]:
    gauge=box_probe('USB_throat_'+name,low,high)
    pairs.append((gauge,base))
for name,low,high in [
    ('left',(-4.9,18.1,8.66),(-4.82,19.2,8.74)),
    ('right',(4.82,18.1,8.66),(4.9,19.2,8.74)),
    ('lower_0_5mm_lip',(-.1,18.76,6.7),(.1,19.24,6.85)),
    ('above',(-.1,18.1,10.55),(.1,19.2,10.7)),
]:
    gauge=box_probe('USB_collar_material_'+name,low,high)
    volume=solid_volume(gauge);filled=intersection_volume(gauge,base)
    audit('USB collar retains '+name,filled>=volume-.0001,
          gauge_volume_mm3=round(volume,6),plastic_volume_mm3=round(filled,6))
# Check the entire specified PCB-edge relief, including a small print allowance.
gauge=box_probe('USB_PCB_edge_relief',(-7.54,18.06,5.31),(7.54,18.74,7.29))
pairs.append((gauge,base))

usb_coupon=bpy.data.objects.get('usb-fit-coupon')
audit('Registered USB fit cradle saved',usb_coupon is not None and usb_coupon.type=='MESH')
if usb_coupon is not None:
    cb=bounds(usb_coupon)
    audit('USB cradle dimensions and print orientation',
          all(near(b-a,n) for (a,b),n in zip(cb,(30,42,14))) and near(cb[2][0],0),
          expected_dimensions_mm=[30,42,14],actual_bounds_mm=cb)
    pairs += [(usb_coupon,o) for o in [board]+components]
    gauge=box_probe('USB_cradle_CONDITIONAL_shoulder_path',(-6.475,19.30,5.15),(6.475,41,12.25))
    pairs.append((gauge,usb_coupon))
    gauge=box_probe('USB_cradle_metal_nose_path',(-4.14,12.2,7.485),(4.14,41,9.915))
    pairs.append((gauge,usb_coupon))
    for x in (-10.2,10.2):
        annular_support(f'USB cradle antenna support {x:+g}',usb_coupon,x,-12.35,1.02,2.4,5.4,5.49)
        gauge=cylinder_probe(f'USB_cradle_mount_bore_{x:+g}',.89,2.81,5.51,x,-12.35)
        pairs.append((gauge,usb_coupon))
        gauge=cylinder_probe(f'USB_cradle_head_entry_{x:+g}',1.79,-.1,2.79,x,-12.35)
        pairs.append((gauge,usb_coupon))
    for x in (-9.5,11.0):
        gauge=box_probe(f'USB_cradle_plain_support_{x:+g}',(x-.99,17.41,5.41),(x+.99,18.39,5.49))
        volume=solid_volume(gauge);filled=intersection_volume(gauge,usb_coupon)
        audit(f'USB cradle plain support {x:+g}',filled>=volume-.001,
              expected_contact_top_z_mm=5.5,filled_mm3=round(filled,6))

# Nominal coupon station x=0: open through-bore, bottom head access, exposed nut.
for family,name in [('CASE','case-fastener-coupon'),('PCB','board-fastener-coupon')]:
    coupon=bpy.data.objects.get(name)
    audit(name+' saved mesh present',coupon is not None and coupon.type=='MESH')
    if coupon is None: continue
    spec=next(s for s in fastener_specs if s['prefix']==family)
    bore=cylinder_probe(name+'_through_bore',spec['clearance']/2-.01,spec['head_top']+.01,
                        spec['nut_bottom']-.01,0,0)
    head=cylinder_probe(name+'_head_entry',spec['head_bore']/2-.01,-.1,spec['head_top']-.01,0,0)
    exposed=cylinder_probe(name+'_exposed_nut',spec['af']/math.sqrt(3)+.05,spec['nut_bottom']+.01,
                           spec['nut_top']+3,0,0)
    pairs += [(g,coupon) for g in (bore,head,exposed)]

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
             'Exposed nut and bottom-entry screw envelopes, vertical nut access, through bores, four PCB bearing regions, '
             'case head counterbores, continuous plastic bearing-ring gauges, and PCB drilled features are checked independently. '
             'USB overmold paths are conditional on the unverified required shoulder plane at y=19.30; metal-nose path, collar material, PCB relief and registered cradle are checked. '
             'RESET/BOOT service gauges are tested with the lid removed, excluding their intentional actuator contact.',
    'limits': 'Unmeasured clone and photo-derived components; standardized cable envelope is not a measurement of the purchased cable. Not physical fit certification. '
              'Actual keycap socket/skirt fit, socket-to-switch internal nesting, clip strength, solder joints, wire bends, screw thread form, '
              'nut chamfers/thread runout, printed strength, tightening torque, and USB insertion flex excluded. '
              'Intentionally mating screw/nut thread regions are excluded from collision pairs. '
              'PCB nut access assumes lid removed; larger nut-gripping tools may require keycap removal. '
              'Service gauges do not certify finger access or unknown soldered wire routing.',
    'required_physical_checks': ['USB cable must fully seat with its shoulder at least 0.35 mm ahead of actual socket lip; registered cradle test pending.'],
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
