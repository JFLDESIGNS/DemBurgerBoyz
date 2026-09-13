import bpy,bmesh,json,math,shutil
from pathlib import Path
from mathutils import Vector,Matrix
base=Path(r'C:\Users\joe\Desktop\burgergame'); src=base/'models/mail_star_truck/source';out=base/'assets/mail_truck';out.mkdir(exist_ok=True)
shutil.copy2(src/'mail_star_truck_editable_parts.blend',src/'user_edits_before_game_export.blend')
bpy.ops.wm.open_mainfile(filepath=str(src/'user_edits_before_game_export.blend'));bpy.context.view_layer.update()
def active(o):
 bpy.ops.object.select_all(action='DESELECT');o.hide_set(False);o.select_set(True);bpy.context.view_layer.objects.active=o
def bounds(o):
 ps=[o.matrix_world@Vector(p) for p in o.bound_box];return Vector([min(p[i] for p in ps) for i in range(3)]),Vector([max(p[i] for p in ps) for i in range(3)])
def ring(name,outer,inner,depth,mat,vertical=False):
 # One continuous mitered frame, with closed corners and short bevels.
 back=lambda p:(p[0],p[1]+depth,p[2]) if vertical else (p[0],p[1],p[2]-depth)
 vs=outer+inner+[back(p) for p in outer]+[back(p) for p in inner];fs=[]
 for i in range(4):
  j=(i+1)%4;fs += [(i,j,4+j,4+i),(8+i,12+i,12+j,8+j),(i,8+i,8+j,j),(4+i,4+j,12+j,12+i)]
 me=bpy.data.meshes.new(name);me.from_pydata(vs,[],fs);me.materials.append(mat);o=bpy.data.objects.new(name,me);bpy.context.scene.collection.objects.link(o)
 active(o);m=o.modifiers.new('Small edge bevel','BEVEL');m.width=.006;m.segments=2;bpy.ops.object.modifier_apply(modifier=m.name);return o
roof=[o for o in bpy.data.objects if o.type=='MESH' and o.name.startswith(('Roof edge cap','Roof cross edge cap','Roof edge satin','Roof cross satin'))]
lohi=[bounds(o) for o in roof]; ymin=min(x[0].y for x in lohi);ymax=max(x[1].y for x in lohi);zfront=min(x[1].z for x in lohi);zrear=max(x[1].z for x in lohi);w=1.267
mat=next(m for m in bpy.data.materials if m.name.startswith('07 |'))
for o in roof:bpy.data.objects.remove(o,do_unlink=True)
ring('Continuous mitered roof trim',[(-w,ymin,zfront),(w,ymin,zfront),(w,ymax,zrear),(-w,ymax,zrear)],[(-w+.045,ymin+.045,zfront),(w-.045,ymin+.045,zfront),(w-.045,ymax-.045,zrear),(-w+.045,ymax-.045,zrear)],.055,mat)
# Replace the four disconnected grille rails with a single closed trapezoid.
rails=[o for o in bpy.data.objects if o.name.startswith('Grille thin rim')]
for o in rails:bpy.data.objects.remove(o,do_unlink=True)
outer=[(-.74,-3.30,.974),(.74,-3.30,.974),(.61,-3.30,.721),(-.61,-3.30,.721)]
inner=[(-.694,-3.30,.944),(.694,-3.30,.944),(.581,-3.30,.753),(-.581,-3.30,.753)]
gr=ring('Closed grille surround',outer,inner,.022,mat,True)
for o in list(bpy.data.objects):
 if o.type=='MESH' and 'mud flap' in o.name.lower():bpy.data.objects.remove(o,do_unlink=True)
meshes=[o for o in bpy.data.objects if o.type=='MESH' and not o.name.startswith('Studio')]
wheel_sets={o.name:[c.name for c in o.children_recursive if c.type=='MESH'] for o in bpy.data.objects if o.name.startswith('Wheel assembly ')}
def tris():
 total=0
 for o in meshes:o.data.calc_loop_triangles();total+=len(o.data.loop_triangles)
 return total
