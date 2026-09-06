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
    assert br - P['insert_outer_diameter']/2 >= 1.3
    assert P['board_post_radius'] - P['board_insert_outer_diameter']/2 >= 1.3
    band, inset = P['bottom_band_height'], P['bottom_inset']
    shell = difference(
        union(rounded(w - 2*inset, d - 2*inset, band + EPS, r-inset),
              rounded(w, d, h-band, r, z=band)),
        rounded(w - 2 * wall, d - 2 * wall, h, r - wall, z=floor),
    )
    additions = []
    # Only the two documented 2 mm mounting holes retain the board.
    # No supports or fingers cover electrical header pads.
    for x in (-P['board_mount_x'], P['board_mount_x']):
        additions.append(cylinder(P['board_post_radius'], P['board_bottom']-floor+EPS,
                                  x=x,y=P['board_mount_y'],z=floor-EPS))
    cuts = [box(P["usb_width"], 2 * wall + 2, P["usb_height"],
                y=d / 2 - wall / 2, z=P["usb_bottom"])]
    for x in (-P['board_mount_x'],P['board_mount_x']):
        cuts.append(cylinder(P['board_insert_seat_diameter']/2,
                             P['board_insert_seat_depth']+EPS,x=x,y=P['board_mount_y'],
                             z=P['board_bottom']-P['board_insert_seat_depth']))
    for x in (-sx, sx):
        cuts += [cylinder(P["screw_clearance"] / 2, floor + 2*EPS, x=x, z=-EPS),
                 cylinder(P['head_diameter']/2, 1.05,
                          top=P['screw_clearance']/2, x=x, z=-EPS)]
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
    )
    post_length = h - floor - P['boss_floor_gap']
    posts = [cylinder(br, post_length + EPS, x=x, z=-post_length) for x in (-sx, sx)]
    lid_cuts = [box(P["switch_opening"], P["switch_opening"], plate + 2 * EPS, z=-EPS)]
    for x in (-sx, sx):
        lid_cuts += [cylinder(P['insert_seat_diameter']/2, P['insert_seat_depth']+EPS,
                             x=x, z=-post_length-EPS),
                     cylinder(P['screw_relief_diameter']/2, P['screw_relief_depth']+EPS,
                              x=x, z=-post_length-EPS)]
    chamfer = P['lid_chamfer']
    lid_skin = union(rounded(w, d, plate-chamfer+EPS, r),
                     rounded(w, d, chamfer, r, z=plate-chamfer,
                             top_scale=(w-2*chamfer)/w))
    lid = difference(union(lid_skin, skirt, *posts), *lid_cuts)
    # Apertures increase left-to-right; small edge notches mark 1, 2, 3.
    coupon_cuts = []
    for index, (x, opening) in enumerate(((-21.5, 14.0), (0, 14.1), (21.5, 14.2))):
        coupon_cuts.append(box(opening, opening, plate + 2 * EPS, x=x, z=-EPS))
        for tick in range(index + 1):
            coupon_cuts.append(box(0.8, 1.5, plate + 2 * EPS,
                                   x=x + 1.5 * tick - 0.75 * index,
                                   y=-13, z=-EPS))
    coupon = difference(rounded(66, 26, plate, 2), *coupon_cuts)
    insert_coupon_cuts = []
    for index, (x, bore) in enumerate(((-18,3.2), (-6,3.3), (6,3.4), (18,3.5))):
        insert_coupon_cuts += [cylinder(bore/2, 3.25, x=x, z=4.8),
                               cylinder(P['screw_relief_diameter']/2, 6.55, x=x, z=1.5)]
        for tick in range(index+1):
            insert_coupon_cuts.append(box(.8, 1.5, 8.1,
                                          x=x + 1.5*tick - .75*index, y=-5, z=-EPS))
    insert_coupon = difference(union(rounded(48,10,1.5,1.5),
                                      *[cylinder(P['boss_radius'],8,x=x) for x in (-18,-6,6,18)]),
                               *insert_coupon_cuts)
    board_coupon_cuts=[]
    for index,(x,bore) in enumerate(((-12,2.2),(0,2.3),(12,2.4))):
        board_coupon_cuts.append(cylinder(bore/2,3.55,x=x,z=1.5))
        for tick in range(index+1):
            board_coupon_cuts.append(box(.8,1.5,5.1,x=x+1.5*tick-.75*index,y=-4,z=-EPS))
    board_coupon=difference(union(rounded(36,8,1.5,1.5),
                                   *[cylinder(P['board_post_radius'],5,x=x) for x in (-12,0,12)]),
                             *board_coupon_cuts)
    return {"base": base, "lid": lid, "fit-coupon": coupon,
            "insert-coupon": insert_coupon,"board-insert-coupon":board_coupon}


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
    return prefix + (f"linear_extrude(height={h:g}, scale={node['top_scale']:g}) offset(r={r:g}, $fn=64) "
                     f"square([{w-2*r:g}, {d-2*r:g}], center=true);\n")


