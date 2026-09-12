import bpy, math
from pathlib import Path
from mathutils import Vector
P=Path('C:/Users/joe/Desktop/burgergame/assets/machines')
s=bpy.context.scene;s.frame_set(1)
asset=bpy.data.collections['GRILL | Export'];root=bpy.data.objects['StylizedGrill'];front=bpy.data.objects['ControlPanelMount']
def mat(prefix):return next(m for m in bpy.data.materials if m.name.startswith(prefix))
steel=mat('Satin stainless');dark=mat('Charcoal');bodymat=mat('Enamel')
def remove(o):
    if isinstance(o,str):o=bpy.data.objects.get(o)
    if o:bpy.data.objects.remove(o,do_unlink=True)
def link(o,c=asset):
    for old in list(o.users_collection):old.objects.unlink(o)
    c.objects.link(o)
def box(name,loc,size,m,bevel=.002,parent=front):
    remove(name);bpy.ops.mesh.primitive_cube_add(size=1)
    o=bpy.context.object;link(o);o.name=name;o.parent=parent;o.location=loc;o.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.data.materials.append(m)
    if bevel:
        b=o.modifiers.new('Edge softness','BEVEL');b.width=bevel;b.segments=2
        o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
    return o
# Remove micro geometry and decoration. Keep only the functional ON/OFF legends and pointer.
prefixes=('KnobGripRib_','DialTick_','DrawerFastener','FasciaScrew','ScrewSlot','GuardRivet','DrainSlot_','CoolingVent_','VentHighlight')
names={'FasciaUpperPinstripe','FasciaLowerPinstripe','DrawerLabel','PilotLabel','PowerLabel','RearEnamelStripe','KnobFace','VentPanel'}
removed=[]
for o in list(asset.all_objects):
    if o.name.startswith(prefixes) or o.name in names:
        removed.append(o.name);remove(o)
bpy.data.objects['KnobGrip'].location.z=.024
bpy.data.objects['KnobPointer'].location.z=.0325
# One metal finish; no tiny gold accent material.
for o in list(asset.all_objects):
    if o.type=='MESH':
        for slot in o.material_slots:
            if slot.material and slot.material.name.startswith('Champagne'):slot.material=steel
    for modifier in o.modifiers:
        if modifier.type=='BEVEL':modifier.segments=min(modifier.segments,2)
# Cut a REAL vent opening through the fascia, then set a dark back inside it.
fascia=bpy.data.objects['FrontControlFascia']
if not s.get('production_vents'):
    bpy.ops.object.select_all(action='DESELECT');fascia.select_set(True);bpy.context.view_layer.objects.active=fascia
    for mod in list(fascia.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
    cutter=box('TemporaryVentCut',(.54,0,0),(.288,.046,.09),dark,0)
    bpy.context.view_layer.update()
    mod=fascia.modifiers.new('Vent opening','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
    bpy.context.view_layer.objects.active=fascia;fascia.select_set(True);cutter.select_set(False)
    bpy.ops.object.modifier_apply(modifier=mod.name);remove(cutter)
    s['production_vents']=True
box('VentRecess',(.54,0,-.007),(.288,.046,.003),dark,.003)
# Three broad, sloped louvers read cleanly at game-camera distance.
for o in list(asset.all_objects):
    if o.name.startswith('VentLouver'):remove(o)
for i,y in enumerate([-.015,0,.015]):
    o=box('VentLouver_%02d'%(i+1),(.54,y,.001),(.270,.007,.004),steel,.0013)
    o.rotation_euler.x=math.radians(-22)
# Move the original-game plate to a clearly marked reference collection, excluded from GLB.
reference=bpy.data.collections.get('REFERENCE | Game cooking surface')
if reference is None:
    reference=bpy.data.collections.new('REFERENCE | Game cooking surface');s.collection.children.link(reference)
plate=bpy.data.objects.get('CookingSurface')
if plate:
    link(plate,reference);plate.hide_select=True
    plate['export']=False;plate['purpose']='Existing game cooking plane for Blender preview only. Not included in GLB.'
    # Remove unused texture nodes; the reference uses a simple portable material.
    for m in plate.data.materials:
        if m and m.use_nodes:
            for node in list(m.node_tree.nodes):
                if node.type not in {'BSDF_PRINCIPLED','OUTPUT_MATERIAL'}:m.node_tree.nodes.remove(node)
# Clear source hierarchy: category collections and named assembly parents.
groups={}
for name in ['01 | Body','02 | Splashguards','03 | Grease drawer','04 | Ventilation','05 | Power control','06 | Feet']:
    c=bpy.data.collections.get(name)
    if c is None:c=bpy.data.collections.new(name);asset.children.link(c)
    groups[name]=c
assemblies={}
for name in ['BodyAssembly','SplashguardAssembly','GreaseDrawerAssembly','VentAssembly','FeetAssembly']:
    o=bpy.data.objects.get(name)
    if o is None:o=bpy.data.objects.new(name,None);asset.objects.link(o);o.parent=root
    o.empty_display_size=.03;assemblies[name]=o
def category(o):
    name=o.name
    if name.startswith(('GreaseDrawer','DrawerHandle')):return '03 | Grease drawer','GreaseDrawerAssembly'
    if name.startswith('Vent'):return '04 | Ventilation','VentAssembly'
    if any(t in name for t in ['Splash','Guard']) or name.startswith('Rear'):return '02 | Splashguards','SplashguardAssembly'
    if 'Foot' in name:return '06 | Feet','FeetAssembly'
    # Control hierarchy descendants retain the original pivots and orientation.
    control=bpy.data.objects.get('ControlAssembly')
    if o==control or (control is not None and o in control.children_recursive):return '05 | Power control',None
    if name in ['PowerKnob','DialMount']:return '05 | Power control',None
    return '01 | Body','BodyAssembly'
bpy.context.view_layer.update()
for o in list(asset.all_objects):
    if o==root or o in assemblies.values():continue
    key,assembly=category(o);link(o,groups[key])
    if assembly and o.parent in [root,front]:
        world=o.matrix_world.copy();o.parent=assemblies[assembly];o.matrix_world=world
for name,key in [('BodyAssembly','01 | Body'),('SplashguardAssembly','02 | Splashguards'),('GreaseDrawerAssembly','03 | Grease drawer'),('VentAssembly','04 | Ventilation'),('FeetAssembly','06 | Feet')]:
    link(assemblies[name],groups[key])
for o in asset.all_objects:
    if o.type=='MESH':o.data.name=o.name+'_Mesh'
# Keep stage separate and unavailable to selection / frame-all.
for o in bpy.data.collections['STUDIO | Preview only'].objects:o.hide_set(True);o.hide_select=True
s.unit_settings.system='METRIC';s.unit_settings.length_unit='METERS'
s.name='Grill | Game Asset';root['asset_version']='1.0';root['forward']='Godot -Z';root['units']='meters'
root['origin']='Center of existing cooking plane; align with GRILL_SURFACE_Y. Existing game surface top is +0.0225m.'
s['production_revision']=5
s['design']='Game asset: clean charcoal body, continuous steel splash rim, inset drawer, 3 recessed louvers, animated power control.'
bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT');bpy.data.objects['EnamelBody'].select_set(True);bpy.context.view_layer.objects.active=bpy.data.objects['EnamelBody']
bpy.ops.wm.save_as_mainfile(filepath=str(P/'stylized_grill.blend'))
print('REMOVED_MICRO_OBJECTS',len(removed))
print('SOURCE_OBJECTS',len(asset.all_objects))
