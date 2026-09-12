import bpy
bpy.ops.wm.read_factory_settings(use_empty=True)
import bpy, math, json, os
from pathlib import Path
from mathutils import Vector
from math import sin, cos, pi
OUT=Path(r'C:\Users\joe\Desktop\burgergame\models\customer_props')
OUT.mkdir(exist_ok=True)
(OUT/'glb').mkdir(exist_ok=True)
scene=bpy.data.scenes.new('CUSTOMER PROPS | 30')
bpy.context.window.scene=scene
scene.unit_settings.system='METRIC'
scene.unit_settings.scale_length=1
M={}
def material(name,color,rough=.65,metal=0):
 m=bpy.data.materials.new('CP_'+name); m.diffuse_color=(*color,1); m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF'); bs.inputs['Base Color'].default_value=(*color,1); bs.inputs['Roughness'].default_value=rough; bs.inputs['Metallic'].default_value=metal
 M[name]=m; return m
for n,c in {'navy':(.035,.07,.115),'teal':(.025,.42,.43),'mint':(.32,.73,.60),'coral':(.95,.23,.16),'yellow':(1,.64,.09),'cream':(.95,.86,.67),'paper':(.93,.94,.88),'tan':(.57,.31,.14),'brown':(.23,.105,.055),'pink':(.87,.27,.43),'purple':(.37,.24,.58),'blue':(.065,.30,.65),'green':(.12,.36,.16),'black':(.018,.026,.035),'gray':(.29,.37,.40),'screen':(.065,.55,.67)}.items(): material(n,c)
material('metal',(.48,.57,.61),.3,.55)
material('gold',(.8,.48,.12),.35,.45)
parts=[]; assets=[]; current=''
def reg(o,mat,smooth=True):
 o.name=current+'_'+o.name; o.data.materials.append(M[mat])
 if o.type=='MESH':
  for p in o.data.polygons:p.use_smooth=smooth
 parts.append(o); return o
def cube(loc,scale,mat,bev=.015):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc); o=bpy.context.object; o.dimensions=scale
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 reg(o,mat,False)
 if bev:
  b=o.modifiers.new('Soft edges','BEVEL'); b.width=bev; b.segments=2
  bpy.context.view_layer.objects.active=o; bpy.ops.object.modifier_apply(modifier=b.name)
  for p in o.data.polygons:p.use_smooth=True
  w=o.modifiers.new('Weighted normals','WEIGHTED_NORMAL'); w.keep_sharp=True; w.weight=50
  bpy.ops.object.modifier_apply(modifier=w.name)
 return o
def uv(loc,scale,mat,seg=16,rings=8):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=seg,ring_count=rings,radius=1,location=loc); o=bpy.context.object; o.scale=scale; return reg(o,mat)
def cyl(loc,r,depth,mat,n=16,r2=None):
 bpy.ops.mesh.primitive_cone_add(vertices=n,radius1=r,radius2=r if r2 is None else r2,depth=depth,location=loc)
 o=reg(bpy.context.object,mat)
 for p in o.data.polygons:p.use_smooth=len(p.vertices)==4
 return o
def rod(a,b,r,mat,n=8):
 a,b=Vector(a),Vector(b); o=cyl((a+b)/2,r,(b-a).length,mat,n); o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o
def tube(points,r,mat,n=6,closed=False):
 pts=[Vector(p) for p in points]; verts=[]; faces=[]
 for i,p in enumerate(pts):
  t=(pts[(i+1)%len(pts)]-pts[i-1] if closed else pts[min(i+1,len(pts)-1)]-pts[max(i-1,0)]).normalized()
  ref=Vector((0,1,0)) if abs(t.y)<.9 else Vector((1,0,0))
  u=t.cross(ref).normalized();v=t.cross(u)
  verts += [p+r*(cos(j*2*pi/n)*u+sin(j*2*pi/n)*v) for j in range(n)]
 for i in range(len(pts) if closed else len(pts)-1):
  for j in range(n):faces.append((i*n+j,i*n+(j+1)%n,((i+1)%len(pts))*n+(j+1)%n,((i+1)%len(pts))*n+j))
 if not closed:faces.extend([tuple(reversed(range(n))),tuple((len(pts)-1)*n+j for j in range(n))])
 return mesh(verts,faces,mat)
