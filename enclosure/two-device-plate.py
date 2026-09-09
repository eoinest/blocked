#!/usr/bin/env python3
"""Two or three current enclosures with matching blank A2 Flat Tab caps, one STL.

Run in Blender: blender -b --factory-startup --threads 4 --python enclosure/two-device-plate.py
Append -- --sets 3 for three complete sets (default: two).
Existing geometry generators and .blend files are read-only. Only this plate/report are written.
"""
import argparse
import ast
import sys
import hashlib
import json
import math
import struct
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parent
CAP_SOURCE = REPO / 'keycap/printed/build.py'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--sets', type=int, choices=(2, 3), default=2)
arguments = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
SETS = arguments.sets
COUNT_WORD = {2: 'two', 3: 'three'}[SETS]
OUTPUT = ROOT / f'stl/blocked-{COUNT_WORD}-devices-blank-caps.stl'
REPORT = ROOT / f'{COUNT_WORD}-device-plate-validation.json'
FOOTPRINT = (98, 48*SETS+18)
BED = 256.0

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

preserved = {str(p.relative_to(REPO)): digest(p) for p in
             (ROOT/'blocked.blend', ROOT/'usb-review.blend', CAP_SOURCE,
              ROOT/'stl/base.stl', ROOT/'stl/lid.stl')}
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = .001

# Reuse the maintained cap geometry functions without executing the generator's
# top-level engraving construction, file exports, scene save, or renders.
# Deliberately omit BOTH text cutters, including the normally hidden underside ID.
tree = ast.parse(CAP_SOURCE.read_text())
excluded = {'legend_curve', 'cut_legend', 'cut_id'}
nodes = [n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name not in excluded]
nodes += [n for n in tree.body if isinstance(n, ast.Assign)
          and any(isinstance(t, ast.Name) and t.id == 'STYLES' for t in n.targets)]
ns = dict(bpy=bpy, bmesh=bmesh, json=json, math=math, struct=struct,
          Path=Path, Vector=Vector, scene=scene, ROOT=CAP_SOURCE.parent)
skipped = {'face_legend': 0, 'underside_id': 0}
def omit_legend(*args, **kwargs): skipped['face_legend'] += 1
def omit_id(*args, **kwargs): skipped['underside_id'] += 1
ns.update(cut_legend=omit_legend, cut_id=omit_id)
exec(compile(ast.Module(body=nodes, type_ignores=[]), str(CAP_SOURCE), 'exec'), ns)
ns['WHITE'] = ns['material']('Blank cap PLA', (.84,.85,.83))
ns['GRAY'] = ns['WHITE']
style = next(s for s in ns['STYLES'] if s['id'] == 'A')
blank, top, slope = ns['make_cap'](style, 2)
blank.name = 'blank_flat_tab_A2_master'
assert skipped == {'face_legend': 1, 'underside_id': 1}
assert not any(o.type in ('FONT', 'CURVE') for o in bpy.data.objects)
blank.rotation_euler.x = math.pi - math.atan(slope)
bpy.context.view_layer.update()
# Bake the existing face-down print transform, then put its complete bounds at0.
world = [blank.matrix_world @ v.co for v in blank.data.vertices]
minimum = Vector(tuple(min(v[i] for v in world) for i in range(3)))
for vertex, point in zip(blank.data.vertices, world): vertex.co = point - minimum
blank.rotation_euler = (0,0,0)
blank.location = (0,0,0)
blank.data.update()
blank_stats = ns['validate'](blank)

# Check the retained blind cross recess directly in the generated solid.
# Local XY origin is the bounding-box minimum; socket center is(14,9).
# Printed mouth is z7.2, recess ceiling z3.6.
probes = []
for dx,dy in ((0,0),(1.8,0),(-1.8,0),(0,2.2),(0,-2.2)):
    hit,point,normal,index = blank.ray_cast(Vector((14+dx,9+dy,top+.5)),Vector((0,0,-1)))
    assert hit and abs(point.z-(top-3.6)) < .002, (dx,dy,point[:])
    probes.append({'offset_xy_mm':[dx,dy], 'ceiling_z_mm':round(point.z,4)})