def write_scad(parts):
    result = '// Generated by build.py from parameters.json. Units: mm.\n'
    result += '// Change parameters.json and rerun build.py to edit dimensions.\n'
    result += 'part = "assembly"; // [assembly,base,lid,fit-coupon,insert-coupon,board-insert-coupon,print-layout]\n'
    for name, body in parts.items():
        result += f"module {name.replace('-', '_')}() {{\n{scad(body, 1)}}}\n"
    result += f'''\nif (part == "base") base();
else if (part == "lid") translate([0,0,{P['plate']}]) rotate([180,0,0]) lid();
else if (part == "fit-coupon") fit_coupon();
else if (part == "insert-coupon") insert_coupon();
else if (part == "board-insert-coupon") board_insert_coupon();
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
    for name in ('fit-coupon', 'insert-coupon','board-insert-coupon'):
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
    brass = material('M2 heat-set inserts | brass', (0.56, 0.31, 0.065))
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
    # This is intentionally not an STL and has no manufactured MX stem socket.
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
    for x in (-12,12):
        for y in (-13,13):
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
    inserts, screws = [], []
    for x in (-P['screw_x'], P['screw_x']):
        insert = evaluate(difference(
            cylinder(P['insert_outer_diameter']/2, P['insert_length'],
                     x=x, z=P['floor']+P['boss_floor_gap']),
            cylinder(1, P['insert_length']+2*EPS,
                     x=x, z=P['floor']+P['boss_floor_gap']-EPS)))
        insert.name = f'M2 x 3 heat-set insert at x={x:g} | brass reference, no knurl/thread detail'
        insert.data.materials.clear()
        insert.data.materials.append(brass)
        for face in insert.data.polygons:
            face.material_index = 0
        inserts.append(insert)
        screw = evaluate(difference(
            union(cylinder(1.9,.3+EPS,x=x),cylinder(1.9,.9,x=x,z=.3,top=1),
                  cylinder(1,6.8+EPS,x=x,z=1.2-EPS)),
            box(2,.5,.4,x=x,z=-EPS), box(.5,2,.4,x=x,z=-EPS)))
        screw.name = f'M2 x 8 countersunk Phillips screw at x={x:g} | reference, unthreaded envelope'
        screw.data.materials.clear()
        screw.data.materials.append(silver)
        for face in screw.data.polygons:
            face.material_index = 0
        screws.append(screw)
    board_mount_refs=[]
    for x in (-P['board_mount_x'],P['board_mount_x']):
        insert=evaluate(difference(
            cylinder(P['board_insert_outer_diameter']/2,P['board_insert_length'],
                     x=x,y=P['board_mount_y'],z=board_bottom-P['board_insert_length']),
            cylinder(.8,P['board_insert_length']+2*EPS,
                     x=x,y=P['board_mount_y'],z=board_bottom-P['board_insert_length']-EPS)))
        insert.name=f'PCB_INSERT_M1_6_x_2_5_{x:+g}'
        insert.data.materials.clear(); insert.data.materials.append(brass)
        for face in insert.data.polygons: face.material_index=0
        board_mount_refs.append(insert)
        screw=evaluate(difference(
            union(cylinder(.8,4+EPS,x=x,y=P['board_mount_y'],z=board_top-4),
                  cylinder(2.93/2,1,x=x,y=P['board_mount_y'],z=board_top)),
            cylinder(.6,.45,x=x,y=P['board_mount_y'],z=board_top+.6)))
        screw.name=f'PCB_SCREW_M1_6_x_4_TX5_{x:+g} | nominal, drive recess simplified'
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
    for obj in (cap,switch_body,switch_top,switch_stem,board,usb,legend,*inserts,*screws,
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
    if '--mounting-only' not in sys.argv:
        bpy.ops.render.render(write_still=True)
    cam.location = (64, 95, 65)
    cam.rotation_euler = (Vector((0, 0, 12)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    scene.render.filepath = str(ROOT / 'rear.png')
    if '--mounting-only' not in sys.argv:
        bpy.ops.render.render(write_still=True)
    lid.location.z += 22
    for obj in (cap, switch_body, switch_top, switch_stem, legend, *inserts,*switch_extras):
        obj.location.z += 22
    for obj in (*wires,cable,cable_body): obj.hide_render=True
    for obj in screws:
        obj.location.z -= 12
    ground.location.z = -14
    cam.location = (68, 84, 94)
    cam.rotation_euler = (Vector((0, 0, 26)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    cam.data.ortho_scale = 110
    scene.render.filepath = str(ROOT / 'exploded.png')
    if '--mounting-only' not in sys.argv:
        bpy.ops.render.render(write_still=True)
    # Dedicated mounting diagram using actual mounting-hole coordinates.
    # The board and its screws are lifted for visibility; the two base posts stay put.
    lid.hide_render = True
    objects['base'].hide_render = True
    for obj in (cap, switch_body, switch_top, switch_stem, legend,*switch_extras):
        obj.hide_render = True
    for obj in inserts:
        obj.location.z -= 22
    for obj in screws:
        obj.location.z = -5
        obj.location.y = -28
    cutaway_base = evaluate(difference(parts['base'],
                           box(60,4,30,y=-20,z=P['floor']),
                           box(4,22,30,x=-22,y=-10,z=P['floor']),
                           box(4,22,30,x=22,y=-10,z=P['floor'])))
    cutaway_base.name = 'Mounting view cutaway base | presentation only'
    post_length = P['base_height'] - P['floor'] - P['boss_floor_gap']
    # Section the front half of each post as well, exposing the brass inserts.
    cutaway_lid = evaluate(difference(
        parts['lid'], box(60,60,40,z=10-P['base_height']),
        *[box(7,3.4,9,x=x,y=-1.7,z=-post_length-EPS)
          for x in (-P['screw_x'],P['screw_x'])]))
    cutaway_lid.location.z = P['base_height']
    cutaway_lid.name = 'Mounting view M2 insert posts | presentation only'
    for obj in (cutaway_base, cutaway_lid):
        obj.data.materials.clear()
        obj.data.materials.append(case_silver)
        for face in obj.data.polygons:
            face.material_index = 0
        move_to(obj, studio_collection)
    for obj in (board,usb,*[o for o in board_extras if not o.name.startswith('8 x 8')]):
        obj.location.z +=4
    for obj in board_mount_refs:
        if obj.name.startswith('PCB_SCREW'): obj.location.z +=8
    for x in (-P['board_mount_x'],P['board_mount_x']):
        obj=primitive(cylinder(.06,8,x=x,y=P['board_mount_y'],z=board_bottom))
        obj.name='Mounting-hole alignment guide | diagram only'
        obj.data.materials.append(copper); move_to(obj,studio_collection)
    cam.location = (72,-92,110)
    target = Vector((0,0,2))
    cam.rotation_euler = (target - cam.location).to_track_quat('-Z', 'Y').to_euler()
    cam.data.ortho_scale = 105
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
    diagram_text('INTERNAL MOUNTING', -47, 45, 3.1)
    diagram_text('Cutaway view - PCB and screws lifted; wire routes omitted', -47, 40, 1.7)
    diagram_text('Nominal reference geometry; see component-models.json for source limits', -47, 36, 1.5)
    diagram_text('PCB: 2 x M1.6 x 4 TX5 screws through existing 2 mm holes', -47, -33, 1.8)
    diagram_text('PCB posts: 2 x M1.6 x 2.5 inserts | hole centers 20.4 mm apart', -47, -38, 1.7)
    diagram_text('Case: 2 x M2 x 8 PH1 screws + 2 x M2 x 3 inserts', -47, -43, 1.8)
    diagram_text('32 electrical holes remain accessible; no edge clips or PCB drilling', -47, -48, 1.6)
    scene.render.filepath = str(ROOT / 'mounting.png')
    bpy.ops.render.render(write_still=True)
    print('MESH_VALIDATION ' + json.dumps(report))


if __name__ == '__main__':
    geometry_parts = geometry()
    write_scad(geometry_parts)
    if '--export' in sys.argv:
        export_blender(geometry_parts)
