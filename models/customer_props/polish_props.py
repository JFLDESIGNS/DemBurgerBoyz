import bpy, math, json, shutil
from pathlib import Path
from mathutils import Vector, Matrix
from math import sin, cos, pi
OUT=Path(r'C:\Users\joe\Desktop\burgergame\models\customer_props')
backup=OUT/'before_polish_20260913'
if not backup.exists():
 backup.mkdir();(backup/'.gdignore').write_text('')
 for f in ['customer_props.blend','manifest.json','validation.json','README.md']:
  shutil.copy2(OUT/f,backup/f)
 shutil.copytree(OUT/'glb',backup/'glb')
bpy.ops.wm.open_mainfile(filepath=str(OUT/'customer_props.blend'))
scene=bpy.data.scenes.new('Polish workshop');bpy.context.window.scene=scene
M={m.name[3:]:m for m in bpy.data.materials if m.name.startswith('CP_') and '.' not in m.name}
src=(OUT/'build_customer_props.py').read_text()
exec(src[src.index("parts=[]; assets=[]; current=''"):src.index("start('01_Open_Umbrella')")])
def mat(name,col,rough):
 m=bpy.data.materials.new('CP_'+name);m.diffuse_color=(*col,1);m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*col,1);bs.inputs['Roughness'].default_value=rough;M[name]=m
mat('polish_black',(.003,.003,.004),.42);mat('polish_glass',(.0015,.0018,.002),.14);mat('polish_rim',(.014,.015,.018),.32)
def flat(x,y,z,w,h,material):
 return mesh([(x-w/2,y,z-h/2),(x+w/2,y,z-h/2),(x+w/2,y,z+h/2),(x-w/2,y,z+h/2)],[(0,1,2,3)],material,False)
changed=[]
def replace(id,scale=2):
 old=bpy.data.objects[id];olddata=old.data
 new=finish();new.data.transform(Matrix.Diagonal((scale,scale,scale,1)))
 new.data.name=id+'_PolishedMesh'
 for ob in list(bpy.data.objects):
  if ob.type=='MESH' and ob.data==olddata:ob.data=new.data
 for child in list(new.children):bpy.data.objects.remove(child,do_unlink=True)
 bpy.data.objects.remove(new,do_unlink=True);changed.append(id)
def begin(id):start('POLISH_'+id)

# Thin black devices: flush glass, restrained bezels, physical side controls.
for id,w,h in [('11_Smartphone',.079,.166),('20_Cell_Phone',.077,.16)]:
 if id not in bpy.data.objects:
  id=next(o.name for o in bpy.data.objects if o.name.startswith('20_') and o.type=='MESH' and ' | ' not in o.name)
 begin(id)
 cube((0,0,h/2+.002),(w,.012,h),'polish_black',.007)
 cube((0,-.00615,h/2+.002),(w-.009,.0008,h-.009),'polish_glass',.004)
 flat(0,-.00661,h-.006,.019,.002,'polish_rim')
 flat(0,-.00661,.009,.021,.001,'polish_rim')
 for x,z,hh in [(-w/2,.107,.021),(w/2,.102,.018)]:cube((x,0,z),(.0016,.004,hh),'polish_rim',.0007)
 cube((-w*.23,.0065,h-.026),(.024,.002,.037),'polish_rim',.004)
 for z in [h-.018,h-.032]:
  c=cyl((-w*.23,.0083,z),.0053,.0018,'polish_black',12);c.rotation_euler[0]=pi/2
  c=cyl((-w*.23,.0093,z),.0034,.0005,'polish_glass',12);c.rotation_euler[0]=pi/2
 replace(id,2.3)

id='12_Tablet';begin(id)
cube((0,0,.137),(.185,.014,.269),'navy',.010)
cube((0,-.0073,.137),(.167,.0008,.245),'paper',.004)
flat(0,-.00775,.224,.153,.048,'teal')
for i,w in enumerate([.129,.112,.137,.092]):flat(-.071+w/2,-.0078,.178-i*.018,w,.004,'gray')
for x,c in [(-.039,'coral'),(.039,'yellow')]:flat(x,-.0078,.064,.064,.042,c)
flat(0,-.0078,.019,.029,.0015,'navy')
replace(id)

id='17_Newspaper';begin(id)
# Two panels bend gently at the spine, with ink on the paper surface.
def panel(x,y,z,w,h,material):
 ob=flat(x,0,z,w,h,material)
 for v in ob.data.vertices:v.co.y=y+abs(v.co.x)*.095
 return ob
for side in [-1,1]:
 ob=panel(side*.060,0,.145,.12,.29,'paper')
 mod=ob.modifiers.new('Paper thickness','SOLIDIFY');mod.thickness=.0015
 bpy.context.view_layer.objects.active=ob;bpy.ops.object.modifier_apply(modifier=mod.name)
 panel(side*.060,-.0016,.268,.103,.016,'navy')
 panel(side*.060,-.0016,.234,.103,.035,'gray')
 for col in [-1,1]:
  for row in range(17):
   width=.041 if row%4 else .032
   panel(side*.060+col*.026,-.0016,.207-row*.010,width,.0021,'gray')
 panel(side*.060,-.0016,.02,.1,.002,'navy')
