"""Regenerate widened contours: uv run --with shapely==2.1.2 python keycap/printed/prepare-legend.py

Only needed when changing the artwork. build.py consumes the checked-in JSON.
"""
from pathlib import Path
import json, re
from shapely.geometry import Polygon, GeometryCollection, MultiPolygon
from shapely.affinity import translate
from shapely import make_valid

root=Path(__file__).resolve().parent
data=re.search(r'<path[^>]* d="([^"]+)"',(root.parent/'blocked-tab-upload.svg').read_text()).group(1)
tokens=re.findall(r'[MLQZ]|-?\d+(?:\.\d+)?',data)
paths=[];current=[];i=0;pos=(0,0)
while i<len(tokens):
    cmd=tokens[i];i+=1
    if cmd in ('M','L'):
        pos=tuple(float(v) for v in tokens[i:i+2]);i+=2
        if cmd=='M':current=[]
        current.append(pos)
    elif cmd=='Q':
        c=tuple(float(v) for v in tokens[i:i+2]);end=tuple(float(v) for v in tokens[i+2:i+4]);i+=4
        start=pos
        for j in range(1,9):
            t=j/8
            current.append(tuple((1-t)**2*start[k]+2*t*(1-t)*c[k]+t*t*end[k] for k in (0,1)))
        pos=end
    elif cmd=='Z':paths.append(current)
    else:raise ValueError(cmd)
shape=GeometryCollection()
for path in paths:
    poly=Polygon([((x-200)*12/900-11,(1600-y)*12/900-6) for x,y in path])
    shape=shape.symmetric_difference(make_valid(poly))
shape=shape.buffer(.07,quad_segs=4).simplify(.001,preserve_topology=True)
assert shape.is_valid and len(shape.geoms)==7
glyphs=[]
for index,poly in enumerate(sorted(shape.geoms,key=lambda p:p.bounds[0])):
    # Keep positive plastic between engraved letters wide enough for a .4 nozzle.
    # Enlarge the tiny e counter so it survives Arachne's first-layer toolpaths.
    for hole in list(poly.interiors):
        counter=Polygon(hole)
        if counter.area<.4:
            poly=poly.difference(counter.buffer(.15,quad_segs=4))
    glyphs.append(translate(poly,xoff=index*.35))
shape=MultiPolygon(glyphs)
assert shape.is_valid and len(shape.geoms)==7
contours=[]
for poly in shape.geoms:
    contours.append(list(poly.exterior.coords)[:-1])
    contours.extend(list(r.coords)[:-1] for r in poly.interiors)
output={'source':'../blocked-tab-upload.svg','word_width_before_offset_mm':14.1,
        'base_scaled_word_width_mm':12,'added_tracking_mm':.35,'small_counter_expansion_mm':.15,
        'outline_expansion_mm':.07,'area_mm2':shape.area,'glyphs':len(shape.geoms),
        'contours':contours}
(root/'legend-contours.json').write_text(json.dumps(output,separators=(',',':'))+'\n')
print('Wrote',len(contours),'closed contours; area',shape.area,'mm²')
