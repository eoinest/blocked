#!/usr/bin/env python3
"""Blender 5: functional FDM prototype keycaps; dimensions and STL coordinates in mm.

blender -b --factory-startup --threads 4 --python keycap/printed/build.py
Original geometry; the compliant split-socket concept is credited in README.md.
"""
import bpy, bmesh
import json, math, struct
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parent
OUT = ROOT / 'stl'
OUT.mkdir(exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = .001

def material(name, color):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*color, 1)
    bsdf.inputs['Roughness'].default_value = .38
    return m

WHITE = material('White PLA', (.84,.85,.83))
GRAY = material('Engraving — optional gray paint', (.25,.27,.28))

def mesh(name, verts, faces):
    m = bpy.data.meshes.new(name)
    m.from_pydata(verts, [], faces)
    m.update()
    o = bpy.data.objects.new(name, m)
    scene.collection.objects.link(o)
    o.data.materials.append(WHITE)
    o.data.materials.append(GRAY)
    bm = bmesh.new(); bm.from_mesh(m)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(m); bm.free()
    return o

def ring(w,d,r,n=12):
    pts=[]
    for cx,cy,start in ((w/2-r,d/2-r,0),(-w/2+r,d/2-r,90),
                        (-w/2+r,-d/2+r,180),(w/2-r,-d/2+r,270)):
        for j in range(n):
            a=math.radians(start+j*90/n)
            pts.append((cx+r*math.cos(a),cy+r*math.sin(a)))
    return pts

def loft(name, sections, slope=0):
    # Each section: width, depth, corner radius, height.
    verts=[]
    for w,d,r,z in sections:
        verts.extend((x,y,z+slope*y) for x,y in ring(w,d,r))
    n=48
    faces=[tuple(reversed(range(n))), tuple(range(len(verts)-n,len(verts)))]
    for k in range(len(sections)-1):
        for i in range(n):
            j=(i+1)%n; a=k*n; b=(k+1)*n
            faces.append((a+i,a+j,b+j,b+i))
    return mesh(name,verts,faces)

def box(name,w,d,z0,z1):
    return loft(name,[(w,d,.001,z0),(w,d,.001,z1)])

def cylinder(name, radius, z0, z1, top=None):
    bpy.ops.mesh.primitive_cone_add(vertices=96,radius1=radius,
        radius2=radius if top is None else top,depth=z1-z0,
        location=(0,0,(z0+z1)/2))
    o=bpy.context.object; o.name=name
    return o

def boolean(body, cutter, operation='DIFFERENCE'):
    if '--debug' in __import__('sys').argv:
        bm=bmesh.new(); bm.from_mesh(cutter.data)
        print('CUTTER',cutter.name,len(bm.faces),bm.calc_volume(signed=True),sum(not e.is_manifold for e in bm.edges),flush=True);bm.free()
    bpy.context.view_layer.objects.active=body
    m=body.modifiers.new(operation,'BOOLEAN'); m.operation=operation
    m.solver='EXACT'; m.object=cutter
    bpy.ops.object.modifier_apply(modifier=m.name)
    if '--debug' in __import__('sys').argv:
        bm=bmesh.new(); bm.from_mesh(body.data)
        print('BOOL',body.name,cutter.name,operation,len(bm.faces),bm.calc_volume(signed=True),sum(not e.is_manifold for e in bm.edges),flush=True)
        bm.free()
    bpy.data.objects.remove(cutter,do_unlink=True)

def legend_curve():
    paths=json.loads((ROOT/'legend-contours.json').read_text())['contours']
    curve=bpy.data.curves.new('blocked paths, widened for FDM','CURVE')
    curve.dimensions='2D'; curve.fill_mode='BOTH'; curve.resolution_u=2
    curve.extrude=.30
    # Precomputed outline expansion, tracking and counter relief for FDM.
    curve.offset=0
    for points in paths:
        sp=curve.splines.new('POLY'); sp.points.add(len(points)-1)
        for p,(x,y) in zip(sp.points,points):
            p.co=(x,y,0,1)
        sp.use_cyclic_u=True
    o=bpy.data.objects.new('blocked cutter',curve); scene.collection.objects.link(o)
    bpy.context.view_layer.objects.active=o; o.select_set(True)
    bpy.ops.object.convert(target='MESH'); o.select_set(False)
    bm=bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(o.data); bm.free()
    return o

LEGEND=legend_curve()
LEGEND.hide_render=True; LEGEND.hide_set(True)

