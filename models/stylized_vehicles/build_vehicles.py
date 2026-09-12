# EARLY DEVELOPMENT DRAFT. Use rebuild_final_vehicles.py or open Sugar_Street_Vehicles.blend for the corrected collection.
import bpy, math, json
from pathlib import Path
from mathutils import Vector
OUT=Path(r'C:\Users\joe\Desktop\burgergame\models\stylized_vehicles')
OUT.mkdir(exist_ok=True)
(OUT/'.gdignore').write_text('# Blender source collection; export selected vehicles to Godot when ready.\n')
scene=bpy.data.scenes.new('SUGAR STREET | Seven little vehicles')
bpy.context.window.scene=scene
scene.unit_settings.system='METRIC'
scene.unit_settings.scale_length=1
studio=bpy.data.collections.new('00 • STUDIO (exclude from game export)')
scene.collection.children.link(studio)
vehicles=[]
COL=studio
ROOT=None
def mat(name, color, rough=.38, metal=0):
 m=bpy.data.materials.new('VEH • '+name)
 m.diffuse_color=(*color,1)
 m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF')
 bs.inputs['Base Color'].default_value=(*color,1)
 bs.inputs['Roughness'].default_value=rough
 bs.inputs['Metallic'].default_value=metal
 return m
cream=mat('Warm porcelain',(0.92,.83,.62),.33)
tire=mat('Soft graphite rubber',(.028,.043,.055),.78)
glass=mat('Opaque blue glass',(.095,.38,.48),.22,.12)
glint=mat('Glass sky reflection',(.40,.75,.79),.25)
dark=mat('Deep petrol trim',(.027,.10,.12),.52)
chrome=mat('Satin alloy',(.54,.68,.67),.3,.48)
lamp=mat('Butter headlamps',(1,.83,.39),.24)
red=mat('Coral tail lights',(.66,.035,.05),.3)
amber=mat('Apricot indicators',(1,.32,.045),.32)
wood=mat('Honey wood deck',(.48,.24,.083),.75)
paints={}
for key,col in [('Lagoon',(.018,.43,.40)),('Guava',(.86,.115,.19)),('Blueberry',(.09,.29,.58)),('Custard',(1,.59,.09)),('Pistachio',(.28,.65,.47)),('Tangerine',(.96,.255,.07)),('Wisteria',(.46,.29,.66))]:
 paints[key]=mat(key+' enamel',col,.32,.05)
def link(o,name,material):
 o.name=name
 for c in list(o.users_collection): c.objects.unlink(o)
 COL.objects.link(o)
 if material: o.data.materials.append(material)
 if ROOT: o.parent=ROOT
 return o
def finish(o, bevel=0,segments=2,smooth=True):
 bpy.context.view_layer.objects.active=o
 o.select_set(True)
 if bevel:
  mod=o.modifiers.new('Soft manufactured edges','BEVEL');mod.width=bevel;mod.segments=segments
  bpy.ops.object.modifier_apply(modifier=mod.name)
 if smooth:
  for f in o.data.polygons:f.use_smooth=True
  mod=o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL');mod.keep_sharp=True;mod.weight=40
  try:bpy.ops.object.modifier_apply(modifier=mod.name)
  except:pass
 o.select_set(False)
 return o
def box(name,loc,dims,material,bevel=.05,segments=2):
 bpy.ops.object.select_all(action='DESELECT')
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc)
 o=link(bpy.context.object,name,material)
 o.dimensions=dims
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 return finish(o,bevel,segments)
def mesh(name,verts,faces,material,bevel=0,smooth=False):
 me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
 o=bpy.data.objects.new(name,me);COL.objects.link(o)
 if material:me.materials.append(material)
 if ROOT:o.parent=ROOT
 bpy.ops.object.select_all(action='DESELECT')
 return finish(o,bevel,2,smooth)