for dx,dy in ((1.1,2),(-1.1,-2)):
    hit,point,normal,index = blank.ray_cast(Vector((14+dx,9+dy,top+.5)),Vector((0,0,-1)))
    assert hit and abs(point.z-top) < .002, ('boss rim',point[:])

# One base/lid row per set, with matching blank caps beneath.
layout = []
for i in range(SETS):
    layout.extend([(f'base_{i+1}', 'base', 0, 48*i),
                   (f'lid_{i+1}', 'lid', 52, 48*i)])
cap_xs = (9, 61) if SETS == 2 else (1, 35, 69)
layout.extend((f'blank_cap_{i+1}', 'blank', x, 48*SETS) for i,x in enumerate(cap_xs))
offset = ((BED-FOOTPRINT[0])/2, (BED-FOOTPRINT[1])/2)
parts=[]
records=[]
for name,source,x,y in layout:
    if source == 'blank':
        obj=blank.copy(); obj.data=blank.data.copy(); scene.collection.objects.link(obj)
    else:
        bpy.ops.wm.stl_import(filepath=str(ROOT/'stl'/f'{source}.stl'))
        obj=bpy.context.object
    obj.name=name
    low=[min(v.co[i] for v in obj.data.vertices) for i in range(3)]
    for v in obj.data.vertices:
        v.co.x += x+offset[0]-low[0]
        v.co.y += y+offset[1]-low[1]
        v.co.z -= low[2]
    obj.data.update()
    # Centering float32 meshes can collapse tiny CSG corner facets. Weld only
    # sub-micron duplicate vertices before triangulation, retaining all fit dimensions.
    clean=bmesh.new();clean.from_mesh(obj.data)
    bmesh.ops.remove_doubles(clean,verts=list(clean.verts),dist=.00001)
    bmesh.ops.dissolve_degenerate(clean,edges=list(clean.edges),dist=.00001)
    bmesh.ops.recalc_face_normals(clean,faces=list(clean.faces))
    clean.to_mesh(obj.data);clean.free()
    stats=ns['validate'](obj)
    bounds=[[min(v.co[i] for v in obj.data.vertices), max(v.co[i] for v in obj.data.vertices)] for i in range(3)]
    assert abs(bounds[2][0])<.00001
    assert all(0<=bounds[i][0] and bounds[i][1]<=BED for i in (0,1))
    records.append(dict(name=name,source=source,bounds_mm=bounds,**stats))
    parts.append(obj)
bpy.data.objects.remove(blank,do_unlink=True)

def box_gap(a,b):
    dx=max(a[0][0]-b[0][1],b[0][0]-a[0][1],0)
    dy=max(a[1][0]-b[1][1],b[1][0]-a[1][1],0)
    return math.hypot(dx,dy)
gaps=[box_gap(a['bounds_mm'],b['bounds_mm']) for i,a in enumerate(records) for b in records[i+1:]]
assert min(gaps)>=5.999
bpy.context.view_layer.update()
# Omit only triangles collapsed to exactly zero area by STL float32 coordinate
# quantization at the centered bed location. No finite-area face is simplified.
triangles=[]; zero_area_triangles=0
for obj in parts:
    obj.data.calc_loop_triangles()
    for face in obj.data.loop_triangles:
        points=[obj.matrix_world @ obj.data.vertices[i].co for i in face.vertices]
        normal=(points[1]-points[0]).cross(points[2]-points[0])
        if normal.length_squared == 0:
            zero_area_triangles+=1
            continue
        normal.normalize()
        triangles.append((*normal,*points[0],*points[1],*points[2],0))
with OUTPUT.open('wb') as handle:
    handle.write(f'{SETS} enclosures and {SETS} blank Tab caps; millimeters'.encode('ascii').ljust(80,b'\0'))
    handle.write(struct.pack('<I',len(triangles)))
    for triangle in triangles:handle.write(struct.pack('<12fH',*triangle))