def mesh(v,f,mat,smooth=True):
 me=bpy.data.meshes.new(current+'_geometry');me.from_pydata(v,[],f);me.update()
 o=bpy.data.objects.new(current+'_part',me);scene.collection.objects.link(o);return reg(o,mat,smooth)
def arc_handle(y,z,w,h,mat='brown',r=.012):
 return tube([(w*.5*cos(pi*i/12),y,z+h*sin(pi*i/12)) for i in range(13)],r,mat,8)
def start(name):
 global parts,current
 parts=[];current=name
def finish(grip=(0,0,.15)):
 bpy.ops.object.select_all(action='DESELECT')
 for o in parts:o.select_set(True)
 bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.convert(target='MESH');bpy.ops.object.join()
 o=bpy.context.object;o.name=current
 scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
 bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
 o['prop_id']=current;o['units']='meters';o['grip_blender_xyz']=list(grip)
 marker=bpy.data.objects.new('GripPoint',None);scene.collection.objects.link(marker);marker.parent=o;marker.location=grip;marker.empty_display_size=.025;marker.hide_render=True
 o.data.calc_loop_triangles()
 assets.append({'object':o,'grip':marker,'name':current,'triangles':len(o.data.loop_triangles),'dimensions':list(o.dimensions)})
 return o
def shellbag(w,d,h,mat):
 # Actual hollow tapered bag, inner liner and closed bottom.
 v=[]
 for z,ww,dd in [(0,w,d),(h,w*.92,d*.9),(h,w*.92-.012,d*.9-.012),(.012,w-.012,d-.012)]:
  v.extend([(-ww/2,-dd/2,z),(ww/2,-dd/2,z),(ww/2,dd/2,z),(-ww/2,dd/2,z)])
 f=[]
 for k in range(3):
  for j in range(4):f.append((k*4+j,k*4+(j+1)%4,(k+1)*4+(j+1)%4,(k+1)*4+j))
 f.extend([(3,2,1,0),(12,13,14,15)])
 mesh(v,f,mat,False)
def badge(x,y,z,w,h,mat='gold'):
 cube((x,y,z),(w,.008,h),mat,0 if h<.009 else .004)

start('01_Open_Umbrella')
# Eight individually curved panels with scalloped, piped edges.
R=.56
def canopy(r,a):
 local=(a%(pi/4))/(pi/4)
 scallop=.022*sin(pi*local)*(r/R)**4
 return (r*cos(a),r*sin(a),.95-.245*(r/R)**1.65+scallop)
for panel in range(8):
 v=[];f=[];nr=6;na=6
 for j in range(nr+1):
  r=.009+(R-.009)*j/nr
  for k in range(na+1):v.append(canopy(r,(panel+k/na)*pi/4))
 for j in range(nr):
  for k in range(na):
   q=j*(na+1)+k;f.append((q,q+1,q+na+2,q+na+1))
 o=mesh(v,f,'teal' if panel%2==0 else 'mint')
 sol=o.modifiers.new('Fabric thickness','SOLIDIFY');sol.thickness=.002;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=sol.name)
 a=panel*pi/4
 tube([canopy(R*j/8,a) for j in range(9)],.0028,'cream')
 tube([canopy(R,(panel+k/12)*pi/4) for k in range(13)],.003,'teal')
 rib=[(x,y,z-.009) for x,y,z in [canopy(R*j/8,a) for j in range(9)]]
 tube(rib,.0035,'metal')
 dest=canopy(R*.64,a);rod((0,0,.59),(dest[0],dest[1],dest[2]-.015),.0038,'metal')
 uv(canopy(R,a),(.009,.009,.009),'metal',8,4)
