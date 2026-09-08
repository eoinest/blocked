#!/usr/bin/env python3
"""One geometry tree generates both OpenSCAD and Blender STL output.

python3 enclosure/build.py                       # regenerate .scad
blender -b --python enclosure/build.py -- --export # regenerate .scad + STL
No third-party Python packages are needed; STL export runs inside Blender 4+.
All coordinates and exported STL units are millimeters.
"""
from __future__ import annotations

import json
import math
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent
P = json.loads((ROOT / "parameters.json").read_text())
C = json.loads((ROOT / "component-models.json").read_text())
EPS = 0.05


def shape(kind, **data):
    return {"kind": kind, **data}


def box(w, d, h, x=0, y=0, z=0):
    return shape("box", w=w, d=d, h=h, x=x, y=y, z=z)


def rounded(w, d, h, r, x=0, y=0, z=0, top_scale=1):
    return shape("rounded", w=w, d=d, h=h, r=r, x=x, y=y, z=z, top_scale=top_scale)


def cylinder(r, h, x=0, y=0, z=0, top=None):
    return shape("cylinder", r=r, top=r if top is None else top,
                 h=h, x=x, y=y, z=z)


def hexagon(af, h, x=0, y=0, z=0):
    return shape('hex', af=af, h=h, x=x, y=y, z=z)


def frustum(w,d,top_w,top_d,h,x=0,y=0,z=0):
    return shape('frustum',w=w,d=d,top_w=top_w,top_d=top_d,h=h,x=x,y=y,z=z)


def union(*children):
    return shape("union", children=list(children))


def difference(body, *cuts):
    return shape("difference", children=[body, *cuts])


def geometry():
    w, d, h = P["width"], P["depth"], P["base_height"]
    wall, floor, plate = P["wall"], P["floor"], P["plate"]
    r, sx, br = P["corner_radius"], P["screw_x"], P["boss_radius"]
    assert w > P["board_width"] + 2 * wall
    assert d > P["board_depth"] + 2 * wall
    assert sx - br > P["board_width"] / 2 + P["board_clearance"]
    assert sx + br <= w / 2 - wall - P["lid_clearance"] + EPS
    assert floor > P["pad_recess"] + 1
    assert 0 < P["switch_opening"] < 18
    assert P["usb_bottom"] >= floor
    assert P["usb_bottom"] + P["usb_height"] < h
    assert P['case_pad_top']-P['case_head_recess_depth'] >= 1.8-EPS
    assert P['board_bottom']-P['board_head_recess_depth'] >= 2.7-EPS
    band, inset = P['bottom_band_height'], P['bottom_inset']
    shell = difference(
        union(rounded(w - 2*inset, d - 2*inset, band + EPS, r-inset),
              rounded(w, d, h-band, r, z=band)),
        rounded(w - 2 * wall, d - 2 * wall, h, r - wall, z=floor),
    )
    additions = []
    # Two existing mounting holes clamp the PCB; two USB-end strips support it.
    for x in (-P['board_mount_x'], P['board_mount_x']):
        additions.append(cylinder(P['board_post_radius'],P['board_bottom']-floor+EPS,
                                  x=x,y=P['board_mount_y'],z=floor-EPS))
    for x in (P['front_support_left_x'],P['front_support_right_x']):
        collar_z=P['board_bottom']-P['front_support_contact_height']
        additions.extend([
            frustum(P['front_support_base_width'],P['front_support_base_depth'],
                    P['front_support_width'],P['front_support_depth'],collar_z-floor+EPS,
                    x=x,y=P['front_support_y'],z=floor-EPS),
            box(P['front_support_width'],P['front_support_depth'],P['front_support_contact_height']+EPS,
                x=x,y=P['front_support_y'],z=collar_z-EPS)])
    for x in (-sx,sx):
        additions.append(cylinder(P['case_pad_radius'],P['case_pad_top']-floor+EPS,x=x,z=floor-EPS))
    cuts = [box(P["usb_width"], 2 * wall + 2, P["usb_height"],
                y=d / 2 - wall / 2, z=P["usb_bottom"])]
    for x in (-P['board_mount_x'],P['board_mount_x']):
        cuts.extend([
            cylinder(P['board_screw_clearance']/2,P['board_bottom']+2*EPS,
                     x=x,y=P['board_mount_y'],z=-EPS),
            cylinder(P['board_head_recess_diameter']/2,P['board_head_recess_depth']+EPS,
                     x=x,y=P['board_mount_y'],z=-EPS)])
    for x in (-sx, sx):
        cuts.extend([
            cylinder(P['case_screw_clearance']/2,P['case_pad_top']+2*EPS,x=x,z=-EPS),
            cylinder(P['case_head_recess_diameter']/2,P['case_head_recess_depth']+EPS,x=x,z=-EPS)])
    for x in (-P['foot_x'],P['foot_x']):
        for y in (-P['foot_y'],P['foot_y']):
            cuts.append(rounded(P["pad_size"], P["pad_size"],
                                P["pad_recess"] + EPS, 1, x=x, y=y, z=-EPS))
    base = difference(union(shell, *additions), *cuts)

    # Lid local z=0 is its underside; skirt extends down into the base.
    sw = w - 2 * wall - 2 * P["lid_clearance"]
    sd = d - 2 * wall - 2 * P["lid_clearance"]
    skirt = difference(
        rounded(sw, sd, P["skirt_height"] + EPS, 1.7, z=-P["skirt_height"]),
        rounded(sw - 2 * P["skirt_wall"], sd - 2 * P["skirt_wall"],
                P["skirt_height"] + 3 * EPS, 0.5, z=-P["skirt_height"] - EPS),
    )
    post_length = h - P['case_post_bottom']
    posts = [cylinder(br, post_length + EPS, x=x, z=-post_length) for x in (-sx, sx)]
    lid_cuts = [box(P["switch_opening"], P["switch_opening"], plate + 2 * EPS, z=-EPS)]
    for x in (-sx, sx):
        lid_cuts.append(cylinder(P['case_screw_clearance']/2,post_length+plate+2*EPS,
                                x=x,z=-post_length-EPS))
    chamfer = P['lid_chamfer']
    lid_skin = union(rounded(w, d, plate-chamfer+EPS, r),
                     rounded(w, d, chamfer, r, z=plate-chamfer,
                             top_scale=(w-2*chamfer)/w))
    # Ribs meet the registration skirt but leave the clip land at 1.5 mm.
    ribs = [box(P['lid_rib_width'],P['lid_rib_length'],P['lid_rib_depth']+EPS,
                y=y,z=-P['lid_rib_depth']) for y in (-P['lid_rib_y'],P['lid_rib_y'])]
    lid = difference(union(lid_skin, skirt, *posts, *ribs), *lid_cuts)
    # Apertures increase left-to-right; small edge notches mark 1, 2, 3.
    coupon_cuts = []
    for index, (x, opening) in enumerate(((-21.5, 14.0), (0, 14.1), (21.5, 14.2))):
        coupon_cuts.append(box(opening, opening, plate + 2 * EPS, x=x, z=-EPS))
        for tick in range(index + 1):
            coupon_cuts.append(box(0.8, 1.5, plate + 2 * EPS,
                                   x=x + 1.5 * tick - 0.75 * index,
                                   y=-13, z=-EPS))
    coupon = difference(rounded(66, 26, plate, 2), *coupon_cuts)
    # Open-nut coupons test through-shafts and bottom head counterbores.
    # Each nominal center station reproduces the entire screw bearing stack.
    case_coupon_cuts=[]
    case_top=h+plate
    for index,(x,head) in enumerate(((-12,4.2),(0,4.4),(12,4.6))):
        case_coupon_cuts.extend([
            cylinder(P['case_screw_clearance']/2,case_top+2*EPS,x=x,z=-EPS),
            cylinder(head/2,P['case_head_recess_depth']+EPS,x=x,z=-EPS)])
        for tick in range(index+1):
            case_coupon_cuts.append(box(.8,1.5,case_top+1,x=x+1.5*tick-.75*index,y=-6,z=-EPS))
    case_coupon=difference(union(rounded(36,12,1.5,1.5),
                                  *[box(2*br,8,case_top-1.4,x=x,z=1.4)
                                    for x in (-12,0,12)]),*case_coupon_cuts)
    board_coupon_cuts=[]
    board_top=P['board_bottom']+P['board_thickness']
    for index,(x,head) in enumerate(((-12,3.4),(0,3.6),(12,3.8))):
        board_coupon_cuts.extend([
            cylinder(P['board_screw_clearance']/2,board_top+2*EPS,x=x,z=-EPS),
            cylinder(head/2,P['board_head_recess_depth']+EPS,x=x,z=-EPS)])
        for tick in range(index+1):
            board_coupon_cuts.append(box(.8,1.5,board_top+1,x=x+1.5*tick-.75*index,y=-5,z=-EPS))
    board_coupon=difference(union(rounded(36,10,1.5,1.5),
                                   *[cylinder(P['board_post_radius'],board_top-1.4,x=x,z=1.4)
                                     for x in (-12,0,12)]),*board_coupon_cuts)
    return {"base":base,"lid":lid,"fit-coupon":coupon,
            "case-fastener-coupon":case_coupon,"board-fastener-coupon":board_coupon}


