import bpy, json, math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
source=ROOT/'assets/character_animation/burger27/build_animation_pack.py'
exec(compile(source.read_text().split('actions={};samples={}')[0],str(source),'exec'),dict_globals:=dict(__file__=str(source)))
globals().update({k:v for k,v in dict_globals.items() if k!='__file__'})
OUT=ROOT/'assets/character_animation/truck_hit'
motion={'fps':30,'rest':{b.name:[list(r) for r in b.matrix_local] for b in rig.data.bones},'clips':[]}
action=bpy.data.actions.new('Truck_Smack');action.use_fake_user=True
rig.animation_data_create();rig.animation_data.action=action
dict_globals['lastq']={}
frames=[]
for frame in range(1,43):
 t=(frame-1)/30
 d=choreography('Idle_Forward',t/1.4)
 wind=interp(t,[(0,0),(.36,1),(.58,0),(.76,.25),(1.4,0)])
 strike=interp(t,[(0,0),(.36,0),(.58,1),(.68,1),(.98,.15),(1.4,0)])
 weight=interp(t,[(0,0),(.25,1),(1.05,1),(1.4,0)])
 d['R']=Vector(d['R']).lerp(Vector((-.62,-.35+wind*.65-strike*.95,2.05+wind*.32-strike*.18)),weight)
 d['RP']=[-1.2,.25,2.1]
 d['L']=Vector(d['L']).lerp(Vector((.65,-.58,1.95)),weight)
 d['spine']=[-9*wind+18*strike,0,-12*wind+9*strike]
 d['chest']=[-6*wind+12*strike,0,-10*wind+8*strike]
 d['head']=[8*strike,0,0]
 d['gripR']=1.0;d['gripL']=.55
 p=solve(d);p.key(action,frame)
 scene.frame_set(frame);bpy.context.view_layer.update()
 frames.append({'time':t,'bones':{b.name:[list(r) for r in b.matrix] for b in rig.pose.bones}})
motion['clips'].append({'name':'Truck_Smack','length':1.4,'loop':False,'prop':'','frames':frames})
from mathutils import Matrix, Quaternion
act=bpy.data.actions.new('Grisaldi_Cartwheel');act.use_fake_user=True;rig.animation_data.action=act
dict_globals['lastq']={};frames=[]
for frame in range(1,85):
 t=(frame-1)/30
 u=smooth((t-.4)/1.75)
 d=choreography('Idle_Forward',t/2.8)
 reach=smooth(t/.4)*(1-smooth((t-2.15)/.65))
 d['L']=Vector(d['L']).lerp(Vector((.58,-.08,3.25)),reach)
 d['R']=Vector(d['R']).lerp(Vector((-.58,-.08,3.25)),reach)
 d['LF'][0]+=.72*math.sin(u*math.pi);d['RF'][0]-=.72*math.sin(u*math.pi)
 d['LF'][1]+=.15*math.sin(u*math.tau);d['RF'][1]-=.15*math.sin(u*math.tau)
 d['root'][2]-=.18*(smooth(t/.25)*(1-smooth((t-.25)/.2))+smooth((t-2.15)/.2)*(1-smooth((t-2.4)/.4)))
 pose=solve(d);pose.key(act,frame);scene.frame_set(frame)
 root_bone=rig.pose.bones['HipsCtrl']
 pivot=Vector((0,0,1.65))
 transform=Matrix.Translation(pivot) @ Matrix.Rotation(u*math.tau,4,'Y') @ Matrix.Translation(-pivot)
 # Ground the lowest supporting hand/foot instead of rotating in mid-air.
 contact_points=[transform @ rig.pose.bones[n].head for n in ['LeftHand','RightHand','LeftFoot','RightFoot']]
 lift=.10-min(v.z for v in contact_points)
 transform=Matrix.Translation((.65*math.sin(u*math.pi),0,lift)) @ transform
 root_bone.matrix=transform @ root_bone.matrix
 root_bone.keyframe_insert(data_path='location',frame=frame)
 root_bone.keyframe_insert(data_path='rotation_quaternion',frame=frame)
 bpy.context.view_layer.update()
 frames.append({'time':t,'bones':{b.name:[list(r) for r in b.matrix] for b in rig.pose.bones}})
motion['clips'].append({'name':'Grisaldi_Cartwheel','length':2.8,'loop':False,'prop':'','frames':frames})
act=bpy.data.actions.new('Grisaldi_Strut');act.use_fake_user=True;rig.animation_data.action=act
dict_globals['lastq']={};frames=[]
for frame in range(1,37):
 t=(frame-1)/30;phase=t/1.2*math.tau
 d=choreography('Idle_Forward',t/1.2)
 d['root'][2]=-.04+.045*(1-math.cos(phase*2))
 d['hips_rot']=[0,0,5*math.sin(phase)]
 d['spine']=[-4,3*math.sin(phase),-5*math.sin(phase)]
 d['chest']=[-3,0,7*math.sin(phase)]
 d['head']=[0,0,-3*math.sin(phase)]
 for side,offset in [('L',0),('R',math.pi)]:
  q=phase+offset
  d[side+'F'][1]=.15+.31*math.cos(q)
  d[side+'F'][2]=.1932+.19*max(0,math.sin(q))
  d[side][1]=-.1-.20*math.cos(q)
  d[side][2]=1.56+.07*math.sin(q)
 pose=solve(d);pose.key(act,frame);scene.frame_set(frame);bpy.context.view_layer.update()
 frames.append({'time':t,'bones':{b.name:[list(r) for r in b.matrix] for b in rig.pose.bones}})
motion['clips'].append({'name':'Grisaldi_Strut','length':1.2,'loop':True,'prop':'','frames':frames})
scene.frame_start=1;scene.frame_end=85;scene.render.fps=30
(OUT/'game_motion.json').write_text(json.dumps(motion,separators=(',',':')))
rig.animation_data.action=bpy.data.actions['Truck_Smack'];scene.frame_set(18)
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
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Customer_Truck_Hit.blend'))
scene.render.filepath=str(ROOT/'output/truck_hit_blender.png');bpy.ops.render.render(write_still=True)
print('TRUCK_HIT_BLENDER_BAKED')