def profile(name,points,width,material,bevel=.045,taper=0,zbase=1):
 verts=[]
 for sign in [-1,1]:
  verts += [(x,sign*(width/2-taper*max(0,z-zbase)),z) for x,z in points]
 n=len(points)
 faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]
 faces +=[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 return mesh(name,verts,faces,material,bevel,True)
def panel(name,points,side,width,material,taper=.13,zbase=1.1):
 verts=[(x,side*(width/2-taper*max(0,z-zbase)+.014),z) for x,z in points]
 return mesh(name,verts,[tuple(range(len(verts))) if side<0 else tuple(reversed(range(len(verts))))],material)
def line(name,points,material,radius=.008):
 cu=bpy.data.curves.new(name,'CURVE');cu.dimensions='3D';cu.resolution_u=1
 cu.bevel_depth=radius;cu.bevel_resolution=0;cu.resolution_u=1
 sp=cu.splines.new('POLY');sp.points.add(len(points)-1)
 for p,co in zip(sp.points,points):p.co=(*co,1)
 o=bpy.data.objects.new(name,cu);COL.objects.link(o);o.data.materials.append(material)
 if ROOT:o.parent=ROOT
 bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
 bpy.ops.object.convert(target='MESH');o.select_set(False)
 return o
def cyl(name,loc,radius,depth,material,axis='Y',vertices=16):
 bpy.ops.object.select_all(action='DESELECT')
 bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,end_fill_type='NGON',location=loc)
 o=link(bpy.context.object,name,material)
 if axis=='Y':o.rotation_euler[0]=math.pi/2
 elif axis=='X':o.rotation_euler[1]=math.pi/2
 bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
 for f in o.data.polygons:f.use_smooth=(len(f.vertices)==4)
 o.select_set(False)
 return o
def ring(name,center,rings,material,N=16):
 x,y,z=center
 vs=[(x+r*math.cos(2*math.pi*i/N),y+yy,z+r*math.sin(2*math.pi*i/N)) for yy,r in rings for i in range(N)]
 fs=[]
 for j in range(len(rings)-1):
  for i in range(N):fs.append((j*N+i,j*N+(i+1)%N,(j+1)*N+(i+1)%N,(j+1)*N+i))
 return mesh(name,vs,fs,material,0,True)
def join_parts(obs,name,origin):
 bpy.ops.object.select_all(action='DESELECT')
 for o in obs:o.select_set(True)
 bpy.context.view_layer.objects.active=obs[0]
 bpy.ops.object.join()
 o=bpy.context.object;o.name=name
 scene.cursor.location=origin;bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
 o.select_set(False)
 return o
def wheel(x,side,w,r,paint,tag):
 y=side*(w/2+.025);z=r
 before=set(COL.objects)
 ring('Rounded tire',(x,y,z),[(-.17,.59*r),(-.17,.87*r),(-.12,r),(.12,r),(.17,.87*r),(.17,.59*r)],tire)
 cyl('Cream wheel rim',(x,y+side*.174,z),r*.63,.025,cream,vertices=16)
 cyl('Painted hub',(x,y+side*.196,z),r*.37,.028,paint,vertices=12)
 cyl('Axle cap',(x,y+side*.216,z),r*.135,.032,chrome,vertices=8)
 return join_parts([o for o in COL.objects if o not in before],tag,(x,y,z))
def arch(name,xc,side,w,r,paint):
 # Open, raised wheel arch follows the tire with genuine clearance.
 verts=[];n=10
 for i in range(n+1):
  a=math.pi*i/n
  for rr in [r+.045,r+.135]:
   verts.append((xc+rr*math.cos(a),side*(w/2+.018),r+rr*math.sin(a)))
 faces=[(2*i,2*i+1,2*i+3,2*i+2) for i in range(n)]
 return mesh(name,verts,faces,paint)
def body(length,w,r,axles,paint):
 # Silhouette includes wheel wells, so tires do not intersect a solid box.
 half=length/2;bottom=r*.68;top=1.12 if r<.43 else 1.25
 pts=[(-half,bottom),(-half,top-.17),(-half+.18,top),(half-.28,top),(half,top-.14),(half,bottom)]
 for xc in sorted(axles,reverse=True):
  R=r+.055;dz=bottom-r
  a=math.asin(dz/R)
  pts.append((xc+R*math.cos(a),bottom))
  for i in range(1,12):
   ang=a+(math.pi-2*a)*i/12
   pts.append((xc+R*math.cos(ang),r+R*math.sin(ang)))
  pts.append((xc-R*math.cos(a),bottom))
 return profile('Wheel-well body shell',pts,w,paint,.035),top
