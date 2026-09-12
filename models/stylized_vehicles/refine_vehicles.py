# EARLY DEVELOPMENT DRAFT. Use rebuild_final_vehicles.py or open Sugar_Street_Vehicles.blend for the corrected collection.

import bmesh
# Revised palette: saturated jewel-toned paint, warm cream, deep blue glazing.
for key,col in [('Lagoon',(.008,.285,.29)),('Guava',(.72,.065,.105)),('Blueberry',(.045,.19,.43)),('Custard',(.95,.48,.035)),('Pistachio',(.14,.47,.31)),('Tangerine',(.87,.145,.028)),('Wisteria',(.30,.155,.49))]:
 m=paints[key];m.diffuse_color=(*col,1)
 bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*col,1);bs.inputs['Roughness'].default_value=.28;bs.inputs['Coat Weight'].default_value=.22;bs.inputs['Coat Roughness'].default_value=.24
for m,col,rough in [(cream,(.94,.855,.64),.32),(glass,(.025,.17,.235),.18),(glint,(.25,.56,.62),.23),(tire,(.018,.028,.036),.82),(chrome,(.53,.64,.65),.24),(lamp,(1,.86,.56),.17)]:
 m.diffuse_color=(*col,1);bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*col,1);bs.inputs['Roughness'].default_value=rough
bs=lamp.node_tree.nodes.get('Principled BSDF');bs.inputs['Emission Color'].default_value=(1,.65,.24,1);bs.inputs['Emission Strength'].default_value=.12
def repair_normals(o,weighted=True):
 bm=bmesh.new();bm.from_mesh(o.data)
 bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
 bm.to_mesh(o.data);bm.free();o.data.update()
 for f in o.data.polygons:f.use_smooth=len(f.vertices)<=4
 if weighted:
  # Recompute after all topology operations; never carry stale split normals.
  for f in o.data.polygons:f.use_smooth=True
  bpy.context.view_layer.objects.active=o
  mod=o.modifiers.new('Final area-weighted normals','WEIGHTED_NORMAL');mod.keep_sharp=True;mod.weight=50;mod.thresh=.01
  try:bpy.ops.object.modifier_apply(modifier=mod.name)
  except:pass
def finish(o,bevel=0,segments=2,smooth=True):
 bpy.context.view_layer.objects.active=o;o.select_set(True)
 bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
 if bevel:
  mod=o.modifiers.new('Rounded profile edges','BEVEL');mod.width=bevel;mod.segments=segments
  mod.limit_method='ANGLE';mod.angle_limit=.35;mod.use_clamp_overlap=False;mod.loop_slide=True
  bpy.ops.object.modifier_apply(modifier=mod.name)
 repair_normals(o,smooth);o.select_set(False)
 return o
def profile(name,points,width,material,bevel=.10,taper=0,zbase=1):
 vs=[]
 for sign in [-1,1]:vs += [(x,sign*(width/2-taper*max(0,z-zbase)),z) for x,z in points]
 n=len(points);fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 me=bpy.data.meshes.new(name);me.from_pydata(vs,[],fs);me.update()
 o=bpy.data.objects.new(name,me);COL.objects.link(o);me.materials.append(material)
 if ROOT:o.parent=ROOT
 bpy.ops.object.select_all(action='DESELECT')
 return finish(o,.105 if 'cabin' in name else .085,3,True)
def body(length,w,r,axles,paint):
 half=length/2;bottom=r*.64;top=1.14 if r<.43 else 1.27
 pts=[(-half,bottom),(-half,top-.25),(-half+.13,top-.06),(-half+.40,top+.015),
      (half-.64,top+.015),(half-.26,top-.015),(half-.055,top-.13),(half,top-.29),(half,bottom)]
 for xc in sorted(axles,reverse=True):
  R=r+.065;dz=bottom-r;a=math.asin(dz/R)
  pts.append((xc+R*math.cos(a),bottom))
  for i in range(1,10):
   ang=a+(math.pi-2*a)*i/10;pts.append((xc+R*math.cos(ang),r+R*math.sin(ang)))
  pts.append((xc-R*math.cos(a),bottom))
 o=profile('Rounded wheel-well body',pts,w,paint,.085)
 # Slightly pinch the nose and tail for a fuller, less rectangular plan view.
 for v in o.data.vertices:
  endness=max(0,(abs(v.co.x)/(half)-.70)/.30)
  v.co.y*=1-.065*endness*endness
 repair_normals(o)
 return o,top
