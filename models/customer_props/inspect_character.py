import bpy,json
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=r'C:\Users\joe\Desktop\burgergame\assets\characters\Model\characterMedium.fbx')
for o in bpy.context.scene.objects:
 print('OBJECT',o.name,o.type,list(o.dimensions))
 if o.type=='ARMATURE':
  print('BONES',[(b.name,list(b.head_local),list(b.tail_local)) for b in o.data.bones])
 if o.type=='MESH':
  print('BOUNDS',list(map(min,zip(*[o.matrix_world@Vector(p) for p in o.bound_box]))),list(map(max,zip(*[o.matrix_world@Vector(p) for p in o.bound_box]))))
  print('MATERIALS',[m.name for m in o.data.materials if m])
print('CHARACTER_INSPECT_COMPLETE')