# Reimport the actual output and check connected components independently of
# source objects. Each shell must remain manifold, positively oriented and onbed.
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.wm.stl_import(filepath=str(OUTPUT))
exported=bpy.context.object
bm=bmesh.new(); bm.from_mesh(exported.data)
assert all(e.is_manifold for e in bm.edges)
remaining=set(bm.verts); exported_parts=[]
while remaining:
    verts={remaining.pop()}; todo=list(verts)
    while todo:
        for e in todo.pop().link_edges:
            for v in e.verts:
                if v in remaining: remaining.remove(v); verts.add(v); todo.append(v)
    faces=set(f for v in verts for f in v.link_faces)
    origin=next(iter(verts)).co.copy()
    volume=math.fsum((f.verts[0].co-origin).dot((f.verts[1].co-origin).cross(f.verts[2].co-origin))/6 for f in faces)
    bounds=[[min(v.co[i] for v in verts),max(v.co[i] for v in verts)] for i in range(3)]
    assert volume>0 and abs(bounds[2][0])<.0001
    match=[r for r in records if all(abs(bounds[i][j]-r['bounds_mm'][i][j])<.001 for i in range(3) for j in (0,1))]
    assert len(match)==1
    assert abs(volume-match[0]['volume_mm3'])<.02, (match[0]['name'],volume,match[0]['volume_mm3'])
    exported_parts.append(dict(name=match[0]['name'],volume_mm3=round(volume,4),bounds_mm=bounds))
bm.free()
assert len(exported_parts)==3*SETS
exported_socket_probes=[]
for cap in (r for r in records if r['source']=='blank'):
    cx=cap['bounds_mm'][0][0]+14;cy=cap['bounds_mm'][1][0]+9
    for dx,dy in ((0,0),(1.8,0),(-1.8,0),(0,2.2),(0,-2.2)):
        hit,point,normal,index=exported.ray_cast(Vector((cx+dx,cy+dy,top+.5)),Vector((0,0,-1)))
        assert hit and abs(point.z-(top-3.6))<.002
        exported_socket_probes.append({'part':cap['name'],'offset_xy_mm':[dx,dy],'ceiling_z_mm':round(point.z,4)})
assert preserved == {path:digest(REPO/path) for path in preserved}
report={
    'output':str(OUTPUT.relative_to(REPO)), 'units':'mm', 'bed_mm':[256,256],
    'footprint_mm':list(FOOTPRINT), 'centered_on_bed':True,
    'part_count':3*SETS, 'contents':{'bases':SETS,'lids':SETS,'blank_keycaps':SETS},
    'minimum_xy_bounding_box_separation_mm':round(min(gaps),4),
    'all_parts_manifold':True,'all_parts_single_body':True,'all_parts_on_z_zero':True,
    'export_reimport_component_count':len(exported_parts),
    'zero_area_triangles_omitted_after_float32_translation':zero_area_triangles,
    'post_translation_vertex_weld_tolerance_mm':.00001,
    'keycap':{'style':'A Flat Tab','fit':2,'reason':'README recommends roomiest fit2 first',
              'face_legend':None,'underside_id':None,'all_text_cutters_omitted':True,
              'dimensions_mm':[28,18,7.2],'print_orientation':'face-down, socket upward',
              'socket_boss_diameter_mm':5.2,'socket_depth_mm':3.6,
              'horizontal_pocket_mm':[4.10,1.30],'through_Y_slot_width_mm':1.50,
              'open_socket_probe_results':probes,'blank_master_mesh':blank_stats},
    'exported_socket_probe_results':exported_socket_probes,
    'parts':records,'reimported_parts':sorted(exported_parts,key=lambda x:x['name']),
    'read_only_source_sha256':preserved,'output_sha256':digest(OUTPUT),
    'limitations':['Physical switch socket fit remains unverified; use existingF2 tester first if needed.',
                   'Thin split socket walls need slicer inspection; manifold checks do not establish print strength.',
                   'Latest socket-hugging case retains its documented conditional cable seating requirement.',
                   'No slicing or physical printing was performed by this plate builder.']}
REPORT.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'output':str(OUTPUT),'report':str(REPORT),'parts':3*SETS,'footprint_mm':list(FOOTPRINT),'minimum_gap_mm':min(gaps)}))
