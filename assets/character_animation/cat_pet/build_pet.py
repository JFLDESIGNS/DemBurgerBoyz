import bpy, json, math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
source=ROOT/'assets/character_animation/burger27/build_animation_pack.py'
exec(compile(source.read_text().split('actions={};samples={}')[0],str(source),'exec'),dict_globals:=dict(__file__=str(source)))
globals().update({k:v for k,v in dict_globals.items() if k!='__file__'})
OUT=ROOT/'assets/character_animation/cat_pet'
motion={'fps':30,'rest':{b.name:[list(r) for r in b.matrix_local] for b in rig.data.bones},'clips':[]}
for side in ['Right','Left']:
 action=bpy.data.actions.new('Pet_Cat_'+side);action.use_fake_user=True
 rig.animation_data_create();rig.animation_data.action=action
 dict_globals['lastq']={}
 frames=[]
 for frame in range(1,74):
  t=(frame-1)/72
  d=choreography('Idle_Forward',t)
  weight=smooth(t/.2)*(1-smooth((t-.78)/.22))
  stroke=math.sin(max(0,t-.2)*math.pi*6)
  hand='R' if side=='Right' else 'L'
  sign=-1 if side=='Right' else 1
  d[hand]=Vector(d[hand]).lerp(Vector((sign*.98,-.57+stroke*.13,1.32+stroke*.025)),weight)
  d[hand+'P']=[sign*1.15,.15,1.72]
  d['spine']=[12*weight,0,sign*-6*weight]
  d['chest']=[7*weight,0,sign*-5*weight]
  d['head']=[16*weight,sign*12*weight,0]
  d['hand'+hand]=[0,-1,-.1]
  d['grip'+hand]=.03
  p=solve(d);p.key(action,frame)
  scene.frame_set(frame);bpy.context.view_layer.update()
  frames.append({'time':(frame-1)/30,'bones':{b.name:[list(r) for r in b.matrix] for b in rig.pose.bones}})
 motion['clips'].append({'name':action.name,'length':2.4,'loop':False,'prop':'','frames':frames})
scene.frame_start=1;scene.frame_end=73;scene.render.fps=30
(OUT/'game_motion.json').write_text(json.dumps(motion,separators=(',',':')))
rig.animation_data.action=bpy.data.actions['Pet_Cat_Right'];scene.frame_set(36)
# A simple lit preview preserves the actual source rig and baked keys.
bounds=[o.matrix_world@Vector(c) for o in scene.objects if o.type=='MESH' for c in o.bound_box]
lo=Vector(tuple(min(v[i] for v in bounds) for i in range(3)));hi=Vector(tuple(max(v[i] for v in bounds) for i in range(3)))
center=(lo+hi)*.5;span=max(hi-lo)
bpy.ops.object.camera_add(location=center+Vector((span*1.4,-span*2,span*.55)))
cam=bpy.context.object;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=span*1.5;scene.camera=cam;cam.data.clip_start=.00001;cam.data.clip_end=100
bpy.ops.object.light_add(type='AREA',location=center+Vector((span,-span,span*2)))
bpy.context.object.data.energy=700;bpy.context.object.data.shape='DISK';bpy.context.object.data.size=span*2
scene.world=bpy.data.worlds.new('Pet preview world');scene.world.color=(.22,.22,.22)
scene.render.engine='BLENDER_WORKBENCH';scene.display.shading.light='STUDIO';scene.display.shading.color_type='MATERIAL';scene.render.resolution_x=800;scene.render.resolution_y=800;scene.render.resolution_percentage=100
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Customer_Cat_Petting.blend'))
scene.render.filepath=str(ROOT/'output/cat_pet_blender.png');bpy.ops.render.render(write_still=True)
print('CAT_PET_BLENDER_BAKED')
