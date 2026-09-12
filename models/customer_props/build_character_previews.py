import bpy,math,json
from pathlib import Path
from mathutils import Vector,Matrix,Quaternion
from math import pi
OUT=Path(r'C:\Users\joe\Desktop\burgergame\models\customer_props')
bpy.ops.wm.open_mainfile(filepath=str(OUT/'customer_props.blend'))
catalog=bpy.data.scenes['CUSTOMER PROPS | 30']
manifest=json.loads((OUT/'manifest.json').read_text())
asset_objects={a['id']:bpy.data.objects[a['id']] for a in manifest}
source_scene=bpy.data.scenes.new('CHARACTER SOURCE')
bpy.context.window.scene=source_scene
bpy.ops.import_scene.fbx(filepath=r'C:\Users\joe\Desktop\burgergame\assets\characters\Model\characterMedium.fbx')
original_rig=next(o for o in source_scene.objects if o.type=='ARMATURE')
original_mesh=next(o for o in source_scene.objects if o.type=='MESH')
original_mesh_local=original_rig.matrix_world.inverted()@original_mesh.matrix_world
print('CHAR_MATERIAL',[(m.name,[(n.type,n.image.filepath if n.type=='TEX_IMAGE' and n.image else '') for n in m.node_tree.nodes] if m.use_nodes else []) for m in original_mesh.data.materials])
# FBX skin imports with zero alpha; restore preview opacity.
for mat in original_mesh.data.materials:
 if mat and mat.use_nodes:
  for node in mat.node_tree.nodes:
   if node.type=='BSDF_PRINCIPLED':node.inputs['Alpha'].default_value=1.0
# Keep the supplied character mesh and its skin material; just pose preview copies.
SCALE=.552
M={k.name.removeprefix('CP_'):k for k in bpy.data.materials if k.name.startswith('CP_')}
def text(body,loc,size,coll,mat='type'):
 cu=bpy.data.curves.new(body,'FONT');cu.body=body;cu.size=size
 ob=bpy.data.objects.new(body,cu);coll.objects.link(ob);ob.location=loc;cu.materials.append(M[mat]);return ob
def disc(loc,r,coll):
 bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=r,depth=.065,location=loc)
 o=bpy.context.object;o.data.materials.append(M['tile'])
 for c in list(o.users_collection):c.objects.unlink(o)
 coll.objects.link(o)
 be=o.modifiers.new('Rounded pedestal','BEVEL');be.width=.022;be.segments=2
 return o
