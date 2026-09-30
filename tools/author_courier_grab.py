"""Author a two-handed courier pickup on the existing character rig in Blender.
Run Blender --background --factory-startup --python tools/author_courier_grab.py.
Then run tools/build_courier_grab.gd through Godot to bake the runtime library.
"""
import bpy, math, json, sys
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion, Euler
from math import sin, cos, pi, sqrt

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/character_animation/courier'
EXPORT = OUT
OUT.mkdir(parents=True, exist_ok=True)
EXPORT.mkdir(parents=True, exist_ok=True)
FPS = 30
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(ROOT/'assets/characters/Model/characterMedium.fbx'))
scene = bpy.context.scene
scene.name = '00 | PLAY ALL 27'
rig = next(o for o in scene.objects if o.type == 'ARMATURE')
mesh = next(o for o in scene.objects if o.type == 'MESH')
rig.name = 'Root'
rig.animation_data_clear()
bones = rig.data.bones
rest = {b.name: b.matrix_local.copy() for b in bones}
rel = {b.name: rest[b.parent.name].inverted() @ rest[b.name] if b.parent else rest[b.name] for b in bones}
order = sorted(bones, key=lambda b: len(b.parent_recursive))
active = [b.name for b in bones if b.name == 'HipsCtrl' or (b.name not in ['HipsCtrl'] and any(p.name == 'Hips' for p in b.parent_recursive)) or b.name == 'Hips']
active = [n for n in active if not n.endswith('_end')]
for p in rig.pose.bones: p.rotation_mode = 'QUATERNION'
source_signature = [{'name':b.name,'parent':b.parent.name if b.parent else None,'matrix':[list(r) for r in b.matrix_local]} for b in bones]

def smooth(x):
    x=max(0,min(1,x)); return x*x*(3-2*x)
def env(t,a=.12,b=.28,c=.72,d=.94):
    return smooth((t-a)/(b-a))*(1-smooth((t-c)/(d-c)))
def interp(t, keys):
    for (t0,v0),(t1,v1) in zip(keys, keys[1:]):
        if t <= t1:
            q=smooth((t-t0)/(t1-t0))
            if isinstance(v0,(tuple,list,Vector)): return Vector(v0).lerp(Vector(v1),q)
            return v0+(v1-v0)*q
    return Vector(keys[-1][1]) if isinstance(keys[-1][1],(tuple,list,Vector)) else keys[-1][1]
def rad(x):return math.radians(x)
def Q(x=0,y=0,z=0):return Euler(tuple(map(rad,(x,y,z))),'XYZ').to_quaternion()

