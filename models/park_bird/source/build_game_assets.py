import bpy, math, json, os, struct
from mathutils import Vector
from pathlib import Path
ROOT=Path(r'C:\Users\joe\Desktop\burgergame'); OUT=ROOT/'models/park_bird';SRC=OUT/'source'
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'output/bird_house_variants/version_3/Bird_and_House.blend'))
scene=bpy.context.scene;scene.render.fps=24
bc=next(c for c in scene.collection.children if c.name.startswith('BIRD') and len(c.objects));hc=next(c for c in scene.collection.children if c.name.startswith('HOUSE') and len(c.objects))
birds=list(bc.objects);houses=list(hc.objects)
for o in list(scene.objects):
 if o not in birds+houses:bpy.data.objects.remove(o,do_unlink=True)
# Recolor only the feathers to the first approved blue palette.
for o in birds:
 for m in o.data.materials:
  col=None
  if m.name.startswith('Bird blue'):col=(.16,.32,.74,1)
  elif m.name.startswith('Wing blue'):col=(.055,.115,.32,1)
  if col:
   m.diffuse_color=col;next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED').inputs['Base Color'].default_value=col

def select(obs):
 bpy.ops.object.select_all(action='DESELECT')
 for o in obs:o.select_set(True)
 bpy.context.view_layer.objects.active=obs[0]

def apply_geo(o,target):
 select([o])
 for m in list(o.modifiers):
  bpy.ops.object.modifier_apply(modifier=m.name)
 bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
 tri=o.modifiers.new('Game triangles','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=tri.name)
 count=len(o.data.polygons)
 if count>target:
  d=o.modifiers.new('Game mesh budget','DECIMATE');d.ratio=target/count;d.use_collapse_triangulate=True;bpy.ops.object.modifier_apply(modifier=d.name)
 # Bake transforms and normalize bird pivot at feet, house pivot at its base.
 mx=o.matrix_world.copy()
 for v in o.data.vertices:v.co=mx@v.co
 o.matrix_world.identity()

assignment={}
for o in birds:
 name=o.name
 target=300
 if name.startswith('Continuous flowing'):target=3000
 elif name.startswith('Unified little foot'):target=750
 elif name.startswith('Separate spheroid eye'):target=650
 elif name.startswith('Convex pupil'):target=450
 elif name.startswith('Fitted soft wing'):target=550
 elif name.startswith('Eye catchlight'):target=100
 apply_geo(o,target)
 for v in o.data.vertices:v.co+=Vector((1.55,0,-.006))
 side='Near' if '-1' in name else 'Far'
 bone='Body'
 if name.startswith(('Separate spheroid','Convex pupil','Eye catchlight')):bone='Eye_'+side
 elif name.startswith('Little wedge'):bone='Head'
 elif name.startswith(('Fitted soft wing','Small folded feather')):bone='Wing_'+side
 elif name.startswith('Tail feather'):bone='Tail'
 elif name.startswith('Unified little foot'):bone='Foot_'+side
 assignment[o.name]=bone
for o in houses:
 apply_geo(o,700 if 'roof' in o.name.lower() else 450)
 for v in o.data.vertices:v.co=(v.co-Vector((1.25,0,-.002)))*1.2
select(houses);bpy.ops.object.join();house=bpy.context.object;house.name='Birdhouse_120_Percent'
# Rig local axes are aligned to Blender world axes, keeping hand-authored motion clear.
arm=bpy.data.armatures.new('ParkBirdSkeleton');rig=bpy.data.objects.new('ParkBirdRig',arm);scene.collection.objects.link(rig);select([rig]);bpy.ops.object.mode_set(mode='EDIT')
def bone(n,p,parent=None):
 b=arm.edit_bones.new(n);b.head=p;b.tail=Vector(p)+Vector((0,.18,0))
 if parent:b.parent=arm.edit_bones[parent]
bone('Root',(0,0,0));bone('Body',(0,0,.44),'Root');bone('Head',(-.13,0,.91),'Body')
for side,y in [('Near',-.30),('Far',.30)]:
 bone('Wing_'+side,(-.04,y,.87),'Body');bone('Foot_'+side,(-.10,y*.82,.27),'Root');bone('Eye_'+side,(-.30,y*1.18,1.225),'Head');bone('Brow_'+side,(-.30,y*1.48,1.40),'Head')
bone('Tail',(.40,0,.63),'Body');bpy.ops.object.mode_set(mode='OBJECT')
# Weighted neck blends smoothly into the head; all other pieces have rigid bone weights.
for o in birds:
 if o.name.startswith('Continuous flowing'):
  bg=o.vertex_groups.new(name='Body');hg=o.vertex_groups.new(name='Head')
  for v in o.data.vertices:
   t=max(0,min(1,(v.co.z-.82)/.37));t=t*t*(3-2*t)
   if t<1:bg.add([v.index],1-t,'REPLACE')
   if t>0:hg.add([v.index],t,'REPLACE')
 else:
  vg=o.vertex_groups.new(name=assignment[o.name]);vg.add(list(range(len(o.data.vertices))),1,'REPLACE')
# Brows appear only during the angry peck clip.
ink=next(m for m in bpy.data.materials if m.name.startswith('Ink pupils'))
for side,y in [('Near',-.477),('Far',.477)]:
 bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,location=(-.30,y,1.43));o=bpy.context.object;o.name='Angry_Brow_'+side;o.scale=(.16,.026,.030);o.rotation_euler.y=-.22;o.data.materials.append(ink);apply_geo(o,150)
 vg=o.vertex_groups.new(name='Brow_'+side);vg.add(list(range(len(o.data.vertices))),1,'REPLACE');birds.append(o)