def windscreen(name,xb,zb,xt,zt,w,taper=.13,zbase=1.1):
 def yw(z):return w/2-taper*max(0,z-zbase)-.10
 # Offset outward on front/back plane.
 off=.013 if xb>xt else -.013
 vs=[(xb+off,-yw(zb),zb),(xb+off,yw(zb),zb),(xt+off,yw(zt),zt),(xt+off,-yw(zt),zt)]
 return mesh(name,vs,[(0,1,2,3)],glass)
def cabin(points,w,paint,windows,front,rear=None,roof=None):
 profile('Sculpted cabin',points,w,paint,.045,taper=.13,zbase=1.1)
 for side in [-1,1]:
  for i,p in enumerate(windows):
   panel('Side window '+str(i),p,side,w,glass)
   # Small static reflection accent, no shader dependency.
   if len(p)>=4:
    a=Vector(p[-1]);b=Vector(p[-2]);c=Vector(p[0])
    q=[tuple(a*.78+c*.22),tuple(a*.64+b*.18+c*.18),tuple(a*.47+b*.18+c*.35),tuple(a*.61+c*.39)]
    panel('Sky highlight',q,side,w+.006,glint)
 windscreen('Front windscreen',*front,w)
 if rear:windscreen('Rear windscreen',*rear,w)
 if roof:
  box('Contrasting roof',roof[0],roof[1],cream,.06,2)
def details(length,w,r,paint,top,cabfront=.45,truck=False):
 half=length/2
 for side in [-1,1]:
  box('Front bumper', (half+.025,0,r+.10),(.15,w*.89,.135),cream,.045)
  break
 box('Rear bumper',(-half-.015,0,r+.10),(.13,w*.88,.12),cream,.04)
 box('Friendly grille',(half+.03,0,top-.27),(.055,w*.41,.18),dark,.05)
 # Thin curved lower grille gives a friendly expression without painted eyes.
 for side in [-1,1]:
  y=side*w*.34
  cyl('Headlamp bezel',(half-.01,y,top-.12),.17,.09,cream,'X',16)
  cyl('Headlamp lens',(half+.042,y,top-.12),.124,.016,lamp,'X',16)
  box('Rear lamp',(-half-.025,side*w*.36,top-.15),(.045,.15,.22),red,.035,2)
  box('Mirror stalk',(cabfront,side*(w/2+.08),1.34),(.065,.18,.06),dark,.018,1)
  box('Candy mirror',(cabfront,side*(w/2+.16),1.40),(.16,.095,.22),paint,.035,2)
  box('Mirror glass',(cabfront-.084,side*(w/2+.16),1.41),(.012,.068,.15),chrome,.012,1)
 box('Rear plate',(-half-.091,0,r+.11),(.01,.32,.09),dark,.01,1)
def door(xrear,xfront,w,top,paint):
 for side in [-1,1]:
  y=side*(w/2+.012)
  line('Door shut line',[(xrear,y,top),(xrear,y,.67),(xrear+.06,y,.59),(xfront-.04,y,.59),(xfront,y,.66),(xfront,y,top)],dark,.006)
  box('Porcelain handle',(xrear+.16,y+side*.016,top-.075),(.20,.04,.038),cream,.015,1)
def begin(name,color,loc):
 global COL,ROOT
 COL=bpy.data.collections.new(name);scene.collection.children.link(COL)
 ROOT=bpy.data.objects.new(name+' • ROOT',None);COL.objects.link(ROOT)
 ROOT.empty_display_type='PLAIN_AXES';ROOT.empty_display_size=.35
 ROOT['forward_axis']='+X';ROOT['up_axis']='+Z';ROOT['units']='meters'
 ROOT['material_workflow']='Principled BSDF / opaque base colors; no procedural textures'
 return paints[color]