def scad(node, level=0):
    tab = "  " * level
    k = node["kind"]
    if k in ("union", "difference"):
        return (tab + k + "() {\n" +
                "".join(scad(c, level + 1) for c in node["children"]) + tab + "}\n")
    x, y, z = (node[t] for t in ("x", "y", "z"))
    prefix = tab + f"translate([{x:g}, {y:g}, {z:g}]) "
    if k == 'hex':
        return prefix + f"cylinder(h={node['h']:g}, r={node['af']/math.sqrt(3):g}, $fn=6);\n"
    if k == "cylinder":
        return prefix + f"cylinder(h={node['h']:g}, r1={node['r']:g}, r2={node['top']:g}, $fn=64);\n"
    w, d, h = (node[t] for t in ("w", "d", "h"))
    if k == 'frustum':
        return prefix + f"linear_extrude(height={h:g},scale=[{node['top_w']/w:g},{node['top_d']/d:g}]) square([{w:g},{d:g}],center=true);\n"
    if k == "box":
        return prefix + f"translate([{-w/2:g}, {-d/2:g}, 0]) cube([{w:g}, {d:g}, {h:g}]);\n"
    r = node["r"]
    return prefix + (f"linear_extrude(height={h:g}, scale={node['top_scale']:g}) offset(r={r:g}, $fn=64) "
                     f"square([{w-2*r:g}, {d-2*r:g}], center=true);\n")


def write_scad(parts):
    result = '// Generated by build.py from parameters.json. Units: mm.\n'
    result += '// Change parameters.json and rerun build.py to edit dimensions.\n'
    result += 'part = "assembly"; // [assembly,base,lid,fit-coupon,case-fastener-coupon,board-fastener-coupon,print-layout]\n'
    for name, body in parts.items():
        result += f"module {name.replace('-', '_')}() {{\n{scad(body, 1)}}}\n"
    result += f'''\nif (part == "base") base();
else if (part == "lid") translate([0,0,{P['plate']}]) rotate([180,0,0]) lid();
else if (part == "fit-coupon") fit_coupon();
else if (part == "case-fastener-coupon") case_fastener_coupon();
else if (part == "board-fastener-coupon") board_fastener_coupon();
else if (part == "print-layout") {{
    base();
    translate([{P['width'] + 6},0,{P['plate']}]) rotate([180,0,0]) lid();
}} else {{
    color("#b8bbc0") base();
    translate([0,0,{P['base_height']}]) color("#c4c7cb") lid();
}}
'''
    (ROOT / "blocked.scad").write_text(result)