def cut_legend(o,top,slope=0):
    c=LEGEND.copy(); c.data=LEGEND.data.copy(); scene.collection.objects.link(c)
    c.hide_set(False); c.hide_render=False
    # Depth .40 mm below top. Cutter extends .20 beyond top.
    for v in c.data.vertices: v.co.z+=top-.10+slope*v.co.y
    c.data.materials.clear(); c.data.materials.append(WHITE); c.data.materials.append(GRAY)
    for p in c.data.polygons: p.material_index=1
    boolean(o,c)

def cut_id(o,label,under,slope=0,coupon=False):
    c=bpy.data.curves.new(label,'FONT'); c.body=label; c.size=2.4
    c.extrude=.2; c.align_x='CENTER'
    ob=bpy.data.objects.new('underside ID '+label,c); scene.collection.objects.link(ob)
    bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True)
    bpy.context.view_layer.objects.active=ob; bpy.ops.object.convert(target='MESH')
    # Mirror X so ID reads when viewing the underside; inside the crown, away from socket.
    for v in ob.data.vertices:
        v.co.x=-v.co.x-(0 if coupon else 8.5); v.co.y+=2.7 if coupon else 2.5
        v.co.z+=under+.10+slope*v.co.y
    bm=bmesh.new(); bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(ob.data); bm.free()
    boolean(o,ob)

def make_cap(style,fit,coupon=False):
    label=('F' if coupon else style['id'])+str(fit)
    top=6.6 if coupon else style['top']
    w,d,r=(10,10,1.5) if coupon else (28,18,style['radius'])
    slope=0 if coupon else math.tan(math.radians(style['angle']))
    under=top-(1.8 if coupon else 2.4)
    # A broad planar face makes a support-free face-down print possible. The .35 mm
    # chamfer removes a sharp finger edge and keeps the first-layer rim recessed.
    o=loft(label,[(w-.7,d-.7,max(.4,r-.35),under),
                 (w,d,r,under+.35),(w,d,r,top-.35),
                 (w-.7,d-.7,max(.4,r-.35),top)],slope)
    boolean(o,cylinder('socket boss',2.6,0,3.82),'UNION')
    boolean(o,cylinder('socket root flare',2.6,3.8,under+.22,top=3.6),'UNION')
    add=fit*.10
    # Vertical slot opens through both ends of the boss: two compliant halves.
    # The orthogonal, blind horizontal pocket retains the 4.10 mm span.
    boolean(o,box('through Y slot',1.30+add,8,-.05,3.6))
    boolean(o,box('horizontal pocket',4.10,1.10+add,-.05,3.6))
    # Modest lead-in, only on the two long slot edges, preserves tip-wall thickness.
    lead=loft('entry lead',[(1.50+add,8,.001,-.05),
                            (1.30+add,8,.001,.25)])
    boolean(o,lead)
    if coupon:
        cut_id(o,label,under,coupon=True)
    else:
        cut_legend(o,top,slope); cut_id(o,label,under,slope)
    o.name=label
    o['shape']= 'fit coupon' if coupon else style['name']
    o['fit_total_width_addition_mm']=add
    o['socket_depth_mm']=3.6
    return o,top,slope

def validate(o):
    bm=bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.triangulate(bm,faces=list(bm.faces))
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    boundary=sum(not e.is_manifold for e in bm.edges)
    todo=set(bm.verts); components=0
    while todo:
        components+=1; stack=[todo.pop()]
        while stack:
            for e in stack.pop().link_edges:
                for v in e.verts:
                    if v in todo: todo.remove(v); stack.append(v)
    volume=bm.calc_volume(signed=True)
    report=dict(nonmanifold_edges=boundary,components=components,volume_mm3=round(volume,3),triangles=len(bm.faces))
    assert boundary==0 and components==1 and volume>0,(o.name,report)
    bm.to_mesh(o.data); bm.free()
    return report

def export_stl(objects,path):
    triangles=[]
    for o in objects:
        o.data.calc_loop_triangles()
        for t in o.data.loop_triangles:
            vs=[o.matrix_world @ o.data.vertices[i].co for i in t.vertices]
            normal=(vs[1]-vs[0]).cross(vs[2]-vs[0]).normalized()
            triangles.append((*normal,*vs[0],*vs[1],*vs[2],0))
    with path.open('wb') as f:
        f.write(b'blocked prototype keycaps; millimeters'.ljust(80,b'\0'))
        f.write(struct.pack('<I',len(triangles)))
        for t in triangles: f.write(struct.pack('<12fH',*t))

STYLES=[dict(id='A',name='Flat Tab',radius=2,top=7.2,angle=0),
        dict(id='B',name='Soft Tab',radius=5,top=7.2,angle=0),
        dict(id='C',name='Tilt Tab',radius=3,top=7.7,angle=5)]