def end(name,loc,wheelobs):
 global ROOT
 parts=[o for o in COL.objects if o.type=='MESH' and o not in wheelobs]
 bodyobj=join_parts(parts,name+' • Body',(0,0,0))
 ROOT.location=loc
 meshes=[bodyobj]+wheelobs
 tris=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes)
 polys=sum(len(o.data.polygons) for o in meshes)
 ROOT['triangles']=tris;ROOT['polygons']=polys
 for o in meshes:
  o['vehicle']=name
  # Generate a basic UV layout for future paint texture work.
  bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
  bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
  bpy.ops.uv.smart_project(angle_limit=1.15192,island_margin=.02)
  bpy.ops.object.mode_set(mode='OBJECT');o.select_set(False)
 vehicles.append(dict(name=name,root=ROOT,collection=COL,triangles=tris,polygons=polys))
 ROOT=None
 print(name, 'TRIS',tris,'POLYGONS',polys)


# Resolve windscreen vertices onto the actual cabin surface.
def cabin(points,w,paint,windows,front,rear=None,roof=None):
 profile('Sculpted cabin',points,w,paint,.045,taper=.13,zbase=1.1)
 for side in [-1,1]:
  for i,p in enumerate(windows):
   panel('Side window '+str(i),p,side,w,glass)
 def boundary(z,frontside):
  xs=[]
  for i,(x1,z1) in enumerate(points):
   x2,z2=points[(i+1)%len(points)]
   if abs(z2-z1)>1e-6 and min(z1,z2)<=z<=max(z1,z2):
    xs.append(x1+(x2-x1)*(z-z1)/(z2-z1))
  return max(xs) if frontside else min(xs)
 for label,spec,frontside in [('Front windscreen',front,True),('Rear windscreen',rear,False)]:
  if not spec:continue
  xb,zb,xt,zt=spec
  xb=boundary(zb,frontside);xt=boundary(zt,frontside)
  off=.02 if frontside else -.02
  def yw(z):return w/2-.13*max(0,z-1.1)-.10
  verts=[(xb+off,-yw(zb),zb),(xb+off,yw(zb),zb),(xt+off,yw(zt),zt),(xt+off,-yw(zt),zt)]
  mesh(label,verts,[(0,1,2,3)],glass)
  # A slim, graphic reflected stripe in the top of the windscreen.
  zlo=zt-.11;zhi=zt-.065
  xlo=boundary(zlo,frontside)+off*1.08;xhi=boundary(zhi,frontside)+off*1.08
  mesh('Windscreen reflected sky',[(xlo,-yw(zlo)*.86,zlo),(xlo,yw(zlo)*.40,zlo),(xhi,yw(zhi)*.40,zhi),(xhi,-yw(zhi)*.86,zhi)],[(0,1,2,3)],glint)
 if roof:box('Contrasting roof',roof[0],roof[1],cream,.06,2)
_original_end=end
def end(name,loc,wheelobs):
 # Collapse only body detail where needed; preserve full wheel silhouettes.
 parts=[o for o in COL.objects if o.type=='MESH' and o not in wheelobs]
 bodyobj=join_parts(parts,name+' • Body',(0,0,0))
 wt=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in wheelobs)
 bt=sum(len(p.vertices)-2 for p in bodyobj.data.polygons)
 if bt+wt>2950:
  bpy.context.view_layer.objects.active=bodyobj
  mod=bodyobj.modifiers.new('Game triangle budget','DECIMATE');mod.ratio=(2930-wt)/bt
  bpy.ops.object.modifier_apply(modifier=mod.name)
 _original_end(name,loc,wheelobs)