before=tris()
for o in meshes:
 active(o)
 for m in list(o.modifiers):
  try:bpy.ops.object.modifier_apply(modifier=m.name)
  except: o.modifiers.remove(m)
 # Flat markings retain the user's colors and silhouettes with no raised back faces.
 if any(s in o.name.lower() for s in ['envelope','badge','star seal','instrument dial','instrument needle']):
  bm=bmesh.new();bm.from_mesh(o.data)
  axis=0 if 'instrument' not in o.name.lower() else 1
  world=[o.matrix_world@v.co for v in bm.verts];sign=1 if axis==1 or sum(p[axis] for p in world)>0 else -1
  edge=max(p[axis]*sign for p in world)*sign
  inv=o.matrix_world.inverted()
  # Keep only outward-facing faces before projection.
  dead=[f for f in bm.faces if (o.matrix_world.to_3x3()@f.normal)[axis]*sign<.15]
  bmesh.ops.delete(bm,geom=dead,context='FACES')
  for v in bm.verts:
   p=o.matrix_world@v.co;p[axis]=edge;v.co=inv@p
  bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001);bm.to_mesh(o.data);bm.free()
 if len(o.data.polygons)>40 and not any(s in o.name.lower() for s in ['windshield','hood cowl','cargo side','roof canopy']):
  m=o.modifiers.new('Game simplification','DECIMATE');m.ratio=.30 if 'Instrument' not in o.name else .16
  bpy.ops.object.modifier_apply(modifier=m.name)
 # Preserve analytically corrected windshield normals.
 if 'windshield' not in o.name.lower():
  bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
  bpy.ops.object.shade_smooth_by_angle(angle=math.radians(48),keep_sharp_edges=True)
  m=o.modifiers.new('Clean corner normals','WEIGHTED_NORMAL');m.keep_sharp=True
  try:bpy.ops.object.modifier_apply(modifier=m.name)
  except:pass
 if not o.data.uv_layers:
  bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(island_margin=.01);bpy.ops.object.mode_set(mode='OBJECT')
for iteration in range(3):
 count=tris()
 if count<=20500:break
 ratio=19500/count
 for o in meshes:
  if len(o.data.polygons)<40 or 'windshield' in o.name.lower():continue
  active(o);m=o.modifiers.new('Budget reduction','DECIMATE');m.ratio=ratio;bpy.ops.object.modifier_apply(modifier=m.name)
# Consolidate stationary meshes while retaining independently rotating wheels.
root=bpy.data.objects.new('DeliveryTruck',None);bpy.context.scene.collection.objects.link(root)
groups={}
for name,names in wheel_sets.items():groups[name.replace('Wheel assembly ','Wheel_')]=[o for o in meshes if o.name in names]
wheel_names={o.name for v in groups.values() for o in v};groups['TruckBody']=[o for o in meshes if o.name not in wheel_names]
for name,objs in groups.items():
 if not objs:continue
 pivot=Vector((0,0,0)) if name=='TruckBody' else bpy.data.objects[name.replace('Wheel_','Wheel assembly ')].matrix_world.translation.copy()
 bpy.ops.object.select_all(action='DESELECT')
 for o in objs:o.hide_set(False);o.select_set(True)
 bpy.context.view_layer.objects.active=objs[0];bpy.ops.object.join();o=bpy.context.object;o.name=name
 world=o.matrix_world.copy();o.parent=None;o.matrix_world=world;bpy.context.scene.cursor.location=pivot;bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
 bpy.context.view_layer.update();world=o.matrix_world.copy();o.parent=root;o.matrix_parent_inverse=Matrix.Identity(4);o.matrix_basis=world
bpy.context.view_layer.update();bpy.ops.object.select_all(action='DESELECT')
for o in [root]+list(root.children_recursive):o.select_set(True)
bpy.context.view_layer.objects.active=root
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(src/'mail_star_truck_game.blend'))
bpy.ops.export_scene.gltf(filepath=str(out/'mail_truck.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_cameras=False,export_lights=False)
count=0
for o in root.children:
 o.data.calc_loop_triangles();count+=len(o.data.loop_triangles)
report={'user_source':'user_edits_before_game_export.blend','before_triangles':before,'triangles':count,'mesh_nodes':[o.name for o in root.children],'mud_flaps':False,'graphics':'Flattened visible faces','trim':'Continuous roof and grille corners'}
(out/'export_report.json').write_text(json.dumps(report,indent=2));print('DELIVERY_TRUCK_EXPORTED',json.dumps(report))
