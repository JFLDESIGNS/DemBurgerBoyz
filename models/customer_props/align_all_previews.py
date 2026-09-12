import bpy,json,math
from pathlib import Path
from mathutils import Vector,Matrix
out=Path(r'C:\Users\joe\Desktop\burgergame\models\customer_props')
bpy.ops.wm.open_mainfile(filepath=str(out/'customer_props.blend'))
for scene in bpy.data.scenes:
 if not scene.name.startswith('CHARACTER PREVIEWS'):continue
 bpy.context.window.scene=scene
 with bpy.context.temp_override(scene=scene,view_layer=scene.view_layers[0]):
  bpy.context.view_layer.update()
  for coll in scene.collection.children:
   if ' | CHARACTER FIT' not in coll.name:continue
   idx=int(coll.name[:2])
   rig=next(o for o in coll.objects if o.type=='ARMATURE')
   prop=next(o for o in coll.objects if o.type=='MESH' and ' | held at game scale' in o.name)
   if idx==7:continue
   marker=next(c for c in prop.children if 'GripPoint' in c.name)
   right=(-.38,-.22,1.00)
   if idx==1:right=(-.40,-.15,1.50)
   elif idx==3:right=(-.38,-.04,1.69)
   elif idx in [11,12,15,16,17,20]:right=(-.40,-.34,1.12)
   elif idx in [21,22,27,28]:right=(-.38,-.25,1.09)
   elif idx==23:right=(-.42,-.24,1.03)
   elif idx==24:right=(-.38,-.24,1.10)
   elif idx==26:right=(-.40,-.16,1.00)
   elif idx==25:right=(-.40,-.16,1.06)
   elif idx in [4,5,6,8]:right=(-.38,-.04,.99)
   elif idx in [9,10,30]:right=(-.35,-.36,1.02)
   target=next(o for o in coll.objects if o.name.startswith('Right wrist target'))
   target.location=rig.matrix_world.translation+Vector(right)
   bpy.context.view_layer.update()
   hand=rig.pose.bones['RightHand']
   anchor=rig.matrix_world@(hand.head+(hand.tail-hand.head)*1.35)+Vector((0,-.025,0))
   rot=Matrix.Identity(3)
   if idx==25:rot=Matrix.Rotation(math.pi/3,3,'Z')@Matrix.Rotation(-math.pi/2,3,'Y')
   elif idx==26:rot=Matrix.Rotation(math.pi/3,3,'Y')
   elif idx in [11,12,15,16,17,20]:rot=Matrix.Rotation(-.16,3,'X')@Matrix.Rotation(-.18,3,'Z')
   elif idx==1:rot=Matrix.Rotation(-.12,3,'Y')
   wanted=Matrix.Translation(anchor-rot@marker.location)@rot.to_4x4()
   prop.matrix_world=wanted
   bpy.context.view_layer.update()
   # Guarantee the current dependency graph, not a stale pre-pose parent matrix, defines the bone attachment.
   error=(prop.matrix_world.translation-wanted.translation).length
   if error>.001:
    prop.matrix_world=wanted
    bpy.context.view_layer.update()
   low=min((prop.matrix_world@Vector(v)).z for v in prop.bound_box)
   print(scene.name,idx,'bottom',round(low,3),'scale',[round(x,3) for x in prop.matrix_world.to_scale()],flush=True)
focus=bpy.data.scenes['CHARACTER PREVIEWS | Refined six'];bpy.context.window.scene=focus
bpy.ops.wm.save_as_mainfile(filepath=str(out/'customer_props.blend'),compress=True)
print('ALL_HAND_ALIGNMENT_SAVED',flush=True)
for name,filename in [('CHARACTER PREVIEWS | Refined six','refined_character_preview.png'),('CHARACTER PREVIEWS | All 30','all_30_character_preview.png')]:
 s=bpy.data.scenes[name];bpy.context.window.scene=s;s.render.filepath=str(out/filename)
 bpy.ops.render.render(write_still=True,scene=s.name)
 print('RENDERED',filename,flush=True)
print('PREVIEW_ALIGNMENT_COMPLETE',flush=True)