# 01 / LAGOON — compact upright city hatchback
name='01 • Lagoon Hatch'
p=begin(name,'Lagoon',(-8.1,-2.7,0))
L=3.55;W=1.66;r=.385;ax=[-1.08,1.10]
_,h=body(L,W,r,ax,p)
cabin([(-1.43,1.08),(-1.24,1.78),(-.98,2.02),(.52,2.02),(.90,1.17),(.94,1.08)],W,p,
 [[(-1.27,1.23),(-1.12,1.77),(-.93,1.89),(-.36,1.89),(-.36,1.23)],
 [(-.25,1.23),(-.25,1.89),(.45,1.89),(.74,1.23)]],
 (.77,1.23,.49,1.91),(-1.38,1.22,-1.21,1.76),
 ((-.23,0,2.035),(1.57,1.43,.12)))
door(-.28,.82,W,h,p)
details(L,W,r,p,h,.62)
wheels=[wheel(x,s,W,r,p,'Wheel_'+('Front' if x>0 else 'Rear')+('_L' if s>0 else '_R')) for x in ax for s in [-1,1]]
for x in ax:
 for s in [-1,1]:arch('Raised turquoise wheel arch',x,s,W,r,p)
end(name,(-8.1,-2.7,0),wheels)

# 02 / GUAVA — rounded microcar
name='02 • Guava Micro'
p=begin(name,'Guava',(-2.8,-2.7,0))
L=3.12;W=1.62;r=.365;ax=[-.95,.99]
_,h=body(L,W,r,ax,p)
cabin([(-1.29,1.06),(-1.20,1.48),(-.98,1.88),(-.63,2.10),(-.16,2.18),(.32,2.04),(.64,1.72),(.87,1.12)],W,p,
 [[(-1.12,1.22),(-1.04,1.46),(-.85,1.80),(-.57,1.98),(-.22,2.035),(-.22,1.22)],
 [(-.10,1.22),(-.10,2.04),(.25,1.93),(.52,1.64),(.71,1.22)]],
 (.75,1.24,.48,1.83),(-1.21,1.24,-1.04,1.63))
door(-.15,.77,W,h,p)
details(L,W,r,p,h,.61)
for s in [-1,1]:
 panel('Cream rocker accent',[(-.49,.34),(.52,.34),(.52,.44),(-.49,.44)],s,W+.026,cream,taper=0)
wheels=[wheel(x,s,W,r,p,'Wheel_'+('Front' if x>0 else 'Rear')+('_L' if s>0 else '_R')) for x in ax for s in [-1,1]]
for x in ax:
 for s in [-1,1]:arch('Butter wheel arch',x,s,W,r,cream)
end(name,(-2.8,-2.7,0),wheels)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Sugar_Street_Vehicles.blend'))
# 03 / BLUEBERRY — long two-tone estate
name='03 • Blueberry Estate'
p=begin(name,'Blueberry',(2.7,-2.7,0))
L=4.22;W=1.74;r=.40;ax=[-1.35,1.30]
_,h=body(L,W,r,ax,p)
cabin([(-1.89,1.08),(-1.75,1.77),(-1.52,2.01),(.62,2.01),(1.00,1.12)],W,p,
 [[(-1.72,1.24),(-1.60,1.75),(-1.45,1.87),(-.91,1.87),(-.91,1.24)],
 [(-.80,1.24),(-.80,1.87),(-.18,1.87),(-.18,1.24)],
 [(-.07,1.24),(-.07,1.87),(.53,1.87),(.82,1.24)]],
 (.85,1.25,.64,1.86),(-1.85,1.25,-1.75,1.73),
 ((-.44,0,2.035),(2.27,1.47,.12)))
door(-.86,-.12,W,h,p);door(-.08,.86,W,h,p)
details(L,W,r,p,h,.67)
for s in [-1,1]:
 box('Roof luggage rail',(-.49,s*.53,2.17),(1.59,.055,.06),chrome,.025,1)
 for x in [-1.12,.12]:box('Rack mount',(x,s*.53,2.11),(.08,.065,.10),dark,.016,1)
wheels=[wheel(x,s,W,r,p,'Wheel_'+('Front' if x>0 else 'Rear')+('_L' if s>0 else '_R')) for x in ax for s in [-1,1]]
for x in ax:
 for s in [-1,1]:arch('Blue wheel arch',x,s,W,r,p)