# Analytic IK creates ordinary baked bone transforms, without runtime constraints.
class Pose:
    def __init__(self):
        self.basis={n:Matrix.Identity(4) for n in rest}
        self.world={}
        self.update()
    def update(self):
        for b in order:
            self.world[b.name]=(self.world[b.parent.name] if b.parent else Matrix.Identity(4)) @ rel[b.name] @ self.basis[b.name]
    def rotate(self,n,x=0,y=0,z=0):
        r=rest[n].to_quaternion()
        self.basis[n]=(r.inverted() @ Q(x,y,z) @ r).to_matrix().to_4x4()
        self.update()
    def pelvis(self,offset,rotation):
        self.rotate('Hips',*rotation)
        base=self.world[bones['Hips'].parent.name] @ rel['Hips']
        self.basis['Hips'].translation=base.to_quaternion().inverted() @ Vector(offset)
        self.update()
    def root(self,offset,yaw):
        center=rest['HipsCtrl'].translation
        target=Matrix.Translation(center+Vector(offset)) @ Q(z=yaw).to_matrix().to_4x4() @ rest['HipsCtrl'].to_quaternion().to_matrix().to_4x4()
        self.basis['HipsCtrl']=rest['HipsCtrl'].inverted() @ target
        self.update()
    def global_rot(self,n,quat):
        p=bones[n].parent
        base=(self.world[p.name] if p else Matrix.Identity(4)) @ rel[n]
        self.basis[n]=(base.to_quaternion().inverted() @ quat).to_matrix().to_4x4()
        self.update()
    @staticmethod
    def frame(direction,normal):
        y=Vector(direction).normalized()
        x=(Vector(normal)-y*Vector(normal).dot(y)).normalized()
        z=x.cross(y).normalized()
        return Matrix((x,y,z)).transposed()
    def orient_hinge(self,n,direction,normal,rest_normal):
        rest_direction=rest[n].to_quaternion() @ Vector((0,1,0))
        transport=self.frame(direction,normal) @ self.frame(rest_direction,rest_normal).transposed()
        self.global_rot(n,transport.to_quaternion() @ rest[n].to_quaternion())
    def wrist_swing(self,n,direction,weight=1):
        # Swing from the inherited forearm orientation, NEVER from world rest.
        # This leaves axial wrist twist at zero even during raised-arm gestures.
        inherited=self.world[n].to_quaternion()
        forward=inherited @ Vector((0,1,0))
        swing=forward.rotation_difference(Vector(direction).normalized())
        angle=swing.angle
        if angle>rad(55):swing=Quaternion(swing.axis,rad(55))
        swing=Quaternion().slerp(swing,weight)
        self.global_rot(n,swing @ inherited)
    def limb(self,upper,lower,tip,target,pole,tipq=None):
        h=self.world[upper].translation.copy()
        target=Vector(target); delta=target-h
        r1=rest[lower].translation-rest[upper].translation
        r2=rest[tip].translation-rest[lower].translation
        l1=r1.length;l2=r2.length
        dist=min(max(delta.length,.05),l1+l2-.005)
        direction=delta.normalized()
        pole=Vector(pole)-h
        side=pole-direction*pole.dot(direction)
        if side.length<.001:raise ValueError('Degenerate limb pole: '+upper)
        side.normalize()
        along=(l1*l1-l2*l2+dist*dist)/(2*dist)
        elbow=h+direction*along+side*sqrt(max(0,l1*l1-along*along))
        normal=side.cross(direction).normalized()
        rest_normal=r1.cross(r2).normalized()
        # Upper/lower share one hinge normal. This preserves anatomical roll,
        # unlike independently choosing shortest rotations for each segment.
        self.orient_hinge(upper,elbow-h,normal,rest_normal)
        self.orient_hinge(lower,h+direction*dist-elbow,normal,rest_normal)
        if tipq:self.global_rot(tip,tipq)
    def key(self,action,frame):
        for n in active:
            p=rig.pose.bones[n]
            p.matrix_basis=self.basis[n]
            # Keep adjacent quaternion samples in the same hemisphere.
            if n in lastq and p.rotation_quaternion.dot(lastq[n])<0: p.rotation_quaternion.negate()
            lastq[n]=p.rotation_quaternion.copy()
            p.keyframe_insert('rotation_quaternion',frame=frame,group=n)
            if n in ('HipsCtrl','Hips'): p.keyframe_insert('location',frame=frame,group=n)


scene.name='Courier / Reach, grasp, lift'
scene.render.fps=FPS;scene.frame_start=1;scene.frame_end=34
act=bpy.data.actions.new('Courier_Grab');rig.animation_data_create();rig.animation_data.action=act
lastq={}
for f in range(1,35):
 t=(f-1)/33
 reach=smooth(t/.45);lift=smooth((t-.49)/.45)
 p=Pose()
 p.root((0,-.04*env(t,.0,.25,.60,.95),-.035),0)
 p.rotate('Spine',7*env(t,.0,.25,.60,.95),0,0)
 p.rotate('Head',8*env(t,.05,.28,.62,.98),0,0)
 for side,sign in [('Left',1),('Right',-1)]:
  home=Vector((sign*.58,-.10,1.50))
  grasp=Vector((sign*.23,-.96,1.79))
  carry=Vector((sign*.23,-.63,1.98))
  target=home.lerp(grasp,reach).lerp(carry,lift)
  p.limb(side+'Arm',side+'ForeArm',side+'Hand',target,(sign*.91,.15,1.9))
  p.wrist_swing(side+'Hand',(-sign*.3,-.75,-.05),reach)
  for j,deg in [(1,42),(2,58),(3,40)]:
   bn=side+'HandIndex'+str(j);fwd=rest[bn].to_quaternion() @ Vector((0,1,0))
   axis=rest[bn].to_quaternion().inverted() @ fwd.cross(Vector((0,0,-1))).normalized()
   p.basis[bn]=Quaternion(axis,rad(deg*smooth((t-.34)/.15))).to_matrix().to_4x4()
  p.update()
 p.key(act,f)
scene.frame_set(16)
(OUT/'.gdignore').write_text('')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Courier_Pickup.blend'))
frames=[]
for f in range(1,35):
 scene.frame_set(f)
 frames.append({'time':(f-1)/30,'bones':{b.name:[list(r) for r in b.matrix] for b in rig.pose.bones}})
motion={'fps':30,'rest':{b.name:[list(r) for r in b.matrix_local] for b in bones},'clips':[{'name':'Courier_Grab','length':1.1,'loop':False,'prop':'','frames':frames}]}
(OUT/'grab_motion.json').write_text(json.dumps(motion,separators=(',',':')))
print('COURIER_GRAB_AUTHORED_IN_BLENDER',flush=True)
