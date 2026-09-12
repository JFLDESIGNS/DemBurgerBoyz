import bpy
from pathlib import Path
from mathutils import Vector
p=Path('C:/Users/joe/Desktop/burgergame/assets/machines')
s=bpy.context.scene
original=list(bpy.data.collections['GRILL | Export'].all_objects)
def bounds(objects):
    points=[o.matrix_world @ Vector(v) for o in objects if o.type=='MESH' for v in o.bound_box]
    return [[round(min(v[i] for v in points),5) for i in range(3)],[round(max(v[i] for v in points),5) for i in range(3)]]
print('SOURCE_BOUNDS',bounds(original))
bpy.data.collections['GRILL | Export'].hide_render=True
before=set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(p/'stylized_grill.glb'))
imported=set(bpy.data.objects)-before
bpy.context.view_layer.update()
print('EXPORTED_BOUNDS',bounds(imported))
s.render.filepath=str(p/'stylized_grill_export_preview.png')
s.cycles.samples=32
bpy.ops.render.render(write_still=True)