rod((0,0,.14),(0,0,.985),.008,'metal',12)
cyl((0,0,.6),.016,.07,'navy',12)
uv((0,0,.984),(.015,.015,.028),'navy',12,6)
tube([(0,0,.22),(0,0,.12)]+[(.046+.046*cos(pi+pi*i/16),0,.12+.046*sin(pi+pi*i/16)) for i in range(17)]+[(.092,0,.145)],.015,'brown',10)
finish((0,0,.2))

start('02_Folded_Umbrella')
cyl((0,0,.43),.042,.53,'coral',12,r2=.013)
for i in range(6):
 a=i*pi/3;rod((.038*cos(a),.038*sin(a),.18),(.013*cos(a),.013*sin(a),.68),.0025,'pink',6)
cyl((0,0,.4),.043,.035,'navy',12)
rod((0,0,.68),(0,0,.735),.006,'metal')
tube([(0,0,.2),(0,0,.075)]+[(.035+.035*cos(pi+pi*i/12),0,.075+.035*sin(pi+pi*i/12)) for i in range(13)],.013,'navy',8)
finish((0,0,.13))

start('03_Roller_Suitcase')
cube((0,0,.34),(.38,.22,.54),'teal',.038)
cube((0,-.118,.34),(.325,.025,.46),'mint',.025)
for x in [-.115,-.057,0,.057,.115]:cube((x,-.136,.34),(.017,.018,.365),'teal',.008)
for x in [-.13,.13]:
 for y in [-.065,.065]:
  wh=cyl((x,y,.043),.037,.026,'navy',12);wh.rotation_euler[0]=pi/2
for x in [-.087,.087]:rod((x,.05,.60),(x,.05,.84),.009,'metal')
cube((0,.05,.84),(.205,.034,.032),'navy',.012)
arc_handle(-.015,.595,.12,.035,'navy',.012)
badge(.105,-.154,.19,.045,.06)
finish((0,.05,.84))

start('04_Briefcase')
cube((0,0,.155),(.40,.11,.29),'brown',.024)
cube((0,-.059,.2),(.39,.012,.175),'tan',.012)
arc_handle(0,.293,.135,.05,'brown',.013)
for x in [-.13,.13]:
 badge(x,-.072,.165,.032,.045)
 cube((x,0,.012),(.018,.112,.016),'gold',.003)
finish((0,0,.34))

start('05_Handbag')
shellbag(.30,.125,.22,'coral')
cube((0,-.061,.168),(.282,.018,.095),'pink',.025)
for y in [-.043,.043]:arc_handle(y,.215,.18,.11,'brown',.011)
badge(0,-.075,.145,.047,.023)
for x in [-.09,.09]:
 for y in [-.052,.052]:uv((x,y,.225),(.012,.009,.014),'gold',8,4)
finish((0,0,.32))

start('06_Shopping_Bag')
shellbag(.28,.13,.34,'mint')
for y in [-.053,.053]:arc_handle(y,.33,.135,.105,'cream',.006)
badge(0,-.068,.19,.12,.09,'cream')
badge(0,-.075,.19,.055,.012,'teal')
finish((0,0,.43))

start('07_Backpack')
cube((0,0,.215),(.29,.17,.40),'yellow',.06)
cube((0,-.106,.125),(.235,.064,.155),'tan',.03)
cube((0,-.141,.173),(.195,.008,.011),'cream',.003)
badge(.065,-.149,.16,.012,.033,'gold')
tube([(-.12,-.033,.31),(-.115,-.078,.374),(0,-.082,.409),(.115,-.078,.374),(.12,-.033,.31)],.004,'brown')
for x in [-.085,.085]:
 tube([(x,.07,.355),(x,.145,.315),(x,.155,.12),(x,.07,.06)],.016,'brown',8)
arc_handle(.025,.404,.1,.046,'brown',.009)
badge(0,-.089,.29,.065,.035,'cream')
finish((0,.025,.445))

start('08_Duffel_Bag')
cube((0,0,.135),(.47,.24,.25),'blue',.065)
for x in [-.15,.15]:
 cube((x,0,.258),(.025,.17,.012),'cream',.004)
 cube((x,-.119,.15),(.025,.013,.19),'cream',.004)