end(name,(2.7,-2.7,0),wheels)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Sugar_Street_Vehicles.blend'))
# 04 / CUSTARD — cheerful open-bed pickup
name='04 • Custard Pickup'
p=begin(name,'Custard',(8.25,-2.7,0))
L=3.95;W=1.78;r=.435;ax=[-1.21,1.20]
_,h=body(L,W,r,ax,p)
cabin([(-.35,1.13),(-.34,2.01),(-.18,2.15),(.59,2.15),(.92,1.25),(.98,1.13)],W,p,
 [[(-.21,1.38),(-.21,1.97),(-.10,2.02),(.51,2.02),(.78,1.38)]],
 (.82,1.40,.63,2.00),(-.35,1.40,-.34,1.95),
 ((.15,0,2.16),(.97,1.53,.10)))
# Bed floor sits between raised side rails and a real tailgate.
box('Recessed pickup bed',(-1.13,0,1.26),(1.40,1.48,.065),dark,.02,1)
for s in [-1,1]:
 box('Pickup bed side',(-1.16,s*.80,1.40),(1.54,.16,.38),p,.05,2)
 box('Bed rail cap',(-1.16,s*.80,1.61),(1.54,.18,.065),cream,.025,1)
box('Tailgate',(-1.88,0,1.40),(.14,1.50,.38),p,.05,2)
box('Tailgate handle',(-1.96,0,1.49),(.035,.31,.065),cream,.015,1)
for y in [-.46,-.15,.15,.46]:
 box('Bed pressed rib',(-1.13,y,1.304),(1.29,.023,.018),chrome,.004,1)
door(-.31,.85,W,h,p);details(L,W,r,p,h,.67,True)
wheels=[wheel(x,s,W,r,p,'Wheel_'+('Front' if x>0 else 'Rear')+('_L' if s>0 else '_R')) for x in ax for s in [-1,1]]
for x in ax:
 for s in [-1,1]:arch('Painted pickup arch',x,s,W,r,p)
end(name,(8.25,-2.7,0),wheels)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Sugar_Street_Vehicles.blend'))
# Keep the growing collection visible in the live Blender viewport.
for a in bpy.context.screen.areas:
 if a.type=='VIEW_3D':
  a.spaces.active.region_3d.view_location=(0,-2.7,1)
  a.spaces.active.region_3d.view_distance=23
  a.tag_redraw()

# 05 / PISTACHIO — rounded two-tone local delivery van
name='05 • Pistachio Van'
p=begin(name,'Pistachio',(-5.5,2.8,0))
L=3.98;W=1.84;r=.415;ax=[-1.28,1.24]
_,h=body(L,W,r,ax,p)
cabin([(-1.86,1.08),(-1.85,2.12),(-1.58,2.43),(.93,2.43),(1.34,2.14),(1.77,1.16)],W,cream,
 [[(.32,1.40),(.32,2.27),(.85,2.27),(1.21,2.04),(1.48,1.40)]],
 (1.54,1.43,1.33,2.12),(-1.85,1.62,-1.85,2.06))
for s in [-1,1]:
 panel('Mint cargo inset',[(-1.69,1.35),(-1.69,2.08),(-1.47,2.25),(.14,2.25),(.14,1.35)],s,W,p)
 line('Sliding cargo door seam',[(.20,s*(W/2+.018),1.16),(.20,s*(W/2-.11),2.26)],dark,.009)
 box('Sliding door handle',(.02,s*(W/2+.028),1.31),(.22,.04,.045),chrome,.018,1)
 # Simple three-dimensional parcel emblem.
 box('Parcel badge',(-.82,s*(W/2-.072),1.82),(.52,.035,.42),cream,.05,2)
 box('Parcel tape',(-.82,s*(W/2-.094+s*0),1.82),(.07,.065,.43),p,.006,1)
door(.27,1.53,W,h,p)
details(L,W,r,p,h,1.29,True)
wheels=[wheel(x,s,W,r,p,'Wheel_'+('Front' if x>0 else 'Rear')+('_L' if s>0 else '_R')) for x in ax for s in [-1,1]]
for x in ax:
 for s in [-1,1]:arch('Mint wheel arch',x,s,W,r,p)