def character_fit(scene,a,pos):
 idx=int(a['id'][:2]);loc=Vector(pos)
 coll=bpy.data.collections.new(a['id']+' | CHARACTER FIT');scene.collection.children.link(coll)
 rig=original_rig.copy();rig.data=original_rig.data.copy();rig.name=a['id']+' | characterMedium rig';coll.objects.link(rig);rig.animation_data_clear()
 rig.matrix_world=Matrix.Translation(loc)@Matrix.Diagonal(Vector((SCALE,SCALE,SCALE,1)))@original_rig.matrix_world
 body=original_mesh.copy();body.name=a['id']+' | characterMedium';coll.objects.link(body)
 body.parent=rig;body.matrix_parent_inverse=Matrix.Identity(4);body.matrix_basis=original_mesh_local
 body.animation_data_clear()
 for mod in body.modifiers:
  if mod.type=='ARMATURE':mod.object=rig
 for pb in rig.pose.bones:
  pb.matrix_basis=Matrix.Identity(4)
  for co in list(pb.constraints):pb.constraints.remove(co)
 # Natural resting left arm, varied right arm for carry vs raised grip.
 left=(.32,-.02,.84)
 right=(-.38,-.22,1.00)
 if idx==1:right=(-.40,-.15,1.50)
 elif idx==3:right=(-.38,-.04,1.69)
 elif idx in [11,12,15,16,17,20]:right=(-.40,-.34,1.12)
 elif idx in [21,22,27,28]:right=(-.38,-.25,1.09)
 elif idx==23:right=(-.42,-.24,1.03)
 elif idx==24:right=(-.38,-.24,1.10)
 elif idx==26:right=(-.40,-.16,1.00)
 elif idx==25:right=(-.40,-.16,1.06)
 elif idx in [4,5,6,7,8]:right=(-.38,-.04,.99)
 elif idx in [9,10,30]:right=(-.35,-.36,1.02)
 targets=[]
 for side,where in [('Right',right),('Left',left)]:
  target=bpy.data.objects.new(side+' wrist target',None);coll.objects.link(target);target.location=loc+Vector(where);target.empty_display_size=.025;target.hide_render=True
  pole=bpy.data.objects.new(side+' elbow guide',None);coll.objects.link(pole)
  pole.location=loc+Vector((-.75 if side=='Right' else .75,-.6,1.15));pole.hide_render=True;pole.empty_display_size=.025
  co=rig.pose.bones[side+'ForeArm'].constraints.new('IK');co.target=target;co.pole_target=pole;co.chain_count=2;co.use_tail=True
  targets.extend([target,pole])
 for side in ['Left','Right']:
  for bone,angle in [('HandIndex1',.35),('HandIndex2',.55),('HandIndex3',.55),('HandThumb1',.20),('HandThumb2',.30)]:
   pb=rig.pose.bones.get(side+bone)
   if pb:
    axis=pb.bone.matrix_local.to_3x3().inverted()@Vector((0,1,0))
    pb.rotation_mode='QUATERNION';pb.rotation_quaternion=Quaternion(axis,angle*(1 if side=='Left' else -1))
 bpy.context.view_layer.update()
 hand=rig.pose.bones['RightHand']
 palm=rig.matrix_world@(hand.head+(hand.tail-hand.head)*1.35)
 # Meter-scale mesh; display-scale transformations are intentionally not copied.
 prop=asset_objects[a['id']].copy();prop.data=asset_objects[a['id']].data
 prop.name=a['id']+' | held at game scale';coll.objects.link(prop);prop.parent=None
 prop.scale=(1,1,1);prop.rotation_euler=(0,0,0);prop.location=(0,0,0)
 prop['preview_character_scale']=SCALE
 grip=Vector((a['grip_godot_xyz'][0],-a['grip_godot_xyz'][2],a['grip_godot_xyz'][1]))
 rot=Matrix.Identity(3)
 if idx==25:
  rot=Matrix.Rotation(pi/3,3,'Z')@Matrix.Rotation(-pi/2,3,'Y')
  grip=Vector((.032,0,.1312))
 elif idx in [11,12,15,16,17,20]:
  rot=Matrix.Rotation(-.16,3,'X')@Matrix.Rotation(-.18,3,'Z')
 elif idx==26:
  rot=Matrix.Rotation(pi/3,3,'Y')
 elif idx==24:
  grip=Vector((.16,0,.230))
 elif idx in [9,10,30]:
  grip=Vector((.18,0,.08))
 elif idx==1:
  rot=Matrix.Rotation(-.12,3,'Y')
 elif idx==7:
  # Backpack worn on the back; preview uses the existing straps.
  prop.matrix_world=Matrix.Translation(loc+Vector((0,.25,.83)))@Matrix.Rotation(pi,4,'Z')
  grip=None
 if grip is not None:
  target=palm+Vector((0,-.025,0))
  prop.matrix_world=Matrix.Translation(target-rot@grip)@rot.to_4x4()
  desired=prop.matrix_world.copy()
  prop.parent=rig;prop.parent_type='BONE';prop.parent_bone='RightHand'
  bpy.context.view_layer.update();prop.matrix_world=desired
  bpy.context.view_layer.update();prop.matrix_world=desired
  marker=bpy.data.objects.new(a['id']+' | GripPoint',None);coll.objects.link(marker);marker.parent=prop;marker.location=grip;marker.hide_render=True;marker.hide_set(True)
 rig.hide_set(True)
 for ob in targets:ob.hide_set(True)
 return coll
def setup_scene(name):
 scene=bpy.data.scenes.new(name);scene.world=catalog.world
 bpy.context.window.scene=scene
 scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
 scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast'
 stage=bpy.data.collections.new(name+' | STAGE');scene.collection.children.link(stage)
 bpy.ops.mesh.primitive_plane_add(size=200)
 floor=bpy.context.object;floor.name='Preview floor';floor.data.materials.append(M['stage'])
 for c in list(floor.users_collection):c.objects.unlink(floor)
 stage.objects.link(floor)
 for n,loc,power,size,col in [('Key',(-4,-6,10),1800,7,(1,.93,.84)),('Fill',(6,-1,7),1100,7,(.75,.85,1)),('Rim',(-2,7,9),1600,6,(.77,.93,1))]:
  ld=bpy.data.lights.new(name+n,'AREA');ld.energy=power;ld.shape='DISK';ld.size=size;ld.color=col
  ob=bpy.data.objects.new(n,ld);stage.objects.link(ob);ob.location=loc;ob.rotation_euler=(Vector((0,0,1))-ob.location).to_track_quat('-Z','Y').to_euler()
 return scene,stage