def rounded_points(points,cut=.055):
 result=[]
 for i,p in enumerate(points):
  prev=Vector(points[(i-1)%len(points)]);cur=Vector(p);nxt=Vector(points[(i+1)%len(points)])
  a=cur+(prev-cur)*min(.20,cut/(prev-cur).length)
  b=cur+(nxt-cur)*min(.20,cut/(nxt-cur).length)
  result += [tuple(a),tuple(a*.25+cur*.5+b*.25),tuple(b)]
 return result
def panel(name,points,side,width,material,taper=.13,zbase=1.1):
 points=rounded_points(points,.038) if 'window' in name.lower() else points
 verts=[(x,side*(width/2-taper*max(0,z-zbase)+.017),z) for x,z in points]
 # Correct outward-facing winding on both sides.
 o=mesh(name,verts,[tuple(reversed(range(len(verts)))) if side<0 else tuple(range(len(verts)))],material)
 for f in o.data.polygons:
  if f.normal.y*side<0:f.flip()
 return o
def cabin(points,w,paint,windows,front,rear=None,roof=None):
 profile('Sculpted cabin',points,w,paint,.105,taper=.13,zbase=1.1)
 for side in [-1,1]:
  for i,pts in enumerate(windows):
   center=sum((Vector(p) for p in pts),Vector((0,0)))/len(pts)
   outline=[tuple(center+(Vector(p)-center)*1.035) for p in pts]
   panel('Rubber window surround',outline,side,w,dark)
   panel('Side window '+str(i),pts,side,w+.013,glass)
 def boundary(z,frontside):
  xs=[]
  for i,(x1,z1) in enumerate(points):
   x2,z2=points[(i+1)%len(points)]
   if abs(z2-z1)>1e-6 and min(z1,z2)<=z<=max(z1,z2):xs.append(x1+(x2-x1)*(z-z1)/(z2-z1))
  return max(xs) if frontside else min(xs)
 for label,spec,frontside in [('Front windscreen',front,True),('Rear windscreen',rear,False)]:
  if not spec:continue
  _,zb,_,zt=spec;off=.024 if frontside else -.024
  levels=sorted(set([zb,zt]+[z for x,z in points if zb<z<zt]))
  vs=[]
  for z in levels:
   y=w/2-.13*max(0,z-1.1)-.145
   x=boundary(z,frontside)+off
   vs.extend([(x,-y,z),(x,y,z)])
  o=mesh(label,vs,[(2*i,2*i+1,2*i+3,2*i+2) for i in range(len(levels)-1)],glass)
  for f in o.data.polygons:
   if f.normal.x*(1 if frontside else -1)<0:f.flip()
  zlo=zt-.11;zhi=zt-.075
  xlo=boundary(zlo,frontside)+off*1.09;xhi=boundary(zhi,frontside)+off*1.09
  yw=w/2-.13*(zt-1.1)-.20
  mesh('Soft windshield highlight',[(xlo,-yw,zlo),(xlo,yw*.3,zlo),(xhi,yw*.3,zhi),(xhi,-yw,zhi)],[(0,1,2,3)],glint)
 if roof:
  loc,dims=roof
  box('Rounded contrast roof',loc,(dims[0]+.045,dims[1]+.045,.17),cream,.08,3)
def ring(name,center,rings,material,N=16):
 x,y,z=center
 vs=[(x+r*math.cos(2*math.pi*i/N),y+yy,z+r*math.sin(2*math.pi*i/N)) for yy,r in rings for i in range(N)]
 fs=[]
 for j in range(len(rings)-1):
  for i in range(N):fs.append((j*N+i,(j+1)*N+i,(j+1)*N+(i+1)%N,j*N+(i+1)%N))
 o=mesh(name,vs,fs,material,0,True)
 return o
