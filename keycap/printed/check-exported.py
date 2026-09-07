#!/usr/bin/env python3
"""Independent exported-keycap STL audit; uses only the Python standard library.

Run from any directory: python3 keycap/printed/check-exported.py
Writes independent-audit.json beside this script. No geometry is modified.
"""
import json, math, struct, hashlib
from pathlib import Path
from collections import defaultdict,Counter
ROOT=Path(__file__).resolve().parent
FILES=sorted((ROOT/'stl').glob('*.stl'))
REFERENCE=json.loads((ROOT/'validation.json').read_text())
def sub(a,b): return tuple(x-y for x,y in zip(a,b))
def cross(a,b): return (a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
def dot(a,b): return sum(x*y for x,y in zip(a,b))
def load(path):
    data=path.read_bytes(); n=struct.unpack_from('<I',data,80)[0]
    assert len(data)==84+50*n,(path,'not exact binary STL length')
    tris=[struct.unpack_from('<12fH',data,84+50*i)[3:12] for i in range(n)]
    return [[tuple(t[j:j+3]) for j in (0,3,6)] for t in tris],hashlib.sha256(data).hexdigest()
def audit(tris):
    ids={}; verts=[]; faces=[]
    for tri in tris:
        f=[]
        for vertex in tri:
            if vertex not in ids: ids[vertex]=len(verts); verts.append(vertex)
            f.append(ids[vertex])
        faces.append(f)
    edges=defaultdict(list); link_edges=defaultdict(list); signed_volume=0.; zero_area=0; contact_area=0.
    for i,face in enumerate(faces):
        a,b,c=[verts[v] for v in face]; area=math.sqrt(dot(cross(sub(b,a),sub(c,a)),cross(sub(b,a),sub(c,a))))/2
        zero_area+=area<1e-12
        signed_volume+=dot(a,cross(b,c))/6
        if max(abs(v[2]) for v in (a,b,c))<1e-4: contact_area+=area
        for u,v in zip(face,face[1:]+face[:1]): edges[tuple(sorted((u,v)))].append((i,1 if u<v else -1))
        for j,v in enumerate(face): link_edges[v].append((face[(j+1)%3],face[(j+2)%3]))
    neighbors=[set() for _ in faces]
    for links in edges.values():
        for a,_ in links:
            neighbors[a].update(b for b,_ in links if b!=a)
    todo=set(range(len(faces))); components=[]
    while todo:
        first=todo.pop(); pending=[first]; found=[first]
        while pending:
            for nxt in neighbors[pending.pop()]:
                if nxt in todo: todo.remove(nxt);pending.append(nxt);found.append(nxt)
        components.append(found)
    bad_vertex_links=0
    for vertex,links in link_edges.items():
        adjacency=defaultdict(set); degrees=Counter()
        for u,v in links: adjacency[u].add(v);adjacency[v].add(u);degrees[u]+=1;degrees[v]+=1
        todo=set(adjacency); visited={todo.pop()}; queue=list(visited)
        while queue:
            for nxt in adjacency[queue.pop()]:
                if nxt not in visited: visited.add(nxt);queue.append(nxt)
        if any(x!=2 for x in degrees.values()) or len(visited)!=len(adjacency): bad_vertex_links+=1
    bounds=[[min(v[k] for v in verts),max(v[k] for v in verts)] for k in range(3)]
    result={'triangles':len(tris),'unique_vertices':len(verts),'edge_incidence_not_two':sum(len(v)!=2 for v in edges.values()),'inconsistently_oriented_edges':sum(len(v)==2 and v[0][1]==v[1][1] for v in edges.values()),'nonmanifold_vertex_links':bad_vertex_links,'degenerate_triangles':zero_area,'face_connected_components':len(components),'signed_volume_mm3':round(signed_volume,6),'minimum_z_mm':bounds[2][0],'maximum_z_mm':bounds[2][1],'bed_contact_triangle_area_mm2':round(contact_area,6),'bounds_mm':bounds}
    return result,[[tris[i] for i in comp] for comp in components]
def fingerprint(tris): return hashlib.sha256(repr(sorted(tuple(sorted(tri)) for tri in tris)).encode()).hexdigest()
results={}; meshes={}; component_sets={}; failures=[]
for path in FILES:
    tris,digest=load(path); result,components=audit(tris)
    result['sha256']=digest; results[path.name]=result; meshes[path.name]=tris; component_sets[path.name]=components
    expected=12 if path.name=='blocked-tab-all-options.stl' else 3 if path.name=='socket-fit-coupons.stl' else 1
    if any(result[k] for k in ('edge_incidence_not_two','inconsistently_oriented_edges','nonmanifold_vertex_links','degenerate_triangles')) or result['face_connected_components']!=expected or result['signed_volume_mm3']<=0 or abs(result['minimum_z_mm'])>1e-4 or result['bed_contact_triangle_area_mm2']<=0: failures.append(path.name)
individual=[name for name in results if name[0] in 'ABCF' and name[1].isdigit()]
if len(individual)!=12: failures.append('Expected twelve individual cap/coupon files')
bounds={name:results[name]['bounds_mm'] for name in individual}
min_gap=1e9; closest=None
for i,a in enumerate(individual):
    for b in individual[i+1:]:
        gaps=[max(0,bounds[a][k][0]-bounds[b][k][1],bounds[b][k][0]-bounds[a][k][1]) for k in (0,1)]
        lower_bound=math.hypot(*gaps)
        if lower_bound<min_gap: min_gap=lower_bound;closest=[a,b]
        if lower_bound<=0: failures.append('Overlapping XY bounds:'+a+','+b)
combined_exact=Counter(fingerprint(t) for t in component_sets['blocked-tab-all-options.stl'])==Counter(fingerprint(meshes[n]) for n in individual)
fit_exact=Counter(fingerprint(t) for t in component_sets['socket-fit-coupons.stl'])==Counter(fingerprint(meshes[n]) for n in individual if n.startswith('F'))
if not combined_exact or not fit_exact: failures.append('Combined component mismatch')
clearances={}
for name in individual:
    if name.startswith('F'): continue
    key=name[:2]; style=next(s for s in REFERENCE['styles'] if s['id']==key[0]); center=REFERENCE['parts'][key]['plate_center_xy']; alpha=math.radians(style['angle']); theta=math.pi-alpha; c=math.cos(theta);s=math.sin(theta); top=style['top']; zoff=top*math.cos(alpha)
    local=[]
    for tri in meshes[name]:
        localtri=[]
        for x,y,z in tri:
            y-=center[1]; z-=zoff
            localtri.append((x-center[0],c*y+s*z,-s*y+c*z))
        local.append(localtri)
    vertices=[v for tri in local for v in tri]
    crown=[v for v in vertices if math.hypot(v[0],v[1])>3.601]
    flare=[v for v in vertices if abs(v[2]-3.8)<1e-4 and abs(math.hypot(v[0],v[1])-2.6)<1e-4]
    ceiling_faces=[tri for tri in local if all(abs(v[2]-3.6)<1e-4 for v in tri)]
    mouth_z=min(v[2] for v in vertices)
    crown_z=min(v[2] for v in crown)
    crown_clear=crown_z+1.4-5
    flare_clear=min(v[2] for v in flare)+1.4-5 if flare else None
    result={'recovered_socket_mouth_z_mm':round(mouth_z,6),'socket_ceiling_faces_at_3_6mm':len(ceiling_faces),'recovered_crown_minimum_local_z_mm':round(crown_z,6),'nominal_full_travel_crown_to_housing_top_gap_mm':round(crown_clear,6),'nominal_full_travel_flare_to_housing_top_gap_mm':round(flare_clear,6) if flare_clear is not None else None}
    clearances[key]=result
    if abs(mouth_z)>1e-4 or not ceiling_faces or crown_clear<=0 or flare_clear is None or flare_clear<=0: failures.append('Clearance/reference feature:'+key)
report={'status':'PASS' if not failures else 'FAIL','scope':'Independent audit of exported binary STL geometry only; no actual switch, filament, printer, fit, retention or full-stroke physical test performed.','methods':['Parsed binary STL files directly with Python standard library; exact float32 coordinate welding, no mesh repair or geometry modification.','Checked every edge has exactly two opposing face incidences, every vertex link forms one cycle, zero degenerate triangles, positive signed volume and expected face-connected component counts.','Checked floor minimum within 0.0001 mm and positive contact triangle area; all 66 individual-part XY bounding-box pairs are disjoint.','Matched combined-plate connected components exactly to individual exported triangles.','Inverted exported print transforms to recover source mouth/ceiling, crown and flare coordinates; evaluated nominal fully depressed height against housing top plane.'], 'file_results':results,'plate':{'parts':12,'xy_bounds_pairs_checked':66,'minimum_xy_aabb_separation_mm':round(min_gap,6),'closest_pair':closest,'combined_plate_matches_individual_stls_exactly':combined_exact,'combined_fit_coupons_match_individual_stls_exactly':fit_exact},'nominal_mechanical_assumptions':{'plate_top_reference_z_mm':0,'modeled_housing_top_z_mm':5,'modeled_male_stem_top_at_rest_z_mm':8.4,'socket_ceiling_depth_mm':3.6,'derived_socket_mouth_at_rest_z_mm':4.8,'travel_mm':3.4,'derived_socket_mouth_at_full_travel_z_mm':1.4},'recovered_export_clearances':clearances,'uncertainties':['The male stem height and housing internal opening are approximate references; the split boss nesting into the switch is not validated.','Printed socket fit, elastic recovery, extraction force and retention are unknown. Nominal near-pocket tip wall thickness is roughly 0.47–0.49 mm, near a single 0.4 mm extrusion width; use fit coupons without forcing.','Crown/flare clearance uses a fixed housing-top envelope and assumed stem seating. Different physical seating changes all calculated gaps.','Mesh topology and disjoint plate bounds do not prove extrusion quality, overhang behavior, glyph readability, fatigue strength or collision-free internal switch travel.','No full self-intersection search was run; manifold topology and coherent positive volumes were checked.'],'failures':failures}
(ROOT/'independent-audit.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'status':report['status'],'failures':failures,'files':len(results),'plate':report['plate'],
                  'minimum_nominal_crown_gap_mm':min(v['nominal_full_travel_crown_to_housing_top_gap_mm'] for v in clearances.values()),
                  'minimum_nominal_flare_gap_mm':min(v['nominal_full_travel_flare_to_housing_top_gap_mm'] for v in clearances.values() if v['nominal_full_travel_flare_to_housing_top_gap_mm'] is not None)},indent=2))
raise SystemExit(0 if report['status']=='PASS' else 1)