for y in [-.07,.07]:arc_handle(y,.255,.30,.11,'navy',.012)
tube([(-.2,0,.258),(0,0,.272),(.2,0,.258)],.004,'navy')
badge(.19,-.122,.16,.035,.024,'gold')
finish((0,0,.36))

start('09_Gift_Box')
cube((0,0,.13),(.25,.25,.25),'pink',.012)
cube((0,0,.255),(.264,.264,.045),'coral',.012)
cube((0,0,.28),(.04,.27,.008),'cream',.002)
cube((0,0,.281),(.27,.04,.008),'cream',.002)
for x in [-.126,.126]:cube((x,0,.13),(.005,.04,.25),'cream',.001)
for s in [-1,1]:
 tube([(0,0,.289),(s*.05,-.024,.344),(s*.092,0,.329),(s*.06,.027,.29),(0,0,.289)],.008,'cream',6)
uv((0,0,.292),(.017,.016,.013),'yellow',12,6)
finish((0,0,.13))

start('10_Parcel')
cube((0,0,.13),(.34,.25,.26),'tan',.01)
cube((0,0,.263),(.062,.252,.008),'cream',.001)
cube((0,-.126,.18),(.062,.006,.16),'cream',.001)
badge(-.09,-.131,.145,.088,.06,'paper')
for j in range(4):badge(-.09,-.137,.13+j*.012,.059,.004,'gray')
finish((0,0,.13))

start('11_Smartphone')
cube((0,0,.085),(.079,.012,.166),'navy',.009)
cube((0,-.007,.085),(.068,.003,.146),'screen',.006)
cube((0,-.009,.146),(.026,.002,.005),'navy',.002)
for j,c in enumerate(['cream','mint','yellow']):badge(-.02+j*.02,-.01,.039,.012,.012,c)
badge(0,-.01,.09,.049,.033,'blue')
badge(-.009,-.011,.119,.03,.004,'paper')
cube((.041,0,.114),(.004,.007,.023),'metal',.002)
finish((0,0,.065))

start('12_Tablet')
cube((0,0,.137),(.185,.014,.269),'navy',.012)
cube((0,-.008,.14),(.163,.003,.235),'cream',.007)
badge(0,-.011,.217,.137,.056,'teal')
for j,w in enumerate([.115,.13,.105,.12]):badge(-.007,-.012,.167-j*.018,w,.006,'tan')
for x,c in [(-.042,'coral'),(.042,'mint')]:badge(x,-.012,.062,.06,.052,c)
finish((0,0,.12))

start('13_Headphones')
tube([(.087*cos(pi*i/20),0,.115+.105*sin(pi*i/20)) for i in range(21)],.014,'navy',8)
tube([(.087*cos(pi*i/16),-.005,.11+.096*sin(pi*i/16)) for i in range(17)],.010,'tan',8)
for s in [-1,1]:
 o=cyl((s*.087,0,.087),.047,.028,'teal',16);o.rotation_euler[1]=pi/2
 o=cyl((s*.070,0,.087),.04,.016,'navy',16);o.rotation_euler[1]=pi/2
 cube((s*.089,0,.14),(.015,.025,.043),'metal',.005)
finish((0,0,.21))

start('14_Camera')
cube((0,0,.075),(.18,.065,.125),'teal',.018)
cube((-.058,-.037,.075),(.042,.017,.103),'navy',.012)
lens=cyl((.017,-.060,.078),.043,.065,'navy',20);lens.rotation_euler[0]=pi/2
lens=cyl((.017,-.095,.078),.034,.008,'metal',20);lens.rotation_euler[0]=pi/2
lens=cyl((.017,-.100,.078),.027,.005,'blue',20);lens.rotation_euler[0]=pi/2
lens=cyl((.017,-.103,.078),.016,.005,'navy',16);lens.rotation_euler[0]=pi/2
cube((.018,0,.15),(.062,.046,.024),'navy',.006)
badge(.065,-.038,.112,.026,.015,'cream')
cyl((-.059,0,.142),.012,.008,'coral',12)
finish((-.06,0,.085))

