import bpy, math
from pathlib import Path
from mathutils import Vector
p=Path('C:/Users/joe/Desktop/burgergame/assets/machines')
s=bpy.context.scene;s.frame_set(1)
asset=bpy.data.collections['GRILL | Export']
root=bpy.data.objects['StylizedGrill'];front=bpy.data.objects['ControlPanelMount']
def remove(name):
    o=bpy.data.objects.get(name)
    if o:bpy.data.objects.remove(o,do_unlink=True)
def material(prefix):return next(m for m in bpy.data.materials if m.name.startswith(prefix))
charcoal=material('Enamel');charcoal.name='Enamel | charcoal graphite';charcoal.diffuse_color=(.028,.039,.052,1)
bs=charcoal.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=charcoal.diffuse_color;bs.inputs['Metallic'].default_value=.40;bs.inputs['Roughness'].default_value=.34
steel=material('Satin stainless');dark=material('Charcoal');brass=material('Champagne');cream=material('Warm ivory')
amber=material('Amber')
amber.node_tree.nodes.get('Principled BSDF').inputs['Emission Color'].default_value=(1,.19,.006,1)
amber.node_tree.nodes.get('Principled BSDF').inputs['Emission Strength'].default_value=.6
def box(name,loc,dim,mat,bev=.005,parent=front):
    remove(name);bpy.ops.mesh.primitive_cube_add(size=1)
    o=bpy.context.object
    for c in list(o.users_collection):c.objects.unlink(o)
    asset.objects.link(o);o.name=name;o.parent=parent;o.location=loc;o.dimensions=dim
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.data.materials.append(mat)
    b=o.modifiers.new('Rounded edges','BEVEL');b.width=bev;b.segments=3
    o.modifiers.new('Weighted normals','WEIGHTED_NORMAL');return o
# A distinct deeper center section with tapered shoulders supports the larger dial.
for name in ['ControlPod','ControlPodFace','ControlPodGasket']:remove(name)
# Eight-sided housing in fascia local coordinates, thickened downward around the knob.
profile=[(-.225,.026),(-.16,.078),(.16,.078),(.225,.026),(.225,-.026),(.16,-.095),(-.16,-.095),(-.225,-.026)]
vs=[(x,y,z) for z in [-.022,.028] for x,y in profile];N=8
faces=[tuple(range(N-1,-1,-1)),tuple(range(N,2*N))]+[(i,(i+1)%N,(i+1)%N+N,i+N) for i in range(N)]
mesh=bpy.data.meshes.new('ControlPodMesh');mesh.from_pydata(vs,[],faces);mesh.update()
pod=bpy.data.objects.new('ControlPod',mesh);asset.objects.link(pod);pod.parent=front;pod.location=(0,0,.012);mesh.materials.append(charcoal)
b=pod.modifiers.new('Rounded shoulders','BEVEL');b.width=.012;b.segments=4;pod.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
box('ControlPodGasket',(0,-.007,.042),(.355,.151,.008),dark,.023)
box('ControlPodFace',(0,-.007,.048),(.343,.140,.007),steel,.021)
# The dial is inset into the thicker face; keep its authored rotation and 1.8x scale.
dial=bpy.data.objects['DialMount'];dial.location=(0,-.006,.058);dial.scale=(1.8,1.8,1.8)
# OFF and ON legends moved to side positions on the plate, free of the rolled lip.
for name,x in [('OffLabel',-.059),('OnLabel',.059)]:
    o=bpy.data.objects[name];o.location=(x,-.008,.008);o.data.size=.0105
# Status lamp mounted visibly in the right shoulder of the center housing.
for name,loc in [
    ('PilotBezel',(.185,.018,.043)),('PowerIndicator',(.185,.018,.050)),
    ('PilotLabel',(.185,-.008,.044))]:
    bpy.data.objects[name].location=loc
bpy.data.objects['PilotLabel'].data.size=.009
# Rebuild the drawer proportions instead of squeezing the old details.
for o in list(asset.objects):
    if o.name.startswith('DrawerHandleMount'):remove(o.name)
box('GreaseDrawerFrame',(-.49,0,.012),(.324,.052,.007),dark,.007)
box('GreaseDrawer',(-.49,0,.018),(.306,.043,.009),steel,.006)
for x in [-.563,-.417]:box('DrawerHandleMount'+str(x),(x,-.006,.029),(.018,.019,.020),dark,.004)
box('GreaseDrawerHandle',(-.49,-.006,.041),(.172,.012,.016),dark,.006)
lab=bpy.data.objects['DrawerLabel'];lab.location=(-.49,.011,.024);lab.data.size=.008
# Keep each vent broad enough to read, clear of the fascia pinstripes.
for o in list(asset.objects):
    if o.name.startswith('CoolingVent') or o.name.startswith('VentHighlight'):remove(o.name)
for i in range(7):
    x=.435+i*.034
    box('CoolingVent_%02d'%i,(x,0,.010),(.015,.029,.004),dark,.005)
    box('VentHighlight_%02d'%i,(x+.007,0,.012),(.002,.024,.002),steel,.001)
# Center view/orbit on the model and exclude the oversized studio ground from framing.
bpy.context.view_layer.update()
for o in bpy.data.collections['STUDIO | Preview only'].objects:
    o.hide_set(True);o.hide_select=True
root.empty_display_size=.075
bpy.ops.object.select_all(action='DESELECT')
body=bpy.data.objects['EnamelBody'];body.hide_set(False);body.select_set(True);bpy.context.view_layer.objects.active=body
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            space=area.spaces.active;rv=space.region_3d
            rv.view_perspective='PERSP';rv.view_location=(0,0,.015);rv.view_distance=2.6
            rv.view_rotation=s.camera.rotation_euler.to_quaternion()
            space.clip_start=.001;space.clip_end=50
            space.shading.type='MATERIAL';space.overlay.show_floor=False
s['compact_revision']=3;s['design']='Charcoal slim body, short splashguards, thicker center control section, 1.8x rotary knob, amber heat LED.'
s['orbit_help']='Viewport centered on grill. Studio objects are hidden in viewport so Home does not frame a 200m ground plane. Numpad period frames selected body.'
root['description']='Compact charcoal flat-top with central reinforced rotary control and amber heat LED.'
# The original game origin is intentionally unchanged at the center of the cooking plane.
s.render.filepath=str(p/'stylized_grill_preview.png')
bpy.ops.wm.save_as_mainfile(filepath=str(p/'stylized_grill.blend'))
exec(compile((p/'export_stylized_grill.py').read_text(encoding='utf-8'),str(p/'export_stylized_grill.py'),'exec'))
# Exporter selects the root; restore the body as the intuitive orbit target.
bpy.ops.object.select_all(action='DESELECT');body.select_set(True);bpy.context.view_layer.objects.active=body
bpy.ops.wm.save_as_mainfile(filepath=str(p/'stylized_grill.blend'))
print('REFINED_COMPACT_GRILL_SAVED')
