"""Combine existing, print-oriented STL parts into single build-plate files.

blender --background --factory-startup --python enclosure/print-layout.py
Geometry is translated only; source STL orientations and dimensions are kept.
"""
import json
from pathlib import Path

import bmesh
import bpy

ROOT = Path(__file__).resolve().parent
STL = ROOT / "stl"
LAYOUTS = {
    "blocked-print-plate": [("base", 0, 0), ("lid", 52, 0)],
    "blocked-print-plate-with-coupons": [
        ("base", 0, 0), ("lid", 52, 0),
        ("fit-coupon", 0, 48), ("case-fastener-coupon", 72, 48),
        ("board-fastener-coupon", 0, 80),
        ("usb-fit-coupon", 42, 80),
    ],
}
report = {}
for name, layout in LAYOUTS.items():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    parts, boxes = [], []
    for source, x, y in layout:
        bpy.ops.wm.stl_import(filepath=str(STL / f"{source}.stl"))
        obj = bpy.context.object
        obj.name = source
        # Place each bounding-box minimum on the specified plate coordinate.
        low = [min(v.co[i] for v in obj.data.vertices) for i in range(3)]
        for vertex in obj.data.vertices:
            vertex.co.x += x - low[0]
            vertex.co.y += y - low[1]
            vertex.co.z -= low[2]
        bounds = [[min(v.co[i] for v in obj.data.vertices),
                   max(v.co[i] for v in obj.data.vertices)] for i in range(3)]
        mesh = bmesh.new()
        mesh.from_mesh(obj.data)
        assert all(edge.is_manifold for edge in mesh.edges), source
        assert mesh.calc_volume(signed=True) > 0, source
        mesh.free()
        for previous in boxes:
            assert (bounds[0][0] >= previous[0][1] + 5.99 or
                    previous[0][0] >= bounds[0][1] + 5.99 or
                    bounds[1][0] >= previous[1][1] + 5.99 or
                    previous[1][0] >= bounds[1][1] + 5.99), "Parts too close"
        boxes.append(bounds)
        parts.append(obj)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.wm.stl_export(filepath=str(STL / f"{name}.stl"), export_selected_objects=True)
    report[name] = {
        "parts": [source for source, _, _ in layout],
        "dimensions_mm": [round(max(b[i][1] for b in boxes), 3) for i in range(3)],
        "minimum_part_spacing_mm": 6,
        "all_parts_manifold": True,
        "all_parts_on_z_zero": True,
        "orientation": "Source print orientation retained: base floor-down, lid top-down",
    }
(ROOT / "print-layout-validation.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report, indent=2))