start('15_Book')
cube((0,0,.13),(.17,.045,.25),'paper',.004)
for y in [-.027,.027]:cube((0,y,.13),(.183,.008,.265),'blue',.005)
cube((-.091,0,.13),(.014,.06,.26),'teal',.006)
badge(.01,-.034,.163,.103,.093,'cream')
badge(.01,-.04,.174,.069,.009,'teal')
badge(.01,-.04,.15,.051,.006,'tan')
for z in [.04,.06,.09,.12,.17,.20]:cube((.086,0,z),(.002,.041,.0015),'tan',0)
cube((.035,0,.012),(.018,.005,.048),'coral',.001)
finish((0,0,.13))

start('16_Notebook_Pen')
cube((0,0,.11),(.145,.025,.21),'paper',.004)
for y in [-.018,.018]:cube((0,y,.11),(.16,.008,.225),'yellow',.004)
for j in range(7):
 z=.03+j*.026
 tube([(-.076+.012*cos(2*pi*k/12),.026*sin(2*pi*k/12),z) for k in range(12)],.0025,'metal',6,True)
badge(.01,-.025,.15,.085,.036,'cream')
rod((.063,-.034,.035),(.063,-.034,.192),.005,'navy',10)
cyl((.063,-.034,.029),.001,.015,'metal',8,r2=.005)
cube((.069,-.035,.17),(.003,.005,.032),'gold',.001)
finish((0,0,.1))

start('17_Newspaper')
cube((0,0,.145),(.24,.011,.29),'paper',.003)
badge(0,-.008,.252,.204,.022,'navy')
for x in [-.063,.057]:
 for j in range(12):badge(x,-.01,.21-j*.013,.083 if j%3 else .063,.003,'gray')
badge(-.063,-.014,.172,.081,.057,'gray')
badge(-.063,-.019,.173,.068,.042,'cream')
tube([(-.119,.006,.006),(-.124,-.001,.145),(-.119,.006,.29)],.003,'cream')
finish((0,0,.09))

start('18_Wallet')
cube((0,0,.045),(.116,.022,.084),'brown',.01)
cube((0,-.013,.045),(.109,.006,.075),'tan',.008)
cube((.04,-.020,.045),(.029,.012,.03),'brown',.005)
uv((.04,-.027,.045),(.005,.002,.005),'gold',8,4)
cube((-.021,.003,.092),(.05,.003,.018),'mint',.001)
cube((-.021,-.001,.093),(.034,.002,.016),'cream',.001)
finish((0,0,.045))

start('19_Keys')
tube([(.029*cos(2*pi*i/20),0,.13+.029*sin(2*pi*i/20)) for i in range(20)],.0025,'metal',6,True)
for x,z,ang,mat in [(-.016,.086,-.2,'gold'),(.012,.079,.23,'metal')]:
 tube([(x+.014*cos(2*pi*i/12),0,z+.014*sin(2*pi*i/12)) for i in range(12)],.004,mat,6,True)
 rod((x,0,z-.01),(x+.015*ang,0,.019),.005,mat)
 for zz in [.023,.037]:cube((x+.007,0,zz),(.016,.008,.007),mat,.001)
cube((.041,.003,.081),(.035,.013,.05),'coral',.008)
tube([(.022,0,.109),(.04,0,.113),(.041,0,.103)],.002,'metal')
finish((0,0,.15))

start('20_Sunglasses')
for x in [-.038,.038]:
 cube((x,0,.032),(.061,.012,.045),'navy',.013)
 cube((x,-.007,.032),(.049,.004,.033),'blue',.01)
tube([(-.013,0,.04),(0,-.002,.044),(.013,0,.04)],.004,'gold')
for s in [-1,1]:
 tube([(s*.067,0,.044),(s*.074,.08,.046),(s*.069,.112,.029)],.004,'navy',6)
finish((0,0,.04))

