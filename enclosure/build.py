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
EPS = 0.05


def shape(kind, **data):
    return {"kind": kind, **data}


def box(w, d, h, x=0, y=0, z=0):
    return shape("box", w=w, d=d, h=h, x=x, y=y, z=z)


def rounded(w, d, h, r, x=0, y=0, z=0):
    return shape("rounded", w=w, d=d, h=h, r=r, x=x, y=y, z=z)


def cylinder(r, h, x=0, y=0, z=0, top=None):
    return shape("cylinder", r=r, top=r if top is None else top,
                 h=h, x=x, y=y, z=z)


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
    assert floor > P["pad_recess"] + 1
    assert 0 < P["switch_opening"] < 18
    assert P["usb_bottom"] >= floor
    assert P["usb_bottom"] + P["usb_height"] < h
    shell = difference(
        rounded(w, d, h, r),
        rounded(w - 2 * wall, d - 2 * wall, h, r - wall, z=floor),
    )
    additions = [cylinder(br, h, x=x) for x in (-sx, sx)]
    # Small foam-covered pads. Move these to bare PCB areas after inspecting yours.
    for x in (-P["support_x"], P["support_x"]):
        for y in (P["board_center_y"] - P["support_y_offset"],
                  P["board_center_y"] + P["support_y_offset"]):
            additions.append(box(P["support_size"], P["support_size"],
                                 P["support_height"] + EPS, x=x, y=y,
                                 z=floor - EPS))
    # Outside-edge locators do not clamp the board or require mounting holes.
    locator_x = P["board_width"] / 2 + P["board_clearance"] + 0.5
    for x in (-locator_x, locator_x):
        for y in (-9, 10):
            additions.append(box(1, 3, P["support_height"] + P["foam_thickness"] + 0.8,
                                 x=x, y=y, z=floor - EPS))
    front_y = P["board_center_y"] - P["board_depth"] / 2 - P["board_clearance"] - 0.5
    additions.append(box(6, 1, P["support_height"] + P["foam_thickness"] + 0.8,
                         y=front_y, z=floor - EPS))
    cuts = [box(P["usb_width"], 2 * wall + 2, P["usb_height"],
                y=d / 2 - wall / 2, z=P["usb_bottom"])]
    cuts += [cylinder(P["pilot_diameter"] / 2, P["pilot_depth"] + EPS,
                      x=x, z=h - P["pilot_depth"]) for x in (-sx, sx)]
    for x in (-12, 12):
        for y in (-13, 13):
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
        *[cylinder(br + P["lid_clearance"], P["skirt_height"] + 3 * EPS,
                   x=x, z=-P["skirt_height"] - EPS) for x in (-sx, sx)],
    )
    lid_cuts = [box(P["switch_opening"], P["switch_opening"], plate + 2 * EPS, z=-EPS)]
    for x in (-sx, sx):
        lid_cuts += [
            cylinder(P["screw_clearance"] / 2, plate + 2 * EPS, x=x, z=-EPS),
            cylinder(P["screw_clearance"] / 2, 1.05,
                     top=P["head_diameter"] / 2, x=x, z=plate - 1),
        ]
    lid = difference(union(rounded(w, d, plate, r), skirt), *lid_cuts)
    # Apertures increase left-to-right; small edge notches mark 1, 2, 3.
    coupon_cuts = []
    for index, (x, opening) in enumerate(((-21.5, 14.0), (0, 14.1), (21.5, 14.2))):
        coupon_cuts.append(box(opening, opening, plate + 2 * EPS, x=x, z=-EPS))
        for tick in range(index + 1):
            coupon_cuts.append(box(0.8, 1.5, plate + 2 * EPS,
                                   x=x + 1.5 * tick - 0.75 * index,
                                   y=-13, z=-EPS))
    coupon = difference(rounded(66, 26, plate, 2), *coupon_cuts)
    return {"base": base, "lid": lid, "fit-coupon": coupon}


