import bpy, math
from mathutils import Vector
from pathlib import Path
p=Path('C:/Users/joe/Desktop/burgergame/assets/machines')
s=bpy.context.scene;s.frame_set(1)
asset=bpy.data.collections['GRILL | Export'];root=bpy.data.objects['StylizedGrill'];front=bpy.data.objects['ControlPanelMount']
def mat(prefix):return next(m for m in bpy.data.materials if m.name.startswith(prefix))
steel=mat('Satin stainless');dark=mat('Charcoal');charcoal=mat('Enamel')
def remove(name):
    o=bpy.data.objects.get(name)
    if o:bpy.data.objects.remove(o,do_unlink=True)
def link(o):
    for c in list(o.users_collection):c.objects.unlink(o)
    asset.objects.link(o)
def box(name,loc,dim,material,bevel=.003,parent=front):
    remove(name);bpy.ops.mesh.primitive_cube_add(size=1)
    o=bpy.context.object;link(o);o.name=name;o.parent=parent;o.location=loc;o.dimensions=dim
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.data.materials.append(material);m=o.modifiers.new('Soft edges','BEVEL');m.width=bevel;m.segments=3;o.modifiers.new('Weighted normals','WEIGHTED_NORMAL');return o
# Scale the COMPLETE control assembly once; the dial keeps its authored animation.
group=bpy.data.objects.get('ControlAssembly')
if group is None:
    group=bpy.data.objects.new('ControlAssembly',None);asset.objects.link(group);group.parent=front
    for name in ['ControlPod','ControlPodGasket','ControlPodFace','DialMount','PilotBezel','PowerIndicator','PilotLabel']:
        bpy.data.objects[name].parent=group
group.scale=(.7,.7,.7)
group.location=front.rotation_euler.to_matrix().inverted() @ Vector((0,0,-.026))
bpy.context.view_layer.update()
dg=bpy.context.evaluated_depsgraph_get()
def top(objects):
    return max((o.matrix_world @ Vector(v)).z for o in objects if o.type=='MESH' for v in o.evaluated_get(dg).bound_box)
highest=top(group.children_recursive)
# All controls stay at least 5 mm below the game's +0.0225 m steel surface.
if highest>.0175:
    group.location += front.rotation_euler.to_matrix().inverted() @ Vector((0,0,.0175-highest))
bpy.context.view_layer.update()
print('CONTROL_TOP',top(group.children_recursive),'CONTROL_SCALE',tuple(bpy.data.objects['PowerKnob'].matrix_world.to_scale()))
# Replace five disconnected rolled edges with ONE connected U-shaped tube.
for name in ['RearRolledCap','LeftGuardRolledEdge','LeftGuardUpperEdge','RightGuardRolledEdge','RightGuardUpperEdge','SplashguardContinuousRim']:remove(name)
points=[(-.904,.20,.042),(-.904,.345,.094),(-.904,.482,.094),(.904,.482,.094),(.904,.345,.094),(.904,.20,.042)]
curve=bpy.data.curves.new('Continuous splash rim','CURVE');curve.dimensions='3D';curve.resolution_u=1
curve.bevel_depth=.007;curve.bevel_resolution=3;curve.use_fill_caps=True
poly=curve.splines.new('POLY');poly.points.add(len(points)-1)
for pt,co in zip(poly.points,points):pt.co=(*co,1)
o=bpy.data.objects.new('SplashguardContinuousRim',curve);asset.objects.link(o);o.parent=root;curve.materials.append(steel)
bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
mesh=bpy.data.meshes.new_from_object(o.evaluated_get(dg),depsgraph=dg)
bpy.data.objects.remove(o,do_unlink=True)
rim=bpy.data.objects.new('SplashguardContinuousRim',mesh);asset.objects.link(rim);rim.parent=root
for face in mesh.polygons:face.use_smooth=True
# Compact inset drip drawer with a flatter, correctly scaled pull.
for o in list(asset.objects):
    if o.name.startswith('DrawerHandleMount') or o.name.startswith('DrawerFastener'):remove(o.name)
box('GreaseDrawerFrame',(-.49,0,.011),(.296,.044,.006),dark,.006)
box('GreaseDrawer',(-.49,0,.016),(.280,.036,.007),steel,.004)
for x in [-.550,-.430]:box('DrawerHandleMount'+str(x),(x,-.005,.025),(.012,.014,.012),dark,.003)
box('GreaseDrawerHandle',(-.49,-.005,.033),(.146,.009,.012),dark,.0035)
label=bpy.data.objects['DrawerLabel'];label.location=(-.49,.010,.021);label.data.size=.0065
for x in [-.620,-.360]:
    bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=.0025,depth=.0015)
    o=bpy.context.object;link(o);o.name='DrawerFastener'+str(x);o.parent=front;o.location=(x,0,.021);o.data.materials.append(dark)
# Flush vent slots replace the oversized proud teeth.
for o in list(asset.objects):
    if o.name.startswith('CoolingVent') or o.name.startswith('VentHighlight') or o.name=='VentPanel':remove(o.name)
box('VentPanel',(.537,0,.009),(.256,.036,.003),charcoal,.005)
for i in range(7):
    x=.435+i*.034
    box('CoolingVent_%02d'%i,(x,0,.011),(.012,.023,.0018),dark,.004)
    box('VentHighlight_%02d'%i,(x,.010,.012),(.009,.0012,.001),steel,.0004)
s['compact_revision']=4
s['design']='Charcoal grill; control assembly reduced 30 percent and lowered below steel; continuous splash rim; inset drawer and flush vent slots.'
s['control_scale_relative_to_original']=1.26
s['control_clearance_m']=.005
bpy.ops.wm.save_as_mainfile(filepath=str(p/'stylized_grill.blend'))
exec(compile((p/'export_stylized_grill.py').read_text(encoding='utf-8'),str(p/'export_stylized_grill.py'),'exec'))
bpy.ops.object.select_all(action='DESELECT');body=bpy.data.objects['EnamelBody'];body.select_set(True);bpy.context.view_layer.objects.active=body
bpy.ops.wm.save_as_mainfile(filepath=str(p/'stylized_grill.blend'))
print('REVISION_4_SAVED')
