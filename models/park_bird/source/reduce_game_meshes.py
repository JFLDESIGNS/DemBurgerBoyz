import bpy, json, math
from pathlib import Path
root=Path(__file__).resolve().parents[3]
report={}
for name in ['park_bird','birdhouse']:
 bpy.ops.wm.read_factory_settings(use_empty=True)
 path=root/'models/park_bird'/f'{name}.glb'
 bpy.ops.import_scene.gltf(filepath=str(path))
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
 def tris(o):return sum(len(p.vertices)-2 for p in o.data.polygons)
 before=sum(tris(o) for o in meshes)
 ratio=min(1,1900/before)
 for o in meshes:
  if tris(o)<12:continue
  bpy.context.view_layer.objects.active=o;o.select_set(True)
  mod=o.modifiers.new('Game mesh budget','DECIMATE');mod.ratio=ratio
  mod.use_collapse_triangulate=True
  bpy.ops.object.modifier_apply(modifier=mod.name)
  for face in o.data.polygons:face.use_smooth=True
  o.select_set(False)
 after=sum(tris(o) for o in meshes)
 # Retain source animations, armatures, skin weights, and material slots.
 bpy.ops.wm.save_as_mainfile(filepath=str(root/'models/park_bird/source'/f'{name}_2k.blend'))
 bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',export_animations=True,export_animation_mode='ACTIONS',export_yup=True)
 report[name]={'before_triangles':before,'after_triangles':after,'meshes':len(meshes),'actions':[a.name for a in bpy.data.actions]}
(root/'models/park_bird/low_poly_validation.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report))
