import bpy,math
from pathlib import Path
from mathutils import Vector,Matrix
out=Path(r'C:\Users\joe\Desktop\burgergame\models\customer_props')
bpy.ops.wm.open_mainfile(filepath=str(out/'customer_props.blend'))
for scene in bpy.data.scenes:
 if not scene.name.startswith('CHARACTER PREVIEWS'):continue
 bpy.context.window.scene=scene
 with bpy.context.temp_override(scene=scene,view_layer=scene.view_layers[0]):
  for coll in scene.collection.children:
   if not coll.name.startswith(('03_Roller_Suitcase | CHARACTER','25_Skateboard | CHARACTER','26_Walking_Cane | CHARACTER')):continue
   prop=next(o for o in coll.objects if o.type=='MESH' and ' | held at game scale' in o.name)
   marker=next(c for c in prop.children if 'GripPoint' in c.name)
   anchor=prop.matrix_world@marker.location
   if coll.name.startswith('03_'):
    rig=next(o for o in coll.objects if o.type=='ARMATURE')
    target=next(o for o in coll.objects if o.name.startswith('Right wrist target'))
    target.location=rig.matrix_world.translation+Vector((-.38,-.04,1.69))
    bpy.context.view_layer.update()
    hand=rig.pose.bones['RightHand']
    anchor=rig.matrix_world@(hand.head+(hand.tail-hand.head)*1.35)+Vector((0,-.025,0))
    rot=Matrix.Identity(3)
   elif coll.name.startswith('25_'):rot=Matrix.Rotation(math.pi/3,3,'Z')@Matrix.Rotation(-math.pi/2,3,'Y')
   else:rot=Matrix.Rotation(math.pi/3,3,'Y')
   prop.matrix_world=Matrix.Translation(anchor-rot@marker.location)@rot.to_4x4()
  bpy.context.view_layer.update()
  for prop in scene.objects:
   if prop.type=='MESH' and ' | held at game scale' in prop.name:
    zs=[(prop.matrix_world@Vector(v)).z for v in prop.bound_box]
    if min(zs)<.015:print('FLOOR_CHECK',prop.name,round(min(zs),3),flush=True)
focus=bpy.data.scenes['CHARACTER PREVIEWS | Refined six']
bpy.context.window.scene=focus
for ar in bpy.context.screen.areas:
 if ar.type=='VIEW_3D':
  sp=ar.spaces.active;sp.shading.type='MATERIAL';sp.overlay.show_overlays=False
  rv=sp.region_3d;rv.view_perspective='ORTHO';rv.view_location=Vector((0,0,1.55));rv.view_distance=12;rv.view_rotation=focus.camera.rotation_euler.to_quaternion()
bpy.ops.wm.save_as_mainfile(filepath=str(out/'customer_props.blend'),compress=True)
print('POSES_FINAL_SAVED',flush=True)
for name,filename in [('CHARACTER PREVIEWS | Refined six','refined_character_preview.png'),('CHARACTER PREVIEWS | All 30','all_30_character_preview.png')]:
 s=bpy.data.scenes[name];bpy.context.window.scene=s;s.render.filepath=str(out/filename)
 bpy.ops.render.render(write_still=True,scene=s.name)
 print('POSE_PREVIEW_RENDERED',filename,flush=True)
print('POSE_PREVIEWS_COMPLETE',flush=True)