report={'units':'mm','printer':'Bambu Lab A1','nozzle_mm':.4,
        'material_assumption':'regular PLA','status':'unprinted physical fit prototypes',
        'socket':{'boss_diameter':5.2,'depth':3.6,'horizontal_span':4.10,
                  'horizontal_bar_base':1.10,'vertical_slot_base':1.30,
                  'total_width_additions':[0,.10,.20],
                  'split_axis':'Y','root_flare_start':3.8},
        'styles':STYLES,'parts':{}}
parts=[]; assembled=[]
for row in range(3):
    for col,style in enumerate(STYLES):
        o,top,slope=make_cap(style,row)
        report['parts'][o.name]=validate(o)
        # Keep an installed-orientation copy in its own hidden collection for editing.
        a=o.copy(); a.data=o.data.copy(); a.name=o.name+' — installed orientation'
        scene.collection.objects.link(a); a.hide_render=True; a.hide_set(True); assembled.append(a)
        angle=math.pi-math.atan(slope)
        o.rotation_euler.x=angle
        bpy.context.view_layer.update()
        points=[o.matrix_world@v.co for v in o.data.vertices]
        zmin=min(p.z for p in points)
        o.location=(20+col*35,20+row*26,-zmin)
        bpy.context.view_layer.update()
        report['parts'][o.name]['plate_center_xy']=[20+col*35,20+row*26]
        export_stl([o],OUT/f'{o.name}-{style["name"].lower().replace(" ","-")}.stl')
        parts.append(o)
    o,top,slope=make_cap(STYLES[0],row,True)
    report['parts'][o.name]=validate(o)
    o.rotation_euler.x=math.pi; o.location=(20+row*35,98,top)
    bpy.context.view_layer.update()
    export_stl([o],OUT/f'{o.name}-socket-coupon.stl'); parts.append(o)

bpy.context.view_layer.update()
export_stl(parts,OUT/'blocked-tab-all-options.stl')
export_stl([o for o in parts if o.name.startswith('F')],OUT/'socket-fit-coupons.stl')
points=[o.matrix_world@v.co for o in parts for v in o.data.vertices]
bounds=[[min(p[i] for p in points),max(p[i] for p in points)] for i in range(3)]
report['plate_bounds_mm']=bounds
report['plate_size_mm']=[round(b-a,3) for a,b in bounds]
report['plate_parts']=len(parts)
report['legend']={'text':'blocked','word_width_before_outline':14.1,'outline_expansion':.07,
                  'base_scaled_word_width':12,'added_tracking':.35,'small_counter_expansion':.15,
                  'depth':.4,'position':'lower left','source':'../blocked-tab-upload.svg'}
(ROOT/'validation.json').write_text(json.dumps(report,indent=2)+'\n')

# Save printable/editable Blender source with plate objects selected and references hidden.
bpy.data.objects.remove(LEGEND,do_unlink=True)
bpy.ops.object.select_all(action='DESELECT')
for o in parts: o.select_set(True)
bpy.context.view_layer.objects.active=parts[0]
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blocked-tab-options.blend'))

# Render a separate presentation of the three middle-fit variants, face-up.
for o in parts: o.hide_render=True
for a in assembled: a.hide_render=True
shows=[]
for i in range(3):
    source=next(a for a in assembled if a.name.startswith(STYLES[i]['id']+'1 '))
    o=source.copy(); o.data=source.data.copy(); scene.collection.objects.link(o)
    o.hide_render=False; o.hide_set(False); o.location=(i*36,0,0); shows.append(o)
floor=loft('presentation ground',[(150,65,8,-.8),(150,65,8,-.3)])
floor.location.x=36
floor.data.materials[0]=material('warm background',(.14,.16,.18))
def aim(o,point): o.rotation_euler=(Vector(point)-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(57,-72,100)); cam=bpy.context.object
cam.data.type='ORTHO';cam.data.ortho_scale=122;aim(cam,(36,0,3));scene.camera=cam
for loc,power,size in [((10,-30,75),160000,65),((65,35,45),90000,50)]:
    bpy.ops.object.light_add(type='AREA',location=loc); l=bpy.context.object
    l.data.energy=power;l.data.shape='DISK';l.data.size=size;aim(l,(36,0,0))
scene.render.engine='CYCLES';scene.cycles.samples=48
scene.world.color=(.3,.3,.3)
scene.render.resolution_x=1600;scene.render.resolution_y=800;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
scene.render.image_settings.file_format='PNG'
scene.render.filepath=str(ROOT/'shape-preview.png')
bpy.ops.render.render(write_still=True)
print(json.dumps({'output':str(OUT/'blocked-tab-all-options.stl'),'validation':report}))