end(name,(-5.5,2.8,0),wheels)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Sugar_Street_Vehicles.blend'))
# 06 / TANGERINE — work truck with open timber flatbed
name='06 • Tangerine Flatbed'
p=begin(name,'Tangerine',(0,2.8,0))
L=4.62;W=1.86;r=.46;ax=[-1.54,1.45]
_,h=body(L,W,r,ax,p)
cabin([(-.12,1.18),(-.12,2.22),(.08,2.39),(.99,2.39),(1.40,1.24)],W,p,
 [[(.04,1.42),(.04,2.16),(.16,2.24),(.90,2.24),(1.23,1.42)]],
 (1.29,1.43,1.02,2.24),(-.12,1.48,-.12,2.13),
 ((.46,0,2.405),(1.17,1.61,.12)))
box('Flatbed frame',(-1.21,0,1.26),(2.10,1.87,.18),dark,.035,1)
for y in [-.68,-.34,0,.34,.68]:
 box('Wooden bed plank',(-1.21,y,1.37),(2.02,.32,.10),wood,.017,1)
for s in [-1,1]:
 box('Timber side rail',(-1.21,s*.89,1.77),(2.08,.07,.22),wood,.02,1)
 for x in [-2.16,-1.19,-.24]:
  box('Orange stake',(x,s*.89,1.65),(.085,.09,.65),p,.02,1)
box('Timber headboard',(-.22,0,1.83),(.075,1.73,.40),wood,.025,1)
door(-.06,1.25,W,h,p);details(L,W,r,p,h,1.10,True)
wheels=[wheel(x,s,W,r,p,'Wheel_'+('Front' if x>0 else 'Rear')+('_L' if s>0 else '_R')) for x in ax for s in [-1,1]]
for x in ax:
 for s in [-1,1]:arch('Orange wheel arch',x,s,W,r,p)
end(name,(0,2.8,0),wheels)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Sugar_Street_Vehicles.blend'))
# 07 / WISTERIA — soft-edged neighborhood box truck
name='07 • Wisteria Box Truck'
p=begin(name,'Wisteria',(5.7,2.8,0))
L=4.50;W=1.90;r=.45;ax=[-1.43,1.42]
_,h=body(L,W,r,ax,p)
cabin([(.24,1.18),(.24,2.16),(.42,2.37),(1.16,2.37),(1.63,1.27)],W,p,
 [[(.38,1.44),(.38,2.13),(.49,2.23),(1.07,2.23),(1.43,1.44)]],
 (1.45,1.45,1.19,2.20),None,
 ((.82,0,2.39),(.92,1.65,.12)))
box('Rounded cargo box',(-1.025,0,2.05),(2.42,1.94,1.79),cream,.13,3)
for s in [-1,1]:
 box('Lavender cargo inset',(-1.025,s*.978,2.06),(2.00,.03,1.22),p,.105,3)
 box('Porcelain cargo stripe',(-1.025,s*.998,1.61),(1.86,.012,.075),cream,.017,1)
 # Bold simple wing badge on each side.
 panel('Courier wing',[(-1.49,2.12),(-1.30,2.30),(-.64,2.30),(-.84,2.12)],s,2.009,cream,taper=0)
 panel('Courier wing lower',[(-1.38,1.94),(-1.23,2.06),(-.90,2.06),(-1.03,1.94)],s,2.009,cream,taper=0)
box('Rear roller shutter',(-2.25,0,2.04),(.025,1.57,1.44),chrome,.045,2)
for z in [1.52,1.72,1.92,2.12,2.32,2.52]:
 line('Roller shutter joint',[(-2.267,-.74,z),(-2.267,.74,z)],dark,.008)
