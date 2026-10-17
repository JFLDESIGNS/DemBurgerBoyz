"""Bake editable cash handoff, food photography and a planted spin/throw in Blender."""
import bpy, json, math
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion
ROOT=Path(__file__).resolve().parents[2]
source=ROOT/'assets/character_animation/burger27/build_animation_pack.py'
ns=dict(__file__=str(source))
exec(compile(source.read_text().split('actions={};samples={}')[0],str(source),'exec'),ns)
globals().update({k:v for k,v in ns.items() if k!='__file__'})
OUT=ROOT/'assets/character_animation/customer_service';OUT.mkdir(exist_ok=True)
motion={'fps':30,'rest':{b.name:[list(r) for r in b.matrix_local] for b in rig.data.bones},'clips':[]}
for name,length,prop in [('Give_Money',1.6,'card'),('Grisaldi_Photos',4.8,'phone'),('Grisaldi_Spin_Throw',2.6,'card')]:
 action=bpy.data.actions.new(name);action.use_fake_user=True
 rig.animation_data_create();rig.animation_data.action=action;ns['lastq']={};frames=[]
 for frame in range(round(length*30)+1):
  t=frame/30;u=t/length
  d=choreography('Phone_Two_Hands' if prop=='phone' else 'Idle_Forward',u)
  if name=='Give_Money':
   reach=interp(u,[(0,0),(.2,.15),(.5,1),(.7,1),(1,0)])
   d['R']=Vector(d['R']).lerp(Vector((-.25,-1.03,2.05)),reach)
   d['RP']=(-.95,-.1,1.8);d['gripR']=.25*(1-smooth((u-.6)/.12))
   d['spine']=[8*reach,0,0];d['head']=[8*reach,0,0]
  elif name=='Grisaldi_Photos':
   side=interp(u,[(0,0),(.2,-.22),(.4,-.22),(.55,.23),(.72,.23),(.86,0),(1,0)])
   height=interp(u,[(0,0),(.2,-.22),(.4,-.22),(.55,.08),(.72,.08),(.86,.3),(1,0)])
   offset=Vector((side,-.12,height))
   d['L']+=offset;d['R']+=offset;d['prop_pos']+=offset
   d['head']=[6-height*12,0,-side*22];d['spine']=[10-height*12,0,side*22]
  else:
   spin=smooth((u-.12)/.5);d['yaw']=360*spin
   wind=interp(u,[(0,0),(.18,1),(.6,1),(.76,0),(1,0)])
   release=interp(u,[(0,0),(.62,0),(.76,1),(.86,1),(1,0)])
   d['R']=Vector((-.58,-.1+wind*.25-release*.95,1.5+wind*.95+release*1.1))
   d['L']=Vector((.58+wind*.18,-.15,1.5+wind*.5))
   d['spine']=[-8*wind+12*release,0,0];d['gripR']=.5*(1-release)
   d['root'][2]=-.07*math.sin(spin*math.pi)
   d['RF'][2]+=.09*math.sin(spin*math.pi)
  pose=solve(d);pose.key(action,frame+1);scene.frame_set(frame+1);bpy.context.view_layer.update()
  if prop=='phone':pos,rot=Vector(d['prop_pos']),Quaternion()
  else:
   hand=pose.world['RightHand'];pos=hand.translation+hand.to_quaternion()@Vector((0,.18,0));rot=hand.to_quaternion()
  transform=Matrix.Translation(pos)@rot.to_matrix().to_4x4()
  frames.append({'time':t,'bones':{b.name:[list(r) for r in b.matrix] for b in rig.pose.bones},'prop':[list(r) for r in transform]})
 motion['clips'].append({'name':name,'length':length,'loop':False,'prop':prop,'frames':frames})
scene.frame_start=1;scene.frame_end=145;scene.render.fps=30
(OUT/'game_motion.json').write_text(json.dumps(motion,separators=(',',':')))
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Customer_Service.blend'))
print('CUSTOMER_SERVICE_BAKED')