replace(id)

id='02_Folded_Umbrella';begin(id)
# Twelve fabric folds gather at the tip; scalloped cloth hem above the hook.
v=[];f=[];profiles=[(.17,.024),(.20,.044),(.32,.041),(.48,.029),(.62,.018),(.687,.007)]
for j,(z,r) in enumerate(profiles):
 for k in range(24):
  a=k*2*pi/24;rr=r*(1 if k%2==0 else .78)
  v.append((rr*cos(a),rr*sin(a),z+(.007*(k%2) if j==0 else 0)))
for j in range(len(profiles)-1):
 for k in range(24):f.append((j*24+k,j*24+(k+1)%24,(j+1)*24+(k+1)%24,(j+1)*24+k))
mesh(v,f,'coral')
cyl((0,0,.405),.037,.024,'navy',24)
cube((0,-.038,.405),(.021,.007,.017),'navy',.004)
rod((0,0,.68),(0,0,.735),.0055,'metal',10)
tube([(0,0,.2),(0,0,.075)]+[(.035+.035*cos(pi+pi*i/16),0,.075+.035*sin(pi+pi*i/16)) for i in range(17)]+[(.07,0,.087)],.013,'navy',8)
cyl((0,0,.171),.014,.02,'gold',12)
replace(id)

id='05_Handbag';begin(id)
# Rounded tapered shell, separate lining, stitched leather flap and hardware.
n=32;v=[]
for z,w,d in [(0,.255,.112),(.025,.297,.132),(.19,.276,.114),(.22,.26,.10),(.22,.246,.086),(.028,.268,.102)]:
 for i in range(n):
  a=2*pi*i/n;v.append((w/2*math.copysign(abs(cos(a))**.35,cos(a)),d/2*math.copysign(abs(sin(a))**.35,sin(a)),z))
f=[]
for j in range(5):
 for i in range(n):f.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
f+=[tuple(reversed(range(n))),tuple(5*n+i for i in range(n))]
mesh(v,f,'coral')
cube((0,-.055,.176),(.24,.015,.076),'coral',.017)
tube([(-.108,-.064,.195),(-.108,-.067,.158),(-.098,-.067,.145),(.098,-.067,.145),(.108,-.067,.158),(.108,-.064,.195)],.0015,'tan',5)
for y in [-.037,.037]:arc_handle(y,.218,.18,.103,'brown',.010)
for x in [-.09,.09]:
 for y in [-.046,.046]:
  tube([(x+.011*cos(i*2*pi/12),y,.221+.014*sin(i*2*pi/12)) for i in range(12)],.0028,'gold',6,True)
cube((0,-.068,.161),(.034,.005,.015),'gold',.003)
replace(id)

id='09_Gift_Box';begin(id)
cube((0,0,.13),(.25,.25,.25),'pink',.006)
cube((0,0,.258),(.264,.264,.038),'coral',.006)
cube((0,0,.279),(.04,.265,.003),'cream',.001)
cube((0,0,.281),(.265,.04,.003),'cream',.001)
for y in [-.126,.126]:cube((0,y,.13),(.04,.002,.248),'cream',.0005)
for x in [-.126,.126]:cube((x,0,.13),(.002,.04,.248),'cream',.0005)
# Wide flat folded ribbon loops, not round tubing.
for side in [-1,1]:
 v=[]
 for i in range(17):
  t=2*pi*i/16;x=side*.051*(1-cos(t));z=.287+.031*sin(t)+.020*(1-cos(t))
  v.extend([(x,-.019,z),(x,.019,z)])
 ob=mesh(v,[(2*i,2*i+1,2*i+3,2*i+2) for i in range(16)],'cream')
 mod=ob.modifiers.new('Ribbon thickness','SOLIDIFY');mod.thickness=.001
 bpy.context.view_layer.objects.active=ob;bpy.ops.object.modifier_apply(modifier=mod.name)
cube((0,0,.291),(.032,.046,.022),'cream',.006)
replace(id)

# Preserve character instances, grip markers and original scene transforms.
bpy.context.window.scene=bpy.data.scenes['CUSTOMER PROPS | 30']
bpy.data.scenes.remove(scene)
for s in bpy.data.scenes:
 if s.render.engine=='CYCLES':s.cycles.samples=24
bpy.context.window.scene=bpy.data.scenes['CHARACTER PREVIEWS | Refined six']
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'customer_props.blend'))
(OUT/'polish_notes.json').write_text(json.dumps({'date':'2026-09-13','refined':changed,'preserved':'Previous sizes, vibrant palette, character poses and grip positions'},indent=2))
print('POLISH_SAVED',changed,flush=True)
exec((OUT/'finalize_props.py').read_text())
with (OUT/'README.md').open('a',encoding='utf-8') as f:
 f.write('\n## September 13 polish\nSeven props refined: both black phones, tablet, newspaper, folded umbrella, handbag and gift box. Flush device screens, flat printed graphics, pleated fabric, rounded leather and flat ribbon bows. Existing approved scale and character grip positions preserved. Run polish_props.py after rebuilding to reapply this pass. Previous delivery backed up in before_polish_20260913/.\n')