def export_blender(parts):
    import bpy
    import bmesh
    from mathutils import Vector
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.context.scene.unit_settings.system = 'METRIC'
    bpy.context.scene.unit_settings.scale_length = 0.001

    def primitive(n):
        k = n["kind"]
        h = n["h"]
        if k == 'hex':
            points=[(n['af']/math.sqrt(3)*math.cos(a*math.tau/6),
                     n['af']/math.sqrt(3)*math.sin(a*math.tau/6)) for a in range(6)]
            upper=points
        elif k == "cylinder":
            points = [(n["r"] * math.cos(a * math.tau / 64),
                       n["r"] * math.sin(a * math.tau / 64)) for a in range(64)]
            upper = [(n["top"] * math.cos(a * math.tau / 64),
                      n["top"] * math.sin(a * math.tau / 64)) for a in range(64)]
        elif k in ("box",'frustum'):
            w, d = n['w'] / 2, n['d'] / 2
            points = [(-w, -d), (w, -d), (w, d), (-w, d)]
            upper = points
            if k=='frustum':
                upper=[(x*n['top_w']/n['w'],y*n['top_d']/n['d']) for x,y in points]
        else:
            w, d, r = n['w'] / 2, n['d'] / 2, n['r']
            points = []
            for cx, cy, start in [(w-r, d-r, 0), (-w+r, d-r, 90),
                                   (-w+r, -d+r, 180), (w-r, -d+r, 270)]:
                for i in range(17):
                    a = math.radians(start + i * 90 / 16)
                    points.append((cx + r * math.cos(a), cy + r * math.sin(a)))
            upper = [(x*n.get('top_scale',1), y*n.get('top_scale',1)) for x,y in points]
        count = len(points)
        verts = [(x + n['x'], y + n['y'], n['z']) for x, y in points]
        verts += [(x + n['x'], y + n['y'], n['z'] + h) for x, y in upper]
        faces = [tuple(range(count - 1, -1, -1)), tuple(range(count, 2 * count))]
        faces += [(i, (i + 1) % count, (i + 1) % count + count, i + count)
                  for i in range(count)]
        mesh = bpy.data.meshes.new('primitive')
        mesh.from_pydata(verts, [], faces)
        mesh.update()
        obj = bpy.data.objects.new('primitive', mesh)
        bpy.context.collection.objects.link(obj)
        return obj

    def evaluate(n):
        if n['kind'] not in ('union', 'difference'):
            return primitive(n)
        obj = evaluate(n['children'][0])
        for child in n['children'][1:]:
            cutter = evaluate(child)
            mod = obj.modifiers.new('CSG', 'BOOLEAN')
            mod.operation = 'UNION' if n['kind'] == 'union' else 'DIFFERENCE'
            mod.solver = 'EXACT'
            mod.object = cutter
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.modifier_apply(modifier=mod.name)
            bpy.data.objects.remove(cutter, do_unlink=True)
        return obj

    output = ROOT / 'stl'
    output.mkdir(exist_ok=True)
    report = {}
    objects = {}
    for name, tree in parts.items():
        obj = evaluate(tree)
        obj.name = name
        if name == 'lid':
            for v in obj.data.vertices:
                v.co.y = -v.co.y
                v.co.z = P['plate'] - v.co.z
        mesh = bmesh.new()
        mesh.from_mesh(obj.data)
        # Exact CSG can leave coincident vertices at coplanar primitive joins.
        # Weld only sub-micron duplicates; dimensions and fit features stay intact.
        bmesh.ops.remove_doubles(mesh,verts=list(mesh.verts),dist=0.000001)
        bmesh.ops.dissolve_degenerate(mesh,edges=list(mesh.edges),dist=0.000001)
        bmesh.ops.recalc_face_normals(mesh, faces=list(mesh.faces))
        bmesh.ops.triangulate(mesh, faces=list(mesh.faces))
        # Blender's exact CSG occasionally omits a single bore-wall triangle
        # where coaxial counterbores meet. Close only three-edge boundary loops;
        # any larger or non-manifold defect still fails the validation below.
        boundary = [edge for edge in mesh.edges if edge.is_boundary]
        repaired_triangles = 0
        if boundary:
            repaired_triangles = len(bmesh.ops.holes_fill(mesh,edges=boundary,sides=3)['faces'])
            bmesh.ops.recalc_face_normals(mesh,faces=list(mesh.faces))
        non_manifold = sum(not e.is_manifold for e in mesh.edges)
        volume = mesh.calc_volume(signed=True)
        unseen = set(mesh.verts)
        components = 0
        while unseen:
            components += 1
            pending = [unseen.pop()]
            while pending:
                vertex = pending.pop()
                for edge in vertex.link_edges:
                    other = edge.other_vert(vertex)
                    if other in unseen:
                        unseen.remove(other)
                        pending.append(other)
        bounds = [[min(v.co[i] for v in mesh.verts), max(v.co[i] for v in mesh.verts)]
                  for i in range(3)]
        report[name] = {'non_manifold_edges': non_manifold,
                        'repaired_csg_triangles': repaired_triangles,
                        'connected_components': components,
                        'dimensions_mm': [round(b-a, 3) for a, b in bounds],
                        'volume_mm3': round(volume, 3),
                        'triangles': len(mesh.faces)}
        if non_manifold or volume <= 0 or components != 1:
            print('INVALID_EDGES',[(len(e.link_faces),[tuple(round(c,6) for c in v.co) for v in e.verts])
                                    for e in mesh.edges if not e.is_manifold])
            raise RuntimeError(f'Invalid printable mesh: {name}: {report[name]}')
        mesh.to_mesh(obj.data)
        mesh.free()
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.wm.stl_export(filepath=str(output / f'{name}.stl'), export_selected_objects=True)
        objects[name] = obj
    (ROOT / 'mesh-validation.json').write_text(json.dumps(report, indent=2) + '\n')
    if '--geometry-only' in sys.argv:
        print('MESH_VALIDATION ' + json.dumps(report))
        return

    # Render actual assembly meshes; cap/switch/PCB shapes are illustrative envelopes.
    for name in ('fit-coupon', 'case-fastener-coupon','board-fastener-coupon'):
        objects[name].hide_render = True
        objects[name].hide_set(True)
    lid = objects['lid']
    lid.rotation_euler.x = math.pi
    lid.location.z = P['base_height'] + P['plate']
    def material(name, color):
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        mat.diffuse_color = (*color, 1)
        shader = mat.node_tree.nodes.get('Principled BSDF')
        shader.inputs['Base Color'].default_value = (*color, 1)
        shader.inputs['Roughness'].default_value = 0.38
        return mat
    dark = material('charcoal legend and underside', (0.026, 0.03, 0.035))
    ink = material('matte near-black printed legend', (0.002, 0.0025, 0.003))
    ink_shader = ink.node_tree.nodes.get('Principled BSDF')
    ink_shader.inputs['Roughness'].default_value = 1
    ink_shader.inputs['Specular IOR Level'].default_value = 0
    ivory = material('white ABS keycap | approximate finish', (0.84, 0.81, 0.74))
    case_silver = material('satin silver finish', (0.48, 0.51, 0.55))
    case_shader = case_silver.node_tree.nodes.get('Principled BSDF')
    case_shader.inputs['Metallic'].default_value = 0.72
    case_shader.inputs['Roughness'].default_value = 0.3
    pcb_blue = material('S2 Mini purple solder mask', (0.16, 0.035, 0.3))
    copper = material('exposed plated pads', (0.65, 0.4, 0.09))
    black = material('IC and switch actuator', (0.02, 0.023, 0.025))
    green = material('Gateron green POM stem', (0.19, 0.5, 0.23))
    milky = material('Gateron nylon lower housing', (0.73, 0.74, 0.64))
    silver = material('USB shell', (0.45, 0.48, 0.5))
    brass = material('Fastener detail highlight', (0.56, 0.31, 0.065))
    brass.node_tree.nodes.get('Principled BSDF').inputs['Metallic'].default_value = 0.75
    clear = material('clear switch housing', (0.72, 0.78, 0.81))
    clear_shader = clear.node_tree.nodes.get('Principled BSDF')
    clear_shader.inputs['Transmission Weight'].default_value = 0.55
    clear_shader.inputs['Roughness'].default_value = 0.18
    print_collection = bpy.data.collections.new('PRINTABLE | STL parts, millimeters')
    reference_collection = bpy.data.collections.new('REFERENCE ONLY | approximate bought parts')
    studio_collection = bpy.data.collections.new('STUDIO | render camera and lighting')
    keepout_collection = bpy.data.collections.new('ENGINEERING | header and USB keepouts, nominal only')
    for col in (print_collection, reference_collection, studio_collection,keepout_collection):
        bpy.context.scene.collection.children.link(col)
    def move_to(obj, collection):
        for previous in list(obj.users_collection):
            previous.objects.unlink(obj)
        collection.objects.link(obj)
    for obj in objects.values():
        move_to(obj, print_collection)
    for name in ('base', 'lid'):
        objects[name].data.materials.clear()
        objects[name].data.materials.append(case_silver)
        objects[name].data.materials.append(dark)
        for face in objects[name].data.polygons:
            face.material_index = int(name == 'base' and face.center.z < P['bottom_band_height'] - 0.01)
        bevel = objects[name].modifiers.new('Render-only edge highlights', 'BEVEL')
        bevel.width = 0.15
        bevel.segments = 2
    plate_top = P['base_height'] + P['plate']
    # Sculpted 1.5u purchased-keycap reference: tapered skirt and shallow dish.
    # Hollow illustrative shell/socket: assumptions, not a manufactured cap CAD.
    cap_bottom = plate_top + P['keycap_rest_gap']
    cap_top = cap_bottom + P['keycap_height']
    def outline(width, depth, radius):
        points = []
        for cx, cy, start in [(width/2-radius, depth/2-radius, 0),
                               (-width/2+radius, depth/2-radius, 90),
                               (-width/2+radius, -depth/2+radius, 180),
                               (width/2-radius, -depth/2+radius, 270)]:
            for index in range(17):
                angle = math.radians(start + index*90/16)
                points.append((cx + radius*math.cos(angle), cy + radius*math.sin(angle)))
        return points
    bottom_ring = outline(P['keycap_width'], P['keycap_depth'], 1.1)
    top_ring = outline(P['keycap_width']-4, P['keycap_depth']-4, 1.35)
    rings = [[(x,y,cap_bottom) for x,y in bottom_ring]]
    for scale in (1, .96, .85, .7, .55, .4, .25, .1):
        rings.append([(x*scale, y*scale, cap_top-1.2*(1-scale*scale)) for x,y in top_ring])
    count = len(bottom_ring)
    verts = [v for ring in rings for v in ring]
    faces = [tuple(range(count-1, -1, -1))]
    for ring in range(len(rings)-1):
        for i in range(count):
            j = (i+1) % count
            faces.append((ring*count+i, ring*count+j, (ring+1)*count+j, (ring+1)*count+i))
    center = len(verts)
    verts.append((0,0,cap_top-1.2))
    for i in range(count):
        faces.append(((len(rings)-1)*count+i, (len(rings)-1)*count+(i+1)%count, center))
    cap_mesh = bpy.data.meshes.new('Sculpted 1.5u keycap reference mesh')
    cap_mesh.from_pydata(verts, [], faces)
    cap_mesh.update()
    cap = bpy.data.objects.new('1.5u ivory keycap | sculpted reference, NOT printable', cap_mesh)
    bpy.context.collection.objects.link(cap)
    cap.data.materials.append(ivory)
    cavity=primitive(rounded(P['keycap_width']-2*P['keycap_wall'],
                              P['keycap_depth']-2*P['keycap_wall'],6.55,1,
                              z=cap_bottom-EPS,top_scale=.78))
    bpy.context.view_layer.objects.active=cap
    modifier=cap.modifiers.new('Illustrative hollow underside','BOOLEAN')
    modifier.operation='DIFFERENCE'; modifier.solver='EXACT'; modifier.object=cavity
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.data.objects.remove(cavity,do_unlink=True)
    socket_bottom=plate_top+P['keycap_socket_bottom_above_plate']
    socket_clearance=P['keycap_socket_cross_clearance']
    socket_boss=evaluate(difference(
        cylinder(P['keycap_socket_outer_diameter']/2,cap_top-1.6-socket_bottom,z=socket_bottom),
        union(box(4+socket_clearance,1.1+socket_clearance,
                  P['keycap_socket_recess_depth']+EPS,z=socket_bottom-EPS),
              box(1.3+socket_clearance,4+socket_clearance,
                  P['keycap_socket_recess_depth']+EPS,z=socket_bottom-EPS))))
    socket_boss.name='KEYCAP_MX_SOCKET | illustrative blind cross recess, not measured OEM geometry'
    socket_boss.data.materials.clear(); socket_boss.data.materials.append(ivory)
    for face in socket_boss.data.polygons: face.material_index=0
    for face in cap.data.polygons:
        face.use_smooth = True
    bevel = cap.modifiers.new('Soft molded rim and skirt', 'BEVEL')
    bevel.width = 0.24
    bevel.segments = 3
    bevel = cap.modifiers.new('Weighted normals', 'WEIGHTED_NORMAL')
    switch_lower_z=plate_top-6.6
    switch_body = primitive(box(14,14,6.6,z=switch_lower_z))
    switch_top = evaluate(union(rounded(15.9,15.7,.7+EPS,.7,z=plate_top),
                               rounded(14.9,14.7,4.3,.7,z=plate_top+.7,top_scale=.72)))
    switch_stem = evaluate(union(box(4,1.1,3.4,z=plate_top+5),
                                box(1.3,4,3.4,z=plate_top+5)))
    for obj,name,mat in [(switch_body,'Gateron lower housing | drawing-based envelope',milky),
                         (switch_top,'Gateron upper housing | drawing-based envelope',clear),
                         (switch_stem,'Gateron cross stem | published cross, unverified height',green)]:
        obj.name=name
        obj.data.materials.clear()
        obj.data.materials.append(mat)
        for face in obj.data.polygons: face.material_index=0
    switch_extras=[]
    switch_clips=[]
    for direction in (-1,1):
        clip=evaluate(union(box(5,.3,1.65,y=direction*6.95,z=P['base_height']-1.7),
                            box(5,.85,.5,y=direction*7.375,z=P['base_height']-.55)))
        clip.name=f'SWITCH_SNAP_LATCH_{direction:+d} | approximate engaged reference'
        clip.data.materials.clear(); clip.data.materials.append(milky)
        for face in clip.data.polygons: face.material_index=0
        switch_clips.append(clip); switch_extras.append(clip)
    for x,y in C['switch']['drawing_grid_pin_positions']['electrical']:
        obj=primitive(box(.55,.3,2.8,x=x,y=y,z=switch_lower_z-2.8))
        obj.name='Gateron electrical pin | drawing-grid position, approximate blade section'
        obj.data.materials.append(silver)
        switch_extras.append(obj)
    for x,y in [[0,0],*C['switch']['drawing_grid_pin_positions']['plastic_locators']]:
        obj=primitive(cylinder(3.85/2 if x==0 else .8,2.8,x=x,y=y,z=switch_lower_z-2.8))
        obj.name='Gateron center/locator post | nominal envelope'
        obj.data.materials.append(milky)
        switch_extras.append(obj)
    board_bottom = P['board_bottom']
    board_top=board_bottom+P['board_thickness']
    grid=C['board']['photo_inferred_header_grid']
    header_holes=[(x,P['board_center_y']-P['board_depth']/2+grid['first_row_y_from_antenna_edge']+row*grid['row_pitch'])
                  for x in grid['column_x'] for row in range(grid['row_count'])]
    mount_holes=[(x,P['board_mount_y']) for x in (-P['board_mount_x'],P['board_mount_x'])]
    board_shape=union(rounded(P['board_width'],P['board_depth'],P['board_thickness'],4.2,
                              y=P['board_center_y'],z=board_bottom),
                      rounded(P['board_width'],25,P['board_thickness'],1,
                              y=P['board_center_y']+P['board_depth']/2-12.5,z=board_bottom))
    board= evaluate(difference(board_shape,
                     box(1.9,10,P['board_thickness']+2*EPS,x=-P['board_width']/2+.95,
                         y=P['board_center_y']-P['board_depth']/2+31.6,z=board_bottom-EPS),
                     *[cylinder(grid['hole_diameter']/2,P['board_thickness']+2*EPS,x=x,y=y,z=board_bottom-EPS)
                       for x,y in header_holes],
                     *[cylinder(P['board_mount_hole']/2,P['board_thickness']+2*EPS,x=x,y=y,z=board_bottom-EPS)
                       for x,y in mount_holes]))
    board.name = 'PCB_S2_MINI'
    board['accuracy']='Official footprint/hole X; remaining geometry derived or unverified. See component-models.json.'
    board.data.materials.clear()
    board.data.materials.append(pcb_blue)
    for face in board.data.polygons: face.material_index=0
    board_extras=[]
    for holes,outer,inner,label in [(header_holes,grid['pad_diameter']/2,grid['hole_diameter']/2,'Electrical pad'),
                                    (mount_holes,1.75,P['board_mount_hole']/2,'Mounting annulus')]:
        for index,(x,y) in enumerate(holes):
            for z in (board_bottom-.025,board_top):
                obj=evaluate(difference(cylinder(outer,.025,x=x,y=y,z=z),
                                         cylinder(inner,.025+2*EPS,x=x,y=y,z=z-EPS)))
                obj.name=f'{label} {index+1} | pad OD photo-estimated'
                obj.data.materials.clear(); obj.data.materials.append(copper)
                for face in obj.data.polygons: face.material_index=0
                board_extras.append(obj)
    env=C['board_photo_envelopes']
    socket=env['usb']
    usb_y=P['board_center_y']+P['board_depth']/2+socket['overhang_beyond_pcb']-socket['length']/2
    usb=evaluate(difference(box(socket['width'],socket['length'],socket['height'],y=usb_y,z=board_top),
                             box(7.6,socket['length']+1,2.1,y=usb_y,z=board_top+.55)))
    usb.name = 'USB-C socket | photo-derived dimensions and 0.3 mm overhang, unverified clone'
    usb.data.materials.clear()
    usb.data.materials.append(silver)
    for face in usb.data.polygons:
        face.material_index = 0
    for name in ('esp32','crystal','regulator','reset','boot','led'):
        data=env[name]
        obj=primitive(box(data['width'],data['depth'],data['height'],x=data['x'],y=data['y'],z=board_top))
        obj.name=f'{name.upper()} | approximate photo-located envelope, not assembly CAD'
        obj.data.materials.append(silver if name=='crystal' else ivory if name in ('reset','boot','led') else black)
        board_extras.append(obj)
        if name in ('reset','boot'):
            actuator=primitive(box(.9,1.8,1.4,x=data['x']+(-1.8 if name=='reset' else 1.8),y=data['y'],z=board_top+.55))
            actuator.name=f'{name.upper()} actuator | approximate photo envelope'
            actuator.data.materials.append(black); board_extras.append(actuator)
    for index,(x,y,w,d) in enumerate(env['passives']):
        obj=primitive(box(w,d,.8,x=x,y=y,z=board_top))
        obj.name=f'Passive {index+1} | photo-estimated package and placement'
        obj.data.materials.append(ivory); board_extras.append(obj)
    # Visible feet are the four 8x8x1 mm pieces specified by the BOM.
    for x in (-P['foot_x'],P['foot_x']):
        for y in (-P['foot_y'],P['foot_y']):
            obj=primitive(rounded(8,8,1,1,x=x,y=y,z=-.5))
            obj.name='8 x 8 x 1 mm rubber foot | trim-to-size geometry'
            obj.data.materials.append(black); board_extras.append(obj)
    # Keep every header hole accessible throughout the enclosure's cavity.
    header_keepouts=[]
    for index,(x,y) in enumerate(header_holes):
        obj=primitive(cylinder(1.1,P['base_height']-P['floor'],x=x,y=y,z=P['floor']))
        obj.name=f'HEADER_KEEPOUT_{index+1:02d}'
        obj.display_type='WIRE'; obj.hide_render=True
        obj.color=(1,.25,.03,1)
        obj['purpose']='Nominal GPIO solder/wire access; must not intersect case or mounting posts.'
        move_to(obj,keepout_collection); header_keepouts.append(obj)
    service_keepouts=[]
    for direction in (-1,1):
        obj=primitive(box(6,1.8,3,y=direction*8.1,z=P['base_height']-3.05))
        obj.name=f'SWITCH_LATCH_SERVICE_KEEPOUT_{direction:+d}'
        obj['purpose']='Illustrative access beside latch, with lid removed; no guaranteed tool model.'
        obj.display_type='WIRE'; obj.hide_render=True
        move_to(obj,keepout_collection); service_keepouts.append(obj)
    solder_access=primitive(box(12,12,4,z=switch_lower_z-4))
    solder_access.name='SWITCH_SOLDER_SERVICE_KEEPOUT | access with lid removed'
    solder_access.display_type='WIRE'; solder_access.hide_render=True
    move_to(solder_access,keepout_collection); service_keepouts.append(solder_access)
    travel_refs=[]
    for source,name in ((cap,'KEYCAP_FULL_TRAVEL_SHELL'),(socket_boss,'KEYCAP_FULL_TRAVEL_SOCKET'),
                        (switch_stem,'STEM_FULL_TRAVEL')):
        obj=source.copy(); obj.data=source.data.copy(); obj.modifiers.clear()
        bpy.context.collection.objects.link(obj); obj.name=name
        obj.location.z-=C['switch']['published_dimensions']['travel_max']
        obj.display_type='WIRE'; obj.hide_render=True
        obj['purpose']='3.4 mm depressed position. Socket/housing internal nesting unverified.'
        move_to(obj,keepout_collection); travel_refs.append(obj)
    def wire_path(name,points,mat,radius=.45):
        curve=bpy.data.curves.new(name,'CURVE'); curve.dimensions='3D'
        spline=curve.splines.new('POLY'); spline.points.add(len(points)-1)
        for point,co in zip(spline.points,points): point.co=(*co,1)
        curve.bevel_depth=radius; curve.bevel_resolution=4
        obj=bpy.data.objects.new(name,curve); bpy.context.collection.objects.link(obj)
        obj.data.materials.append(mat); return obj
    red_wire=material('GPIO4 insulated wire',(0.55,.025,.015))
    wires=[wire_path('WIRE_GPIO4 | illustrative 30AWG route, fit after soldering',
                     [(-3.81,2.54,12.9),(-5.5,2.54,12.8),(-7.5,-1,12),(-8.89,-2.95,9),(-8.89,-2.95,7.75)],red_wire),
           wire_path('WIRE_GND | illustrative 30AWG route, fit after soldering',
                     [(2.54,5.08,12.9),(5.5,6.8,12.7),(8.89,7.21,10.2),(8.89,7.21,7.75)],black)]
    for x,y in C['switch']['drawing_grid_pin_positions']['electrical']:
        obj=primitive(cylinder(.7,1.8,x=x,y=y,z=switch_lower_z-2.5))
        obj.name='Switch pin insulation sleeve | approximate heat-shrink envelope'
        obj.data.materials.append(black); switch_extras.append(obj)
    cable_body=primitive(rounded(12,18,6,1.2,y=29,z=board_top+1.6-3))
    cable_body.name='USB_CABLE_PLUG | 12x18x6 illustrative overmold; actual cable unknown'
    cable_body.data.materials.append(black)
    cable=wire_path('USB_CABLE | illustrative 3.5 mm cable',
                     [(0,38,board_top+1.6),(0,45,board_top+1.6),(5,54,board_top+1.6),(14,64,board_top+1.6)],black,1.75)
    cable_keepout=primitive(box(12,18,6,y=29,z=board_top+1.6-3))
    cable_keepout.name='USB_PLUG_KEEPOUT | assumed envelope, verify actual cable'
    cable_keepout.display_type='WIRE'; cable_keepout.hide_render=True
    move_to(cable_keepout,keepout_collection)
    # These approaches are meaningful with the lid removed. They intentionally
    # cross the closed lid, and certify only the stated narrow tool envelope.
    button_service_keepouts=[]
    for name,tool_x,face_x in (('RESET',-16,-12.25),('BOOT',16,13.25)):
        obj=evaluate(union(box(abs(tool_x-face_x),1.5,1.5,
                               x=(tool_x+face_x)/2,y=15.1,z=7.6),
                           box(1.5,1.5,16.4,x=tool_x,y=15.1,z=7.6)))
        obj.name=f'{name}_SERVICE_KEEPOUT | lid-off 1.5 mm blunt-tool approach, unverified board'
        obj.display_type='WIRE'; obj.hide_render=True
        obj['purpose']='Lid-off access only: test against base and PCB, not the removed lid.'
        move_to(obj,keepout_collection); button_service_keepouts.append(obj)
    case_nuts, screws = [], []
    for x in (-P['screw_x'],P['screw_x']):
        nut=evaluate(difference(
            hexagon(P['case_nut_af'],P['case_nut_thickness'],x=x,z=plate_top),
            cylinder(P['case_screw_diameter']/2,P['case_nut_thickness']+2*EPS,
                     x=x,z=plate_top-EPS)))
        nut.name=f'CASE_NUT_M2_{x:+g} | kit AF, assumed thickness, no threads'
        nut.data.materials.clear(); nut.data.materials.append(silver)
        for face in nut.data.polygons: face.material_index=0
        case_nuts.append(nut)
        head_top=P['case_head_recess_depth']
        screw=evaluate(difference(
            union(cylinder(P['case_head_diameter']/2,P['case_head_height'],
                           x=x,z=head_top-P['case_head_height']),
                  cylinder(P['case_screw_diameter']/2,P['case_screw_length']+EPS,x=x,z=head_top-EPS)),
            hexagon(1.5,1.1,x=x,z=head_top-P['case_head_height']-EPS)))
        screw.name=f'CASE_SCREW_M2_x20_{x:+g} | conservative socket-cap envelope, unthreaded'
        screw.data.materials.clear(); screw.data.materials.append(silver)
        for face in screw.data.polygons: face.material_index=0
        screws.append(screw)
    board_mount_refs=[]
    for x in (-P['board_mount_x'],P['board_mount_x']):
        nut_bottom=board_top
        nut=evaluate(difference(
            hexagon(P['board_nut_af'],P['board_nut_thickness'],x=x,y=P['board_mount_y'],z=nut_bottom),
            cylinder(P['board_screw_diameter']/2,P['board_nut_thickness']+2*EPS,
                     x=x,y=P['board_mount_y'],z=nut_bottom-EPS)))
        nut.name=f'PCB_NUT_M1_6_{x:+g} | kit AF, assumed thickness, no threads'
        nut.data.materials.clear(); nut.data.materials.append(silver)
        for face in nut.data.polygons: face.material_index=0
        board_mount_refs.append(nut)
        head_top=P['board_head_recess_depth']
        screw=evaluate(difference(
            union(cylinder(P['board_screw_diameter']/2,P['board_screw_length']+EPS,
                           x=x,y=P['board_mount_y'],z=head_top-EPS),
                  cylinder(P['board_head_diameter']/2,P['board_head_height'],
                           x=x,y=P['board_mount_y'],z=head_top-P['board_head_height'])),
            hexagon(1.5,1.0,x=x,y=P['board_mount_y'],z=head_top-P['board_head_height']-EPS)))
        screw.name=f'PCB_SCREW_M1_6_x6_{x:+g} | conservative socket-cap envelope, unthreaded'
        screw.data.materials.clear(); screw.data.materials.append(silver)
        for face in screw.data.polygons: face.material_index=0
        board_mount_refs.append(screw)
    bpy.ops.object.text_add(location=(-9.3, -4.3, cap_top + 1))
    legend = bpy.context.object
    legend.name = 'blocked legend | visual only'
    legend.data.body = 'blocked'
    legend.data.align_x = 'LEFT'
    legend.data.size = 2.25
    legend.data.extrude = 0
    legend.data.materials.append(ink)
    bpy.ops.object.convert(target='MESH')
    legend = bpy.context.object
    legend.name = 'blocked legend | reference only'
    conform = legend.modifiers.new('Conform ink to sculpted cap', 'SHRINKWRAP')
    conform.target = cap
    conform.wrap_method = 'PROJECT'
    conform.use_project_z = True
    conform.use_negative_direction = True
    conform.use_positive_direction = False
    conform.offset = 0.025
    for obj in (cap,socket_boss,switch_body,switch_top,switch_stem,board,usb,legend,*case_nuts,*screws,
                *switch_extras,*board_extras,*board_mount_refs,*wires,cable_body,cable):
        move_to(obj, reference_collection)
    # Validate the modeled GPIO access cylinders against the printable parts.
    # This proves only this nominal geometry, not the unmeasured physical clone.
    def intersection_volume(subject,cutter):
        copy=subject.copy(); copy.data=subject.data.copy()
        bpy.context.collection.objects.link(copy)
        copy.modifiers.clear()
        mod=copy.modifiers.new('Nominal interference check','BOOLEAN')
        mod.operation='INTERSECT'; mod.solver='EXACT'; mod.object=cutter
        bpy.context.view_layer.objects.active=copy
        bpy.ops.object.modifier_apply(modifier=mod.name)
        bm=bmesh.new(); bm.from_mesh(copy.data)
        volume=abs(bm.calc_volume(signed=True)); bm.free()
        bpy.data.objects.remove(copy,do_unlink=True)
        return volume
    vertices,faces=[],[]
    for obj in header_keepouts:
        offset=len(vertices)
        vertices += [tuple(v.co) for v in obj.data.vertices]
        faces += [tuple(i+offset for i in p.vertices) for p in obj.data.polygons]
    mesh=bpy.data.meshes.new('Temporary header keepout bundle')
    mesh.from_pydata(vertices,[],faces); mesh.update()
    bundle=bpy.data.objects.new('Temporary header keepout bundle',mesh)
    bpy.context.collection.objects.link(bundle)
    clearance_report={
        'scope':'Nominal modeled geometry only; physical clone dimensions and component heights unverified.',
        'header_keepout_count':len(header_keepouts),
        'header_keepout_radius_mm':1.1,
        'header_keepout_intersection_base_mm3':intersection_volume(objects['base'],bundle),
        'header_keepout_intersection_lid_mm3':intersection_volume(objects['lid'],bundle),
        'pcb_intersection_base_mm3':intersection_volume(objects['base'],board),
        'pcb_intersection_lid_mm3':intersection_volume(objects['lid'],board),
        'switch_housing_intersection_lid_mm3':intersection_volume(objects['lid'],switch_top)+intersection_volume(objects['lid'],switch_body),
        'switch_latches_intersection_lid_mm3':sum(intersection_volume(objects['lid'],o) for o in switch_clips),
        'service_keepouts_intersection_lid_mm3':sum(intersection_volume(objects['lid'],o) for o in service_keepouts),
        'depressed_keycap_shell_intersection_lid_mm3':intersection_volume(objects['lid'],travel_refs[0]),
        'reset_boot_service_intersection_base_mm3':sum(intersection_volume(objects['base'],o) for o in button_service_keepouts),
        'reset_boot_service_intersection_pcb_mm3':sum(intersection_volume(board,o) for o in button_service_keepouts),
        'illustrative_keycap_depressed_gap_mm':round(P['keycap_rest_gap']-C['switch']['published_dimensions']['travel_max'],3)
    }
    bpy.data.objects.remove(bundle,do_unlink=True)
    for key,value in clearance_report.items():
        if key.endswith('_mm3') and value>0.001:
            raise RuntimeError(f'Nominal mounting collision: {key}={value}')
    (ROOT/'clearance-validation.json').write_text(json.dumps(clearance_report,indent=2)+'\n')
    ground = primitive(box(2000, 2000, 1, z=-1.7))
    ground.name = 'Studio floor'
    ground.data.materials.append(material('warm studio backdrop', (0.7, 0.68, 0.64)))
    move_to(ground, studio_collection)
    bpy.ops.object.camera_add(location=(64, -95, 65))
    cam = bpy.context.object
    cam.rotation_euler = (Vector((0, 0, 12)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    cam.data.type = 'ORTHO'
    cam.data.ortho_scale = 91
    bpy.context.scene.camera = cam
    move_to(cam, studio_collection)
    for location, energy, size in [((25, 0, 90), 180000, 70), ((-45, 25, 50), 80000, 60)]:
        bpy.ops.object.light_add(type='AREA', location=location)
        light = bpy.context.object
        light.data.energy = energy
        light.data.shape = 'DISK'
        light.data.size = size
        light.rotation_euler = (Vector((0, 0, 10)) - light.location).to_track_quat('-Z', 'Y').to_euler()
        move_to(light, studio_collection)
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 48
    scene.world.color = (0.3, 0.3, 0.3)
    scene.render.resolution_x = 1100
    scene.render.resolution_y = 850
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.render.filepath = str(ROOT / 'preview.png')
    bpy.ops.object.select_all(action='DESELECT')
    objects['base'].select_set(True)
    bpy.context.view_layer.objects.active = objects['base']
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type == 'VIEW_3D':
                area.spaces.active.region_3d.view_perspective = 'CAMERA'
                area.spaces.active.clip_end = 10000
                area.spaces.active.shading.color_type = 'MATERIAL'
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / 'blocked.blend'))
    if '--mounting-only' not in sys.argv and '--key-mounting-only' not in sys.argv:
        bpy.ops.render.render(write_still=True)
    cam.location = (64, 95, 65)
    cam.rotation_euler = (Vector((0, 0, 12)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    scene.render.filepath = str(ROOT / 'rear.png')
    if '--mounting-only' not in sys.argv and '--key-mounting-only' not in sys.argv:
        bpy.ops.render.render(write_still=True)
    lid.location.z += 22
    for obj in (cap,socket_boss,switch_body,switch_top,switch_stem,legend,*case_nuts,*switch_extras):
        obj.location.z += 22
    for obj in (*wires,cable,cable_body): obj.hide_render=True
    for obj in screws:
        obj.location.z -= 12
    ground.location.z = -14
    cam.location = (68, 84, 94)
    cam.rotation_euler = (Vector((0, 0, 26)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    cam.data.ortho_scale = 110
    scene.render.filepath = str(ROOT / 'exploded.png')
    if '--mounting-only' not in sys.argv and '--key-mounting-only' not in sys.argv:
        bpy.ops.render.render(write_still=True)
    # Dedicated mounting diagram using actual mounting-hole coordinates.
    # Board and sectioned lid are lifted; all four screws remain below the base.
    lid.hide_render = True
    objects['base'].hide_render = True
    for obj in (cap,socket_boss,switch_body,switch_top,switch_stem,legend,*switch_extras):
        obj.hide_render = True
    for obj in case_nuts:
        obj.location.z=22
    for obj in screws:
        obj.location.z=-12
    cutaway_base=evaluate(difference(parts['base'],
                           box(60,4,30,y=-20,z=P['floor']),
                           box(4,22,30,x=-22,y=-10,z=P['floor']),
                           box(4,22,30,x=22,y=-10,z=P['floor'])))
    cutaway_base.name='Mounting view cutaway base | four PCB supports stay in position'
    cutaway_lid=evaluate(difference(parts['lid'],box(27,60,50,z=-30)))
    cutaway_lid.location.z=P['base_height']+18
    cutaway_lid.name='Mounting view sectioned raised lid | exposed top nut seats'
    for obj in (cutaway_base,cutaway_lid):
        obj.data.materials.clear();obj.data.materials.append(case_silver)
        for face in obj.data.polygons: face.material_index=0
        move_to(obj,studio_collection)
    for obj in (board,usb,*[o for o in board_extras if not o.name.startswith('8 x 8')]):
        obj.location.z+=8
    for obj in board_mount_refs:
        obj.location.z=12 if obj.name.startswith('PCB_NUT') else -9
    for obj in [*case_nuts,*[o for o in board_mount_refs if o.name.startswith('PCB_NUT')]]:
        obj.data.materials.clear();obj.data.materials.append(copper)
        for face in obj.data.polygons:face.material_index=0
    for x in (-P['board_mount_x'],P['board_mount_x']):
        obj=primitive(cylinder(.06,20,x=x,y=P['board_mount_y'],z=0))
        obj.name='Mounting-hole alignment guide | diagram only'
        obj.data.materials.append(copper);move_to(obj,studio_collection)
    cam.location = (72,-100,125)
    target = Vector((0,0,16))
    cam.rotation_euler = (target - cam.location).to_track_quat('-Z', 'Y').to_euler()
    cam.data.ortho_scale = 125
    scene.render.resolution_x = 1200
    scene.render.resolution_y = 1200
    # Labels sit in the camera plane, never hidden by the model.
    camera_rotation = cam.rotation_euler.to_quaternion()
    right = camera_rotation @ Vector((1,0,0))
    up = camera_rotation @ Vector((0,1,0))
    forward = camera_rotation @ Vector((0,0,-1))
    def diagram_text(body, x, y, size):
        bpy.ops.object.text_add(location=cam.location+forward*20+right*x+up*y)
        obj = bpy.context.object
        obj.name = 'Mounting callout | ' + body
        obj.rotation_euler = cam.rotation_euler
        obj.data.body = body
        obj.data.size = size
        obj.data.materials.append(ink)
        move_to(obj, studio_collection)
    diagram_text('BOTTOM SCREWS / EXPOSED TOP NUTS', -56, 54, 2.8)
    diagram_text('PCB and sectioned lid lifted; screws enter from below', -56, 48, 1.8)
    diagram_text('Four PCB supports: two mounting posts + two plain USB-end pads', -56, 43, 1.65)
    diagram_text('PCB: M1.6 x 6 screws below; AF3.5 nuts rest on top of the PCB', -56, -43, 1.8)
    diagram_text('Case: M2 x 20 screws below; AF4 nuts rest openly on the lid', -56, -49, 1.8)
    diagram_text('Confirm screw lengths and bare PCB contact areas on your actual board', -56, -55, 1.65)
    scene.render.filepath = str(ROOT / 'mounting.png')
    if '--key-mounting-only' not in sys.argv:
        bpy.ops.render.render(write_still=True)
    # Key retention detail: sectioned purchased parts on the left, lid underside
    # on the right. These presentation copies never alter the saved assembly.
    for col in (print_collection,reference_collection,studio_collection):
        for obj in col.objects:
            if obj.type not in ('CAMERA','LIGHT') and obj!=ground:
                obj.hide_render=True
    ground.location.z=-18
    section_material=material('key mount section face',(0.36,.39,.43))
    def section_copy(source,name,shift_x=0,lift=0,cut=True):
        obj=source.copy(); obj.data=source.data.copy(); obj.modifiers.clear()
        bpy.context.collection.objects.link(obj)
        obj.location=(0,0,0); obj.rotation_euler=(0,0,0); obj.hide_render=False
        if cut:
            cutter=primitive(box(60,80,100,x=-30.02,z=-10))
            mod=obj.modifiers.new('Presentation section only','BOOLEAN')
            mod.operation='DIFFERENCE'; mod.solver='EXACT'; mod.object=cutter
            bpy.context.view_layer.objects.active=obj; bpy.ops.object.modifier_apply(modifier=mod.name)
            bpy.data.objects.remove(cutter,do_unlink=True)
        obj.location.x=shift_x; obj.location.z=lift
        if source.name.startswith('SWITCH_SNAP_LATCH'):
            obj.data.materials.clear(); obj.data.materials.append(copper)
            for face in obj.data.polygons: face.material_index=0
        obj.name=name; move_to(obj,studio_collection); return obj
    key_lid=evaluate(difference(parts['lid'],
                               box(60,80,80,x=-30.02,z=-30),
                               box(80,80,30,z=-35)))
    key_lid.location=(-23,0,P['base_height'])
    key_lid.data.materials.clear(); key_lid.data.materials.append(section_material)
    for face in key_lid.data.polygons: face.material_index=0
    key_lid.name='Key detail | sectioned lid; lower case posts omitted'
    move_to(key_lid,studio_collection)
    for obj in (switch_body,switch_top,switch_stem,*switch_extras):
        section_copy(obj,'Key detail section | '+obj.name,-23)
    for obj in (cap,socket_boss):
        section_copy(obj,'Key detail raised section | '+obj.name,-23,8)
    # Underside inspection copy, with tall case posts clipped away in this view.
    underside=evaluate(difference(parts['lid'],box(80,80,30,z=-35)))
    for vertex in underside.data.vertices:
        vertex.co.x+=25
        vertex.co.y=-vertex.co.y
        vertex.co.z=18-vertex.co.z
    underside.name='Key detail underside | full ribs and clip land; tall case posts omitted'
    underside.data.materials.clear(); underside.data.materials.append(section_material)
    for face in underside.data.polygons: face.material_index=0
    move_to(underside,studio_collection)
    for source in (switch_body,*switch_extras):
        obj=section_copy(source,'Key detail underside | '+source.name,cut=False)
        for vertex in obj.data.vertices:
            vertex.co.x+=25
            vertex.co.y=-vertex.co.y
            vertex.co.z=18-(vertex.co.z-P['base_height'])
    cam.location=(-68,-110,94)
    cam.rotation_euler=(Vector((0,0,22))-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.ortho_scale=113
    scene.render.resolution_x=1500; scene.render.resolution_y=1500
    camera_rotation=cam.rotation_euler.to_quaternion()
    right=camera_rotation @ Vector((1,0,0)); up=camera_rotation @ Vector((0,1,0))
    forward=camera_rotation @ Vector((0,0,-1))
    diagram_text('KEY MOUNTING',-52,44,3.2)
    diagram_text('MX press-fit cap + snap-in switch; no extra screws or glue',-52,39,1.9)
    diagram_text('Section: cap lifted 8 mm',-52,33,1.7)
    diagram_text('Underside: ribs, latches and solder access',-2,33,1.65)
    diagram_text('Cap: hollow shell and blind cross socket press onto the MX stem',-52,-31,1.8)
    diagram_text('Switch: flange above 1.5 mm plate; two latches (orange) catch underneath',-52,-36,1.65)
    diagram_text('Square opening prevents rotation; two 2 mm ribs stiffen the lid',-52,-41,1.8)
    diagram_text('3.4 mm travel leaves 0.8 mm nominal skirt gap; verify with purchased cap',-52,-46,1.65)
    diagram_text('Socket, latch shape and seating are illustrative; physical fit testing required',-52,-51,1.55)
    scene.render.filepath=str(ROOT/'key-mounting.png')
    bpy.ops.render.render(write_still=True)
    print('MESH_VALIDATION ' + json.dumps(report))


def render_supports():
    """Presentation-only view of the saved, validated base; never resave assembly."""
    import bpy
    from mathutils import Vector
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'blocked.blend'))
    scene=bpy.context.scene
    base=bpy.data.objects['base']
    ground=bpy.data.objects.get('Studio floor')
    for obj in scene.objects:
        obj.hide_render=obj not in (base,ground) and obj.type not in ('CAMERA','LIGHT')
    highlight=bpy.data.materials.new('Support-contact highlight | diagram only')
    highlight.diffuse_color=(.8,.25,.045,1)
    highlight.use_nodes=True
    highlight.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.8,.25,.045,1)
    highlight.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.7
    base.data.materials.append(highlight)
    highlight_index=len(base.data.materials)-1
    for face in base.data.polygons:
        c=face.center
        near_post=any((c.x-x)**2+(c.y-P['board_mount_y'])**2 < 2.7**2 for x in (-P['board_mount_x'],P['board_mount_x']))
        near_pad=any(abs(c.x-x)<1.6 and abs(c.y-P['front_support_y'])<1.1 for x in (P['front_support_left_x'],P['front_support_right_x']))
        if 2.01<c.z<5.51 and (near_post or near_pad):face.material_index=highlight_index
    cam=scene.camera
    cam.location=(0,-25,140)
    cam.rotation_euler=(Vector((0,0,4))-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.ortho_scale=73
    rotation=cam.rotation_euler.to_quaternion()
    right=rotation @ Vector((1,0,0));up=rotation @ Vector((0,1,0));forward=rotation @ Vector((0,0,-1))
    ink=bpy.data.materials.new('Support diagram ink');ink.diffuse_color=(.008,.008,.008,1)
    def label(body,x,y,size):
        bpy.ops.object.text_add(location=cam.location+forward*20+right*x+up*y)
        obj=bpy.context.object;obj.rotation_euler=cam.rotation_euler
        obj.data.body=body;obj.data.size=size;obj.data.materials.append(ink)
    label('FOUR PCB SUPPORTS',-32,32,2.5)
    label('USB end: two plain 2 x 1 mm pads; no screws or PCB holes',-32,26,1.3)
    label('Antenna end: two screw posts use the existing PCB holes',-32,-25,1.3)
    label('All four orange contacts meet the PCB underside at 5.5 mm',-32,-30,1.25)
    label('Confirm the USB-end contact strips are bare on your actual board',-32,-34,1.1)
    scene.render.resolution_x=1200;scene.render.resolution_y=1200
    scene.render.filepath=str(ROOT/'supports.png')
    bpy.ops.render.render(write_still=True)


if __name__ == '__main__':
    if '--supports-only' in sys.argv:
        render_supports()
        sys.exit(0)
    geometry_parts = geometry()
    write_scad(geometry_parts)
    if '--export' in sys.argv:
        export_blender(geometry_parts)
        if '--geometry-only' not in sys.argv:
            render_supports()