def lathe(profile,mat,n=20):
 v=[(r*cos(i*2*pi/n),r*sin(i*2*pi/n),z) for r,z in profile for i in range(n)]
 f=[]
 for j in range(len(profile)-1):
  for i in range(n):
   q=j*n+i;k=j*n+(i+1)%n;f.append((q,k,k+n,q+n))
 f.extend([tuple(reversed(range(n))),tuple((len(profile)-1)*n+i for i in range(n))])
 return mesh(v,f,mat)
start('21_Water_Bottle')
lathe([(.031,0),(.039,.012),(.041,.04),(.037,.17),(.027,.197),(.02,.203),(.02,.22)],'blue',16)
cyl((0,0,.225),.024,.028,'navy',16)
cyl((0,0,.1),.041,.065,'mint',16,r2=.039)
badge(0,-.042,.1,.031,.025,'paper')
tube([(.024,0,.23),(.04,0,.247),(.025,0,.264),(0,0,.249)],.004,'navy',6)
finish((0,0,.115))

start('22_Thermos')
lathe([(.034,0),(.038,.006),(.038,.245),(.032,.256)],'cream',20)
cyl((0,0,.012),.039,.019,'navy',20)
cyl((0,0,.245),.039,.055,'teal',20)
cyl((0,0,.216),.0395,.008,'metal',20)
badge(0,-.039,.134,.022,.06,'teal')
finish((0,0,.13))

start('23_Flower_Bouquet')
# Open paper cone surrounding seven individual stems and soft low-poly blossoms.
lathe([(.024,.045),(.029,.04),(.108,.245),(.101,.245),(.023,.06)],'cream',12)
for j in range(7):
 a=j*2*pi/6;r=.062 if j<6 else 0
 x,y=r*cos(a),r*sin(a);z=.31+(j%3)*.015
 rod((0,0,0),(x,y,z),.004,'green')
 uv((x*.75+.016,y*.7,.21),(.023,.009,.055),'mint',8,4)
 for k in range(5):
  aa=k*2*pi/5
  uv((x+.022*cos(aa),y+.022*sin(aa),z),(.022,.022,.017),'pink' if j%2 else 'coral',8,4)
 uv((x,y,z+.012),(.012,.012,.011),'yellow',8,4)
cyl((0,0,.11),.045,.016,'teal',12,r2=.053)
for s in [-1,1]:tube([(0,-.05,.115),(s*.035,-.056,.133),(s*.04,-.056,.11),(0,-.05,.115)],.005,'teal')
finish((0,0,.10))

start('24_Basketball')
uv((0,0,.12),(.12,.12,.12),'coral',24,12)
for axis in range(3):
 pts=[]
 for i in range(48):
  a=2*pi*i/48;c=.1202*cos(a);s=.1202*sin(a)
  pts.append((c,s,.12) if axis==0 else ((c,0,.12+s) if axis==1 else (0,c,.12+s)))
 tube(pts,.0019,'brown',4,True)
finish((0,0,.12))

start('25_Skateboard')
# Solid deck with gently raised ends.
v=[];f=[]
xs=[-.34,-.31,-.25,.25,.31,.34]
for zoff in [0,.012]:
 for x in xs:
  w=.066 if abs(x)>.32 else .09
  z=.075+max(0,abs(x)-.25)*.3+zoff
  v.extend([(x,-w,z),(x,w,z)])
for j in range(5):
 f.extend([(2*j,2*j+2,2*j+3,2*j+1),(12+2*j,13+2*j,15+2*j,14+2*j)])
for j in range(5):
 f.extend([(2*j,12+2*j,14+2*j,2*j+2),(2*j+1,2*j+3,15+2*j,13+2*j)])
f.extend([(0,1,13,12),(10,22,23,11)])
mesh(v,f,'tan',False)
cube((0,0,.09),(.48,.168,.005),'teal',.016)
cube((0,0,.094),(.10,.165,.004),'cream',.001)
for x in [-.215,.215]:
 rod((x,-.101,.042),(x,.101,.042),.009,'metal')
 cube((x,0,.06),(.055,.056,.033),'metal',.006)
 for y in [-.103,.103]:
  o=cyl((x,y,.035),.033,.028,'yellow',12);o.rotation_euler[0]=pi/2
  o=cyl((x,y*1.145,.035),.013,.002,'navy',12);o.rotation_euler[0]=pi/2
