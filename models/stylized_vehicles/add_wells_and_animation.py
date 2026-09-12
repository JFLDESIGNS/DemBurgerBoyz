
import bpy, math, json, bmesh
from pathlib import Path
from mathutils import Vector
OUT=Path(r'C:\Users\joe\Desktop\burgergame\models\stylized_vehicles')
EXPORT=Path(r'C:\Users\joe\Desktop\burgergame\assets\vehicles\sugar_street')
EXPORT.mkdir(parents=True,exist_ok=True)
scene=bpy.context.scene
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Sugar_Street_before_driving.blend'),copy=True)
liner=bpy.data.materials.get('VEH • Recessed charcoal wheel wells') or bpy.data.materials.new('VEH • Recessed charcoal wheel wells')
liner.diffuse_color=(.018,.028,.032,1);liner.use_nodes=True
bs=liner.node_tree.nodes['Principled BSDF'];bs.inputs['Base Color'].default_value=liner.diffuse_color;bs.inputs['Roughness'].default_value=.86
vehicle_records=[]
for col in sorted(scene.collection.children,key=lambda c:c.name):
 roots=[o for o in col.objects if o.type=='EMPTY' and 'asset_id' in o]
 if not roots:continue
 root=roots[0]
 for old in list(col.objects):
  if old.type=='MESH' and old.name.startswith('WheelWell_'):bpy.data.objects.remove(old,do_unlink=True)
 body=next(o for o in col.objects if o.type=='MESH' and 'Body' in o.name)
 wheels=sorted([o for o in col.objects if o.type=='MESH' and o.name.startswith('Wheel_')],key=lambda o:o.name)
 for w in wheels:
  x,y,z=w.location
  radius=w.dimensions.z*.5;side=1 if y>0 else -1
  N=14;R=radius+.054
  # A closed, recessed arch liner with an inner back panel.
  profile=[(R,abs(y)-.075),(R,abs(y)-.34),(R+.014,abs(y)-.34),(R+.014,abs(y)-.075)]
  vs=[]
  for i in range(N+1):
   a=math.pi*i/N
   vs.extend((x+rr*math.cos(a),side*yy,z+rr*math.sin(a)) for rr,yy in profile)
  fs=[(4*i+j,4*(i+1)+j,4*(i+1)+(j+1)%4,4*i+(j+1)%4) for i in range(N) for j in range(4)]
  fs.extend([tuple(reversed(range(4))),tuple(range(N*4,N*4+4))])
  # Close the visible upper half at the rear of the cavity, well behind the tire.
  back_start=len(vs)
  vs +=[(x+R*math.cos(math.pi*i/N),side*(abs(y)-.345),z+R*math.sin(math.pi*i/N)) for i in range(N+1)]
  vs +=[(x-R,side*(abs(y)-.345),radius*.62),(x+R,side*(abs(y)-.345),radius*.62)]
  fs.append(tuple(range(back_start,len(vs))))
  me=bpy.data.meshes.new('Recessed wheel well');me.from_pydata(vs,[],fs);me.materials.append(liner)
  ob=bpy.data.objects.new('WheelWell_'+('Front' if x>0 else 'Rear')+('_L' if side>0 else '_R'),me);col.objects.link(ob);ob.parent=body
  bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free()
  for f in me.polygons:f.use_smooth=len(f.vertices)==4
  # Well is fixed to the suspension/body, never to the rotating wheel.
  ob['purpose']='recessed wheel-well liner'
 root['wheel_radius_m']=round(wheels[0].dimensions.z*.5,5)
 root['drive_reference_speed_mps']=round(root['wheel_radius_m']*math.tau*2,5)
 root['drive_clip']='DriveLoop'
 vehicle_records.append((col,root,body,wheels))
scene.render.fps=24;scene.frame_start=1;scene.frame_end=48
for col,root,body,wheels in vehicle_records:
 for ob in [body]+wheels:
  ob.animation_data_clear();ob.rotation_mode='XYZ'
 for w in wheels:
  for frame in range(1,50):
   w.rotation_euler.y=math.tau*4*(frame-1)/48
   w.keyframe_insert(data_path='rotation_euler',index=1,frame=frame,group='Wheel roll')
  w.animation_data.action.name=root['asset_id']+'_Drive_Wheel_'+w.name.split('.')[0]
 for frame in range(1,50):
  t=(frame-1)/48;wave=math.tau*t
  body.location.z=.009*(1-math.cos(wave*2))
  body.rotation_euler.y=.004*math.sin(wave*2)
  body.rotation_euler.x=.0025*math.sin(wave)
  body.keyframe_insert(data_path='location',index=2,frame=frame,group='Suspension')
  body.keyframe_insert(data_path='rotation_euler',frame=frame,group='Suspension')
 body.animation_data.action.name=root['asset_id']+'_Drive_Suspension'
 # Linear sampling makes the wheel phase continuous at the loop seam.
 for ob in [body]+wheels:
  action=ob.animation_data.action
  for layer in action.layers:
   for strip in layer.strips:
    for bag in strip.channelbags:
     for fc in bag.fcurves:
      for k in fc.keyframe_points:k.interpolation='LINEAR'
      fc.modifiers.new('CYCLES')
scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Sugar_Street_Vehicles.blend'))
bpy.app.driver_namespace['vehicle_export_records']=vehicle_records
print('Recessed wells and 2-second driving loops authored for',len(vehicle_records),'vehicles')
print('GODOT',[str(p) for p in Path(r'C:\Users\joe\Downloads\godot').rglob('*.exe')][:15])
print('ANIMATION MODES',[(i.identifier,i.name) for i in bpy.ops.export_scene.gltf.get_rna_type().properties['export_animation_mode'].enum_items])