box('Roller shutter latch',(-2.278,0,1.52),(.045,.27,.08),cream,.017,1)
door(.31,1.47,W,h,p);details(L,W,r,p,h,1.26,True)
wheels=[wheel(x,s,W,r,p,'Wheel_'+('Front' if x>0 else 'Rear')+('_L' if s>0 else '_R')) for x in ax for s in [-1,1]]
for x in ax:
 for s in [-1,1]:arch('Lavender wheel arch',x,s,W,r,p)
end(name,(5.7,2.8,0),wheels)
for a in bpy.context.screen.areas:
 if a.type=='VIEW_3D':
  a.spaces.active.region_3d.view_location=(0,0,1)
  a.spaces.active.region_3d.view_distance=26
  a.tag_redraw()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Sugar_Street_Vehicles.blend'))

# Presentation-only studio. Vehicle roots and wheel pivots remain separate.
COL=studio;ROOT=None
floor_mat=mat('Studio warm linen',(.73,.69,.60),.9)
pad_mat=mat('Display porcelain',(.89,.855,.765),.75)
ink=mat('Studio ink',(.038,.105,.12),.75)
muted=mat('Studio muted type',(.24,.32,.32),.85)
box('Endless warm studio',(0,0,-.23),(200,200,.2),floor_mat,0)
for v in vehicles:
 x,y,z=v['root'].location
 box(v['name']+' • presentation pad',(x,y,-.085),(5.10,4.5,.16),pad_mat,.20,4)
def text_obj(name,body,loc,size,material,align='CENTER'):
 cu=bpy.data.curves.new(name,'FONT');cu.body=body;cu.size=size;cu.align_x=align;cu.space_character=1.1
 ob=bpy.data.objects.new(name,cu);COL.objects.link(ob);ob.location=loc;cu.materials.append(material)
 return ob
for v in vehicles:
 x,y,_=v['root'].location
 number,title=v['name'].split(' • ')
 text_obj('Label '+title,number+'  /  '+title.upper(),(x,y-1.63,.009),.215,ink)
 text_obj('Budget '+title,format(v['triangles'],',')+' TRIANGLES',(x,y-1.94,.009),.135,muted)
text_obj('Collection heading','SUGAR STREET',(0,6.50,.01),.78,ink)
text_obj('Collection subheading','SEVEN LITTLE VEHICLES  /  BUILT FOR PLAY',(0,5.98,.012),.205,muted)
world=scene.world or bpy.data.worlds.new('Sugar Street studio world');scene.world=world;world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.64,.75,.84,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.35
def area(name,loc,power,size,color,target=(0,0,0)):
 data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size;data.color=color
 o=bpy.data.objects.new(name,data);studio.objects.link(o);o.location=loc
 o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
 return o
area('Large warm key',(-6,-8,13),2500,10,(1,.88,.72))
area('Cool sky fill',(9,-1,10),2000,8,(.73,.87,1))
area('Warm rim',(-3,10,12),3000,9,(1,.92,.77))
data=bpy.data.cameras.new('Collection camera')
camera=bpy.data.objects.new('Collection camera',data);studio.objects.link(camera)
camera.location=(8,-21,23)
camera.rotation_euler=(Vector((0,.8,.35))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO';camera.data.ortho_scale=26.7
scene.camera=camera
scene.render.engine='CYCLES';scene.cycles.samples=40;scene.cycles.use_denoising=True
scene.render.resolution_x=2200;scene.render.resolution_y=1500;scene.render.resolution_percentage=70
scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False
scene.view_settings.view_transform='AgX'
scene.view_settings.look='AgX - Medium High Contrast'
scene.view_settings.exposure=.6
scene.render.filepath=str(OUT/'Sugar_Street_Collection.png')
for a in bpy.context.screen.areas:
 if a.type=='VIEW_3D':
  a.spaces.active.region_3d.view_perspective='CAMERA'
  a.spaces.active.region_3d.view_camera_zoom=3
  a.spaces.active.overlay.show_overlays=False
  a.spaces.active.shading.type='MATERIAL'
  a.spaces.active.shading.use_scene_world=False
  a.spaces.active.shading.use_scene_lights=False
  a.tag_redraw()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Sugar_Street_Vehicles.blend'))