# One copy of the supplied character per prop, with bone-attached held examples.
allscene,stage=setup_scene('CHARACTER PREVIEWS | All 30')
for i,a in enumerate(manifest):
 x=(i%6-2.5)*3.3;y=(2-i//6)*4.0
 with bpy.context.temp_override(scene=allscene,view_layer=allscene.view_layers[0]):
  character_fit(allscene,a,(x,y,.07))
 disc((x,y,.035),.85,stage)
 text(a['id'].replace('_',' ').upper(),(x-.86,y-.84,.077),.092,stage)
text('ALL 30 / CHARACTER FIT',(-6.2,7.55,.03),.32,stage)
text('SUPPLIED CHARACTERMEDIUM  /  GAME SCALE 0.552  /  PROPS IN METERS',(-6.18,7.16,.03),.105,stage,'muted')
cd=bpy.data.cameras.new('All thirty camera');cam=bpy.data.objects.new('All thirty camera',cd);stage.objects.link(cam)
cam.location=(0,-23,26);cam.rotation_euler=(Vector((0,.3,.8))-cam.location).to_track_quat('-Z','Y').to_euler();cd.type='ORTHO';cd.ortho_scale=24.8;allscene.camera=cam
allscene.render.resolution_x=2000;allscene.render.resolution_y=2200;allscene.render.resolution_percentage=100;allscene.render.filepath=str(OUT/'all_30_character_preview.png')
# Larger six-prop scene for judging the refined silhouettes and hand fit.
focus,stage=setup_scene('CHARACTER PREVIEWS | Refined six')
ids=[0,5,22,23,24,19]
for i,aid in enumerate(ids):
 a=manifest[aid];x=(i%3-1)*3.7;y=(.5-i//3)*4.6
 with bpy.context.temp_override(scene=focus,view_layer=focus.view_layers[0]):
  character_fit(focus,a,(x,y,.07))
 disc((x,y,.035),1,stage)
 text(a['id'].replace('_',' ').upper(),(x-.93,y-.91,.077),.115,stage)
text('REFINED / CUSTOMER PROPS',(-3.68,3.45,.04),.3,stage)
text('CHARACTERMEDIUM  /  GAME SCALE  /  STRONGER COLOR',(-3.65,3.08,.04),.115,stage,'muted')
cd=bpy.data.cameras.new('Refined props camera');cam=bpy.data.objects.new('Refined props camera',cd);stage.objects.link(cam)
cam.location=(0,-16,12.5);cam.rotation_euler=(Vector((0,.3,1))-cam.location).to_track_quat('-Z','Y').to_euler();cd.type='ORTHO';cd.ortho_scale=13.2;focus.camera=cam
focus.render.resolution_x=1800;focus.render.resolution_y=1700;focus.render.resolution_percentage=100;focus.render.filepath=str(OUT/'refined_character_preview.png')
# Headings above the models, facing their cameras.
for scn,heading,sub,z,y in [(focus,'REFINED / CUSTOMER PROPS','CHARACTERMEDIUM  /  GAME SCALE  /  STRONGER COLOR',4.1,4.2),(allscene,'ALL 30 / CHARACTER FIT','SUPPLIED CHARACTERMEDIUM  /  GAME SCALE 0.552  /  PROPS IN METERS',4.0,9.2)]:
 for ob in scn.objects:
  if ob.type=='FONT' and ob.data.body in [heading,sub]:
   ob.location.z=z if ob.data.body==heading else z-.33
   ob.location.y=y;ob.rotation_euler=scn.camera.rotation_euler
# The imported source is now represented by the editable preview instances.
bpy.data.scenes.remove(source_scene)
bpy.context.window.scene=focus
for area in bpy.context.screen.areas:
 if area.type=='VIEW_3D':
  area.spaces.active.shading.type='MATERIAL'
  area.spaces.active.overlay.show_overlays=False
  area.spaces.active.region_3d.view_perspective='CAMERA'
  area.spaces.active.region_3d.view_camera_zoom=0
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'customer_props.blend'),compress=True)
bpy.ops.render.render(write_still=True,scene=focus.name)
print('REFINED_CHARACTER_PREVIEW_COMPLETE',flush=True)
bpy.ops.render.render(write_still=True,scene=allscene.name)
print('ALL_CHARACTER_PREVIEWS_COMPLETE',flush=True)