finish((0,0,.085))

start('26_Walking_Cane')
rod((0,0,.019),(0,0,.78),.011,'brown',12)
cyl((0,0,.023),.018,.035,'navy',12)
tube([(0,0,.75),(0,0,.80)]+[(.047+.047*cos(pi-pi*i/16),0,.80+.047*sin(pi-pi*i/16)) for i in range(17)],.014,'tan',10)
cyl((0,0,.746),.013,.024,'gold',12)
finish((.043,0,.845))

start('27_Takeaway_Coffee')
lathe([(.028,0),(.03,.009),(.043,.116),(.045,.122)],'paper',20)
cyl((0,0,.06),.037,.043,'tan',20,r2=.041)
lathe([(.046,.117),(.048,.122),(.048,.129),(.042,.133),(.041,.143),(.033,.147)],'navy',20)
cube((0,-.019,.149),(.016,.008,.003),'black',.003)
badge(0,-.042,.066,.022,.023,'cream')
finish((0,0,.068))

start('28_Soda_Cup')
lathe([(.035,0),(.038,.015),(.05,.147),(.052,.16)],'cream',20)
cyl((0,0,.079),.043,.059,'coral',20,r2=.048)
cyl((0,0,.163),.055,.009,'paper',20)
cyl((0,0,.169),.05,.006,'paper',20)
tube([(0,0,.17),(0,0,.225),(.018,0,.244),(.019,0,.264)],.0045,'coral',8)
badge(0,-.048,.082,.035,.022,'cream')
finish((0,0,.08))

start('29_Takeaway_Bag')
shellbag(.19,.115,.265,'tan')
cube((0,0,.265),(.19,.10,.008),'tan',.003)
cube((0,-.021,.275),(.19,.067,.023),'cream',.005)
badge(0,-.061,.145,.086,.062,'coral')
badge(0,-.067,.153,.05,.012,'cream')
badge(0,-.068,.133,.037,.005,'yellow')
for x in [-.086,.086]:rod((x,-.058,.018),(x,-.052,.248),.0018,'brown',4)
finish((0,0,.245))

start('30_Burger_Box')
cube((0,0,.037),(.165,.15,.068),'cream',.014)
cube((0,0,.083),(.175,.16,.031),'coral',.012)
cube((0,-.080,.06),(.038,.015,.022),'coral',.004)
cube((0,0,.101),(.075,.06,.005),'cream',.009)
# Tiny graphic made from three solid strips.
cube((0,-.002,.105),(.045,.03,.005),'yellow',.009)
cube((0,.01,.108),(.045,.008,.003),'brown',.002)
finish((0,0,.05))