select(birds);bpy.ops.object.join();bird=bpy.context.object;bird.name='ParkBirdMesh';bird.parent=rig
mod=bird.modifiers.new('ParkBird skin','ARMATURE');mod.object=rig
for p in bird.data.polygons:p.use_smooth=True
rig.show_in_front=True

def reset():
 for b in rig.pose.bones:b.rotation_mode='XYZ';b.location=(0,0,0);b.rotation_euler=(0,0,0);b.scale=(1,1,1)
 for n in ['Brow_Near','Brow_Far']:rig.pose.bones[n].scale=(.001,)*3

def keys(f):
 for b in rig.pose.bones:
  for path in ['location','rotation_euler','scale']:b.keyframe_insert(path,frame=f)
clips={}
for name,frames in [('Idle',73),('Fly_Loop',25),('Perch',31),('Mad_Peck',49),('Takeoff',19)]:
 action=bpy.data.actions.new(name);rig.animation_data_create();rig.animation_data.action=action
 for f in range(1,frames+1):
  reset();p=rig.pose.bones;t=(f-1)/(frames-1)
  strength=0
  if name=='Fly_Loop':strength=1
  elif name=='Perch':strength=(1-t)**2
  elif name=='Takeoff':strength=t*t
  if strength:
   flap=math.cos(t*math.tau*(2 if name=='Fly_Loop' else 3))
   for side,sgn in [('Near',-1),('Far',1)]:
    p['Wing_'+side].rotation_euler=(sgn*(.25+.85*flap)*strength,.06*strength,sgn*1.20*strength)
    p['Foot_'+side].rotation_euler.y=.85*strength
    p['Wing_'+side].scale=(1+.35*strength,1,1+.15*strength)
   p['Body'].location.z=.025*math.sin(t*math.tau*2)*strength;p['Tail'].rotation_euler.y=-.18*strength
  if name=='Idle':
   p['Body'].scale=(1+math.sin(t*math.tau)*.008,1+math.sin(t*math.tau)*.012,1+math.sin(t*math.tau)*.012)
   p['Head'].rotation_euler.z=.09*math.sin(t*math.tau);p['Tail'].rotation_euler.z=.07*math.sin(t*math.tau*2)
   blink=max(0,1-abs(t-.66)/.035)
   for side in ['Near','Far']:p['Eye_'+side].scale.z=1-.90*blink
  elif name=='Perch':
   p['Body'].location.z-=.07*math.sin(t*math.pi);p['Head'].rotation_euler.y=-.08*math.sin(t*math.pi)
  elif name=='Mad_Peck':
   envelope=math.sin(math.pi*t)**.5;strike=max(0,math.sin(t*math.tau*3))**4*envelope
   p['Head'].rotation_euler.y=-.85*strike+.10*envelope;p['Head'].rotation_euler.z=.3*envelope;p['Body'].rotation_euler.y=-.10*strike;p['Body'].location.x=-.16*strike
   p['Foot_Near'].location.y=.14*envelope;p['Foot_Far'].location.y=-.14*envelope
   p['Tail'].rotation_euler.y=.18*envelope
   for side,sgn in [('Near',-1),('Far',1)]:
    p['Wing_'+side].rotation_euler.z=sgn*.20*envelope;p['Brow_'+side].scale=(max(.001,envelope),)*3
  keys(f)
 clips[name]=action;rig.animation_data.action=None
 tr=rig.animation_data.nla_tracks.new();tr.name=name;tr.strips.new(name,1,action);tr.mute=True
reset();scene.frame_start=1;scene.frame_end=73
select([rig,bird])
for tr in rig.animation_data.nla_tracks:tr.mute=False
props=bpy.ops.export_scene.gltf.get_rna_type().properties
assert 'NLA_TRACKS' in [v.identifier for v in props['export_animation_mode'].enum_items]
bpy.ops.export_scene.gltf(filepath=str(OUT/'park_bird.glb'),use_selection=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True,export_frame_range=False,export_anim_slide_to_zero=True)
for tr in rig.animation_data.nla_tracks:tr.mute=True
select([house]);bpy.ops.export_scene.gltf(filepath=str(OUT/'birdhouse.glb'),use_selection=True,export_animations=False)
# Independent, origin-normalized game assets and editable rig source.
rig.animation_data.action=clips['Idle'];scene.frame_set(1)
house.location=(2.4,0,0)
bpy.ops.wm.save_as_mainfile(filepath=str(SRC/'Park_Bird_Animated.blend'))
def glb_info(path):
 raw=path.read_bytes();n=struct.unpack_from('<I',raw,12)[0];d=json.loads(raw[20:20+n]);tris=sum(d['accessors'][p['indices']]['count']//3 for m in d['meshes'] for p in m['primitives']);return {'triangles':tris,'materials':len(d.get('materials',[])),'animations':{a['name']:max(d['accessors'][s['input']]['max'][0] for s in a['samplers']) for a in d.get('animations',[])},'bytes':len(raw)}
report={'bird':glb_info(OUT/'park_bird.glb'),'house':glb_info(OUT/'birdhouse.glb'),'bones':len(arm.bones),'house_scale':1.2}
assert set(report['bird']['animations'])=={'Idle','Fly_Loop','Perch','Mad_Peck','Takeoff'}
assert report['bird']['triangles']<14000
(OUT/'validation.json').write_text(json.dumps(report,indent=2));print('ASSET_REPORT',json.dumps(report),flush=True)