def scad(node, level=0):
    tab = "  " * level
    k = node["kind"]
    if k in ("union", "difference"):
        return (tab + k + "() {\n" +
                "".join(scad(c, level + 1) for c in node["children"]) + tab + "}\n")
    x, y, z = (node[t] for t in ("x", "y", "z"))
    prefix = tab + f"translate([{x:g}, {y:g}, {z:g}]) "
    if k == "cylinder":
        return prefix + f"cylinder(h={node['h']:g}, r1={node['r']:g}, r2={node['top']:g}, $fn=64);\n"
    w, d, h = (node[t] for t in ("w", "d", "h"))
    if k == "box":
        return prefix + f"translate([{-w/2:g}, {-d/2:g}, 0]) cube([{w:g}, {d:g}, {h:g}]);\n"
    r = node["r"]
    return prefix + (f"linear_extrude({h:g}) offset(r={r:g}, $fn=64) "
                     f"square([{w-2*r:g}, {d-2*r:g}], center=true);\n")


def write_scad(parts):
    result = '// Generated by build.py from parameters.json. Units: mm.\n'
    result += '// Change parameters.json and rerun build.py to edit dimensions.\n'
    result += 'part = "assembly"; // [assembly,base,lid,fit-coupon,print-layout]\n'
    for name, body in parts.items():
        result += f"module {name.replace('-', '_')}() {{\n{scad(body, 1)}}}\n"
    result += f'''\nif (part == "base") base();
else if (part == "lid") translate([0,0,{P['plate']}]) rotate([180,0,0]) lid();
else if (part == "fit-coupon") fit_coupon();
else if (part == "print-layout") {{
    base();
    translate([{P['width'] + 6},0,{P['plate']}]) rotate([180,0,0]) lid();
}} else {{
    color("#25282b") base();
    translate([0,0,{P['base_height']}]) color("#383c40") lid();
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
        if k == "cylinder":
            points = [(n["r"] * math.cos(a * math.tau / 64),
                       n["r"] * math.sin(a * math.tau / 64)) for a in range(64)]
            upper = [(n["top"] * math.cos(a * math.tau / 64),
                      n["top"] * math.sin(a * math.tau / 64)) for a in range(64)]
        elif k == "box":
            w, d = n['w'] / 2, n['d'] / 2
            points = [(-w, -d), (w, -d), (w, d), (-w, d)]
            upper = points
        else:
            w, d, r = n['w'] / 2, n['d'] / 2, n['r']
            points = []
            for cx, cy, start in [(w-r, d-r, 0), (-w+r, d-r, 90),
                                   (-w+r, -d+r, 180), (w-r, -d+r, 270)]:
                for i in range(17):
                    a = math.radians(start + i * 90 / 16)
                    points.append((cx + r * math.cos(a), cy + r * math.sin(a)))
            upper = points
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
        bmesh.ops.recalc_face_normals(mesh, faces=list(mesh.faces))
        bmesh.ops.triangulate(mesh, faces=list(mesh.faces))
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
                        'connected_components': components,
                        'dimensions_mm': [round(b-a, 3) for a, b in bounds],
                        'volume_mm3': round(volume, 3),
                        'triangles': len(mesh.faces)}
        if non_manifold or volume <= 0 or components != 1:
            raise RuntimeError(f'Invalid printable mesh: {name}: {report[name]}')
        mesh.to_mesh(obj.data)
        mesh.free()
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.wm.stl_export(filepath=str(output / f'{name}.stl'), export_selected_objects=True)
        objects[name] = obj
    (ROOT / 'mesh-validation.json').write_text(json.dumps(report, indent=2) + '\n')

    # Render actual assembly meshes; cap/switch/PCB shapes are illustrative envelopes.
    objects['fit-coupon'].hide_render = True
    objects['fit-coupon'].hide_set(True)
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
    dark = material('graphite', (0.048, 0.057, 0.067))
    red = material('warm red keycap', (0.7, 0.045, 0.035))
    white = material('legend', (1, 0.93, 0.88))
    pcb_blue = material('PCB blue', (0.02, 0.16, 0.5))
    silver = material('USB shell', (0.45, 0.48, 0.5))
    brown = material('switch housing', (0.45, 0.33, 0.13))
    print_collection = bpy.data.collections.new('PRINTABLE | STL parts, millimeters')
    reference_collection = bpy.data.collections.new('REFERENCE ONLY | approximate bought parts')
    studio_collection = bpy.data.collections.new('STUDIO | render camera and lighting')
    for col in (print_collection, reference_collection, studio_collection):
        bpy.context.scene.collection.children.link(col)
    def move_to(obj, collection):
        for previous in list(obj.users_collection):
            previous.objects.unlink(obj)
        collection.objects.link(obj)
    for obj in objects.values():
        move_to(obj, print_collection)
    for name in ('base', 'lid'):
        objects[name].data.materials.clear()
        objects[name].data.materials.append(dark)
        for face in objects[name].data.polygons:
            face.material_index = 0
        bevel = objects[name].modifiers.new('Render-only edge highlights', 'BEVEL')
        bevel.width = 0.15
        bevel.segments = 2
    cap = primitive(rounded(18, 18, 10.5, 1.2, z=P['base_height'] + P['plate'] + 1.5))
    cap.name = '1u custom keycap | approximate envelope, NOT printable'
    cap.data.materials.append(red)
    plate_top = P['base_height'] + P['plate']
    switch_body = primitive(box(13.9, 13.9, 5, z=plate_top - 5))
    switch_top = primitive(rounded(15.6, 15.6, 4.5, 0.8, z=plate_top))
    switch_stem = primitive(box(4, 4, 1.5, z=plate_top + 4.5))
    for obj, name in [(switch_body, 'Switch lower body'),
                      (switch_top, 'Switch upper housing'), (switch_stem, 'Switch stem')]:
        obj.name = name + ' | reference envelope only'
        obj.data.materials.append(brown)
    board_bottom = P['floor'] + P['support_height'] + P['foam_thickness']
    board = primitive(rounded(P['board_width'], P['board_depth'], 1.6, 1,
                              y=P['board_center_y'], z=board_bottom))
    board.name = 'S2 mini | official footprint, provisional height'
    board.data.materials.append(pcb_blue)
    usb = evaluate(difference(
        box(9, 7, 3.2, y=P['board_center_y'] + P['board_depth']/2 - 1, z=board_bottom + 1.6),
        box(7.5, 8, 2, y=P['board_center_y'] + P['board_depth']/2 - 1,
            z=board_bottom + 2.2)))
    usb.name = 'USB-C socket | approximate envelope only'
    usb.data.materials.clear()
    usb.data.materials.append(silver)
    for face in usb.data.polygons:
        face.material_index = 0
    bpy.ops.object.text_add(location=(0, -0.8, P['base_height'] + P['plate'] + 12.05))
    legend = bpy.context.object
    legend.name = 'blocked legend | visual only'
    legend.data.body = 'blocked'
    legend.data.align_x = 'CENTER'
    legend.data.size = 2.7
    legend.data.extrude = 0.01
    legend.data.materials.append(white)
    for obj in (cap, switch_body, switch_top, switch_stem, board, usb, legend):
        move_to(obj, reference_collection)
    ground = primitive(box(2000, 2000, 1, z=-1.7))
    ground.name = 'Studio floor'
    ground.data.materials.append(material('backdrop', (0.55, 0.57, 0.59)))
    move_to(ground, studio_collection)
    bpy.ops.object.camera_add(location=(68, -84, 76))
    cam = bpy.context.object
    cam.rotation_euler = (Vector((0, 0, 12)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    cam.data.type = 'ORTHO'
    cam.data.ortho_scale = 85
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
    scene.cycles.samples = 32
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
    bpy.ops.render.render(write_still=True)
    lid.location.z += 22
    for obj in (cap, switch_body, switch_top, switch_stem, legend):
        obj.location.z += 22
    cam.location = (68, 84, 94)
    cam.rotation_euler = (Vector((0, 0, 26)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    cam.data.ortho_scale = 99
    scene.render.filepath = str(ROOT / 'exploded.png')
    bpy.ops.render.render(write_still=True)
    print('MESH_VALIDATION ' + json.dumps(report))


if __name__ == '__main__':
    geometry_parts = geometry()
    write_scad(geometry_parts)
    if '--export' in sys.argv:
        export_blender(geometry_parts)