# Resolve outward normals and export one material-ready mesh + GripPoint per file.
import bmesh
manifest=[]
for a in assets:
 o=a['object']
 bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
 bpy.ops.object.select_all(action='DESELECT')
 old=bpy.data.objects.get('GripPoint')
 if old and old!=a['grip']:old.name=old.parent.name+'_GripPoint'
 a['grip'].name='GripPoint'
 o.select_set(True);a['grip'].select_set(True);bpy.context.view_layer.objects.active=o
 bpy.ops.export_scene.gltf(filepath=str(OUT/'glb'/(a['name']+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_extras=True,export_apply=True)
 manifest.append({'id':a['name'],'file':'glb/'+a['name']+'.glb','triangles':a['triangles'],'size_m_blender_xyz':a['dimensions'],'grip_godot_xyz':[a['grip'].location.x,a['grip'].location.z,-a['grip'].location.y]})
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
# Catalog display is normalized for readability; GLBs above retain their meter scale.
catalog=bpy.data.collections.new('30 PROPS | display sizes');scene.collection.children.link(catalog)
stage=bpy.data.collections.new('PRESENTATION | not exported');scene.collection.children.link(stage)
for idx,a in enumerate(assets):
 o=a['object']; g=a['grip']
 for ob in [o,g]:
  for c in list(ob.users_collection):c.objects.unlink(ob)
  catalog.objects.link(ob)
 c=idx%6;r=idx//6
 dims=a['dimensions'];sc=min(1.08/max(dims),3.8)
 o.scale=(sc,)*3;o.location=((c-2.5)*1.65,(2-r)*1.67,.12)
 o['presentation_scale']=sc
 a['grip'].hide_set(True)
def stage_obj(o):
 for c in list(o.users_collection):c.objects.unlink(o)
 stage.objects.link(o)
 return o
material('stage',(.025,.048,.072))
material('tile',(.045,.083,.11))
material('type',(.83,.9,.86))
material('muted',(.34,.55,.59))
current='DISPLAY';parts=[]
for idx,a in enumerate(assets):
 x=(idx%6-2.5)*1.65;y=(2-idx//6)*1.67
 stage_obj(cube((x,y,.034),(1.52,1.54,.10),'tile',.035))
def text_obj(body,loc,size,mat,align='LEFT'):
 cu=bpy.data.curves.new('Catalog type','FONT');cu.body=body;cu.size=size;cu.extrude=0;cu.align_x=align
 ob=bpy.data.objects.new(body,cu);stage.objects.link(ob);ob.location=loc;cu.materials.append(M[mat]);return ob
for idx,a in enumerate(assets):
 x=(idx%6-2.5)*1.65;y=(2-idx//6)*1.67
 label=a['name'][3:].replace('_',' ').upper()
 text_obj(str(idx+1).zfill(2),(x-.66,y-.638,.09),.102,'mint')
 text_obj(label,(x-.44,y-.635,.09),.083,'type')
text_obj('EVERYDAY / CUSTOMER PROPS',(-4.88,4.64,.03),.37,'type')
text_obj('30 ORIGINAL ASSETS     /     SIMPLE MATERIALS     /     SOFT LOW-POLY',(-4.86,4.27,.03),.125,'muted')
text_obj('26 EVERYDAY OBJECTS + 4 TAKEAWAY ITEMS',(-4.85,-4.40,.03),.125,'mint')
text_obj('DISPLAY SIZES NORMALIZED   /   EXPORTS IN METERS',(4.85,-4.40,.03),.105,'muted','RIGHT')
stage_obj(cube((0,0,-.105),(200,200,.15),'stage',0))
world=bpy.data.worlds.new('CP Studio World');world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.22,.30,.4,1);world.node_tree.nodes['Background'].inputs[1].default_value=.45;scene.world=world
def area(name,loc,power,size,col):
 data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size;data.color=col
 ob=bpy.data.objects.new(name,data);stage.objects.link(ob);ob.location=loc;ob.rotation_euler=(Vector((0,0,0))-ob.location).to_track_quat('-Z','Y').to_euler()
area('Large warm key',(-4,-4,9),1800,8,(1,.87,.73))
area('Soft cool fill',(5,2,7),1400,7,(.63,.83,1))
area('Back rim',(-2,6,6),1000,5,(.79,1,.94))
camd=bpy.data.cameras.new('Catalog Camera');cam=bpy.data.objects.new('Catalog Camera',camd);stage.objects.link(cam)
cam.location=(0,-9.3,16);target=Vector((0,.2,0));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();camd.type='ORTHO';camd.ortho_scale=11.7;scene.camera=cam
scene.render.engine='CYCLES';scene.cycles.samples=32
scene.cycles.use_denoising=True
scene.render.resolution_x=1800;scene.render.resolution_y=1575;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
scene.render.image_settings.file_format='PNG'
scene.render.filepath=str(OUT/'customer_props_preview.png')
# Save only this scene and its dependencies, leaving the pre-existing workspace intact.
bpy.context.window.scene=scene
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'customer_props.blend'),compress=True)
print('EXPORTED',len(manifest),'GLBs;',sum(a['triangles'] for a in assets),'total triangles')

bpy.ops.render.render(write_still=True)
print('CUSTOMER_PROPS_COMPLETE',flush=True)