def headlight(x,y,z):
 # Radially modeled housing, rolled cream bezel, metal lip, convex warm lens.
 N=16
 levels=[(-.13,.135),(-.065,.19),(.006,.195),(.047,.17),(.049,.137)]
 vs=[(x+dx,y+r*math.cos(2*math.pi*i/N),z+r*math.sin(2*math.pi*i/N)) for dx,r in levels for i in range(N)]
 fs=[(j*N+i,j*N+(i+1)%N,(j+1)*N+(i+1)%N,(j+1)*N+i) for j in range(len(levels)-1) for i in range(N)]
 ob=mesh('Rolled headlamp housing',vs,fs,cream,0,True)
 # Two concentric curved lens rings and a center fan.
 vs=[(x+.052,y+.137*math.cos(2*math.pi*i/N),z+.137*math.sin(2*math.pi*i/N)) for i in range(N)]
 vs +=[(x+.084,y+.092*math.cos(2*math.pi*i/N),z+.092*math.sin(2*math.pi*i/N)) for i in range(N)]
 vs +=[(x+.096,y,z)]
 fs=[(i,(i+1)%N,(i+1)%N+N,i+N) for i in range(N)]+[(N+i,N+(i+1)%N,2*N) for i in range(N)]
 ob=mesh('Domed headlamp lens',vs,fs,lamp,0,True)
 # Tiny specular inset catches the softbox even in game lighting.
 cyl('Lens reflector',(x+.085,y-.043,z+.055),.021,.008,cream,'X',8)
def details(length,w,r,paint,top,cabfront=.45,truck=False):
 half=length/2
 box('Soft front bumper',(half-.005,0,r+.10),(.19,w*.82,.17),cream,.075,3)
 box('Soft rear bumper',(-half+.006,0,r+.10),(.16,w*.83,.15),cream,.065,2)
 # Recessed curved intake, inset far enough to read as part of the body.
 box('Inset front grille',(half-.002,0,top-.32),(.065,w*.39,.145),dark,.055,2)
 for s in [-1,1]:
  headlight(half-.042,s*w*.325,top-.17)
  box('Rear lamp',(-half-.009,s*w*.34,top-.22),(.065,.14,.20),red,.052,2)
  cyl('Amber marker',(half-.085,s*w*.435,top-.40),.046,.025,amber,'X',10)
  box('Mirror stalk',(cabfront,s*(w/2+.065),1.41),(.055,.16,.05),dark,.019,1)
  box('Rounded mirror',(cabfront,s*(w/2+.15),1.46),(.16,.105,.215),paint,.049,3)
  box('Mirror face',(cabfront-.082,s*(w/2+.15),1.46),(.012,.075,.16),chrome,.025,1)
 box('Rear plate',(-half-.081,0,r+.11),(.012,.29,.075),dark,.012,1)
def arch(name,xc,side,w,r,paint):
 # Rounded three-dimensional bead, instead of a flat strip with bad back normals.
 N=12;verts=[]
 for i in range(N+1):
  a=math.pi*i/N
  for rr,dy in [(r+.045,.016),(r+.072,.052),(r+.122,.045),(r+.145,.003)]:
   verts.append((xc+rr*math.cos(a),side*(w/2+dy),r+rr*math.sin(a)))
 fs=[(4*i+j,4*(i+1)+j,4*(i+1)+j+1,4*i+j+1) for i in range(N) for j in range(3)]
 return mesh(name,verts,fs,paint,0,True)
def end(name,loc,wheelobs):
 global ROOT
 parts=[o for o in COL.objects if o.type=='MESH' and o not in wheelobs]
 ob=join_parts(parts,name+' • Body',(0,0,0))
 wt=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in wheelobs)
 bt=sum(len(p.vertices)-2 for p in ob.data.polygons)
 # Prefer the revised sculpted profiles over aggressive simplification.
 budget=3600
 if bt+wt>budget:
  bpy.context.view_layer.objects.active=ob
  mod=ob.modifiers.new('Conservative game reduction','DECIMATE');mod.ratio=(budget-wt)/bt
  bpy.ops.object.modifier_apply(modifier=mod.name)
 repair_normals(ob)
 for o in wheelobs:repair_normals(o)
 ROOT.location=loc
 meshes=[ob]+wheelobs
 tris=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes)
 polys=sum(len(o.data.polygons) for o in meshes)
 ROOT['triangles']=tris;ROOT['polygons']=polys
 for o in meshes:
  o['vehicle']=name
  bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
  bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=1.15192,island_margin=.02);bpy.ops.object.mode_set(mode='OBJECT');o.select_set(False)
 vehicles.append(dict(name=name,root=ROOT,collection=COL,triangles=tris,polygons=polys))
 ROOT=None
 print(name,'revised:',tris,'triangles /',polys,'polygons')
