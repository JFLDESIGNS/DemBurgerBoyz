import bpy, math
from mathutils import Vector
from pathlib import Path
ROOT=Path('C:/Users/joe/Desktop/burgergame')
OUT=ROOT/'assets/machines'
scene=bpy.data.scenes.new('SIZZLE 86 | Stylized flat-top')
bpy.context.window.scene=scene
asset=bpy.data.collections.new('GRILL | Export')
scene.collection.children.link(asset)
studio=bpy.data.collections.new('STUDIO | Preview only')
scene.collection.children.link(studio)
def move(o,collection=asset):
    for c in list(o.users_collection): c.objects.unlink(o)
    collection.objects.link(o)
    return o
def mat(name,color,metal=0,rough=.4):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Metallic'].default_value=metal; p.inputs['Roughness'].default_value=rough
    return m
teal=mat('Enamel | deep diner teal',(.018,.23,.20),.32,.28)
steel=mat('Satin stainless | rolled edges',(.53,.61,.62),.72,.29)
plate=mat('Seasoned steel | cooking surface',(.23,.25,.24),.62,.43)
dark=mat('Charcoal | seals and vents',(.014,.023,.027),.15,.52)
red=mat('Vermilion | power knob',(.72,.057,.022),.15,.29)
cream=mat('Warm ivory | legends',(.95,.84,.59),.1,.4)
brass=mat('Champagne | trim and badge',(.71,.40,.13),.67,.29)
amber=mat('Amber | power indicator',(.9,.24,.016),.15,.25)
rubber=mat('Rubber | nonslip feet',(.013,.016,.018),0,.75)
def empty(name,loc=(0,0,0),parent=None):
    o=bpy.data.objects.new(name,None); asset.objects.link(o); o.location=loc; o.parent=parent; return o
root=empty('StylizedGrill')
root['description']='SIZZLE 86 | burger-truck flat-top. Origin matches original grill surface.'
root['cook_surface_z']=.0225
root['godot_front']='-Z (root rotates 180 degrees for matching original grill)'
def finish(o,name,m,parent=None,bevel=0):
    move(o); o.name=name; o.parent=parent or root
    if m:o.data.materials.append(m)
    if bevel:
        b=o.modifiers.new('Soft manufactured edges','BEVEL'); b.width=bevel;b.segments=3
        b=o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL');b.keep_sharp=True;b.weight=50
    return o
def box(name,loc,dim,m,bevel=.005,parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc)
    o=bpy.context.object;o.dimensions=dim;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,m,parent,bevel)
def cyl(name,loc,radius,depth,m,parent=None,rot=None,verts=48):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=radius,depth=depth,location=loc)
    o=finish(bpy.context.object,name,m,parent,min(.002,depth*.2))
    if rot:o.rotation_euler=rot
    for p in o.data.polygons:p.use_smooth=len(p.vertices)==4
    return o
def text(name,body,loc,size,m,parent=None,rotation=(0,0,0)):
    c=bpy.data.curves.new(name,'FONT');c.body=body;c.align_x='CENTER';c.align_y='CENTER';c.size=size;c.extrude=0;c.bevel_depth=0;c.resolution_u=3
    o=bpy.data.objects.new(name,c);asset.objects.link(o);o.location=loc;o.rotation_euler=rotation;o.parent=parent or root;c.materials.append(m);return o
def rod(name,a,b,r,m,parent=None):
    a,b=Vector(a),Vector(b)
    o=cyl(name,(a+b)*.5,r,(b-a).length,m,parent,verts=16)
    o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o
box('EnamelBody',(0,0,-.047),(1.825,.985,.092),teal,.022)
box('LowerShadowSeam',(0,0,-.09),(1.81,.97,.014),dark,.007)
box('SteelPerimeter',(0,0,-.004),(1.846,1.01,.028),steel,.009)
box('CookingSurface',(0,0,0),(1.786,.95,.045),plate,.008)
# Very subtle real stainless texture; portable in the GLB and packed in the blend.
texpath=OUT/'grill_stainless_steel.png'
if texpath.exists():
    im=bpy.data.images.load(str(texpath),check_existing=True)
    p=plate.node_tree.nodes.get('Principled BSDF');n=plate.node_tree.nodes.new('ShaderNodeTexImage');n.image=im
    # Keep the art-directed graphite color, use grain only for micro-normal.
    bump=plate.node_tree.nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.12;bump.inputs['Distance'].default_value=.00018
    plate.node_tree.links.new(n.outputs['Color'],bump.inputs['Height']);plate.node_tree.links.new(bump.outputs['Normal'],p.inputs['Normal'])
# Far splash wall and rolled cap.
box('RearSplashguard',(0,.485,.095),(1.824,.025,.148),steel,.012)
box('RearRolledCap',(0,.484,.169),(1.84,.032,.024),steel,.012)
box('RearEnamelStripe',(0,.500,.109),(1.70,.009,.032),teal,.006)
# Tapered side guards: nearly flat at front, taller at rear.
for sign,label in [(-1,'Left'),(1,'Right')]:
    x=sign*.904;t=.013
    profile=[(-.36,.023),(.49,.023),(.49,.164),(.22,.164),(-.36,.052)]
    vs=[(x+dx,y,z) for dx in [-t/2,t/2] for y,z in profile]
    N=len(profile);faces=[tuple(range(N-1,-1,-1)),tuple(range(N,N*2))]+[(i,(i+1)%N,(i+1)%N+N,i+N) for i in range(N)]
    me=bpy.data.meshes.new(label+' guard');me.from_pydata(vs,[],faces);me.update()
    o=bpy.data.objects.new(label+'TaperedSplashguard',me);asset.objects.link(o);o.parent=root;me.materials.append(steel)
    mod=o.modifiers.new('Rounded guard edges','BEVEL');mod.width=.006;mod.segments=3
    o.modifiers.new('Guard normals','WEIGHTED_NORMAL')
    rod(label+'GuardRolledEdge',(x,-.352,.052),(x,.22,.164),.009,steel)
    rod(label+'GuardUpperEdge',(x,.22,.164),(x,.484,.164),.009,steel)
    for y in [-.34,.35]:
        cyl(label+'FootCollar'+str(y),(sign*.80,y,-.099),.031,.018,steel)
        cyl(label+'RubberFoot'+str(y),(sign*.80,y,-.113),.032,.016,rubber)
# Front grease gutter, below the uninterrupted usable cooking rectangle.
box('GreaseGutterShadow',(0,-.486,.012),(1.72,.019,.008),dark,.004)
box('FrontRolledLip',(0,-.510,.008),(1.83,.015,.018),steel,.007)
for i in range(7):
    box('DrainSlot_%02d'%i,(.56+i*.025,-.486,.017),(.014,.012,.002),dark,.003)
# Sloping control panel makes the small controls visible from the game camera.
front=empty('ControlPanelMount',(0,-.497,-.044),root);front.rotation_euler.x=math.radians(65)
box('FrontControlFascia',(0,0,0),(1.795,.104,.016),teal,.011,front)
box('FasciaUpperPinstripe',(0,.043,.009),(1.69,.003,.003),brass,.001,front)
box('FasciaLowerPinstripe',(0,-.043,.009),(1.69,.002,.003),brass,.001,front)
# Legible diner branding.
box('BrandBadge',(-.57,0,.011),(.36,.065,.007),dark,.018,front)
text('BrandName','S I Z Z L E  8 6',(-.57,.010,.016),.027,cream,front)
text('BrandSubtitle','BURGER PALS  /  FLAT TOP',(-.57,-.019,.016),.010,brass,front)
# Pull-out drip drawer with a separate handle.
box('GreaseDrawerFrame',(-.075,-.008,.012),(.34,.070,.009),dark,.009,front)
box('GreaseDrawer',(-.075,-.008,.018),(.326,.059,.011),steel,.008,front)
for x in [-.157,.007]:box('DrawerHandleMount'+str(x),(x,-.009,.031),(.020,.025,.026),dark,.005,front)
box('GreaseDrawerHandle',(-.075,-.009,.047),(.195,.018,.023),dark,.008,front)
text('DrawerLabel','D R I P',(-.075,.012,.026),.010,dark,front)
# Louvers with softly rounded stamped edges.
for i in range(6):
    x=.185+i*.032
    box('CoolingVent_%02d'%i,(x,-.003,.010),(.012,.052,.004),dark,.005,front)
    box('VentHighlight_%02d'%i,(x+.006,-.003,.012),(.002,.042,.002),steel,.001,front)
# Rotary control, grouped around an actual axial pivot.
dial=empty('DialMount',(.64,0,.014),front)
cyl('DialBezel',(0,0,0),.048,.009,brass,dial)
cyl('DialInset',(0,0,.006),.042,.009,dark,dial)
knob=empty('PowerKnob',(0,0,.015),dial)
cyl('KnobBody',(0,0,.008),.032,.023,red,knob)
cyl('KnobFace',(0,0,.021),.029,.007,red,knob)
box('KnobGrip',(0,0,.030),(.012,.050,.015),red,.006,knob)
box('KnobPointer',(0,.018,.039),(.004,.014,.002),cream,.001,knob)
for i in range(20):
    a=i*math.tau/20
    o=box('KnobGripRib_%02d'%i,(math.sin(a)*.031,math.cos(a)*.031,.008),(.004,.004,.016),red,.001,knob)
for i in range(9):
    a=math.radians(-52+i*13)
    x=math.sin(a)*.055;y=math.cos(a)*.055
    o=box('DialTick_%02d'%i,(x,y,.006),(.002,.006 if i in [0,8] else .003,.001),cream,.0004,dial)
    o.rotation_euler.z=-a
text('OffLabel','OFF',(-.063,.008,.008),.012,cream,dial)
text('OnLabel','ON',(.063,.008,.008),.012,cream,dial)
text('PowerLabel','POWER',(0,-.055,.008),.009,cream,dial)
cyl('PilotBezel',(.782,.018,.015),.012,.009,brass,front)
cyl('PowerIndicator',(.782,.018,.022),.0085,.008,amber,front)
text('PilotLabel','HEAT',(.782,-.010,.012),.009,cream,front)
# Captive screws at fascia corners.
for x in [-.861,.861]:
    cyl('FasciaScrew'+str(x),(x,0,.012),.006,.004,steel,front,verts=24)
    box('ScrewSlot'+str(x),(x,0,.015),(.008,.0015,.001),dark,.0004,front)
# Small center badge on the splash wall.
back=empty('SplashBadgeMount',(0,.467,.111),root);back.rotation_euler.x=math.pi/2
box('SplashBadge',(0,0,0),(.205,.044,.006),teal,.018,back)
text('SplashBadgeType','SIZZLE / 86',(0,0,.005),.021,cream,back)
for x in [-.79,.79]:
    cyl('GuardRivet'+str(x),(x,.469,.131),.006,.004,brass,root,(math.pi/2,0,0),24)
# Animate the actual rotary group, from left OFF to right ON.
knob.rotation_euler.z=math.radians(45);knob.keyframe_insert(data_path='rotation_euler',frame=1)
knob.rotation_euler.z=math.radians(-45);knob.keyframe_insert(data_path='rotation_euler',frame=16)
knob.animation_data.action.name='Power_OFF_to_ON'
scene.frame_start=1;scene.frame_end=16;scene.render.fps=30
scene.timeline_markers.new('OFF',frame=1);scene.timeline_markers.new('ON',frame=16)
scene.frame_set(1)
# Rotate entire assembly to the game's original front direction.
root.rotation_euler.z=math.pi
# Studio, kept separate from game export.
floor=box('PreviewGround',(0,0,-.133),(200,200,.02),mat('Studio sand',(.11,.145,.16),0,.78),0)
floor.parent=None;move(floor,studio)
def aim(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(2.0,2.7,1.85));camera=bpy.context.object;move(camera,studio);camera.name='PreviewCamera';aim(camera,(0,0,.035));camera.data.type='ORTHO';camera.data.ortho_scale=2.65;scene.camera=camera
def light(name,loc,power,size,color):
    bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;move(o,studio);o.name=name;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.data.color=color;aim(o,(0,0,0))
light('Key softbox',(1.1,1.5,3.2),260,3.0,(1,.84,.65))
light('Cool fill',(-2,1,1.3),190,2.4,(.65,.82,1))
light('Back steel rim',(.5,-2,2.2),330,2.0,(1,.93,.77))
scene.world=bpy.data.worlds.new('Studio World');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.22,.27,.32,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.4
scene.render.engine='CYCLES';scene.cycles.samples=48;scene.cycles.use_denoising=True
scene.render.resolution_x=1600;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
scene.render.image_settings.file_format='PNG';scene.render.filepath=str(OUT/'stylized_grill_preview.png')
scene['integration']='Origin at original GRILL_SURFACE_Y; cook top is +0.0225 m. Godot front -Z. Runtime retains original heat-zone panels and overlays; hide CookingSurface in runtime.'
scene['controls']='PowerKnob rotates about local Z: OFF +45deg, ON -45deg. Frames 1 / 16.'
# Ensure startup view presents the grill.
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_perspective='CAMERA'
            area.spaces.active.shading.type='MATERIAL'
bpy.ops.object.select_all(action='DESELECT');root.select_set(True);bpy.context.view_layer.objects.active=root
# Write only this scene and its dependencies, preserving the pre-existing truck project.
for im in bpy.data.images:
    if im.name=='grill_stainless_steel.png' and not im.packed_file:im.pack()
bpy.data.libraries.write(str(OUT/'stylized_grill.blend'),{scene},fake_user=True,compress=True)
print('CREATED',len(asset.objects),'asset objects; saved isolated stylized_grill.blend')

# Finalize a standalone source project after writing the isolated scene.
bpy.ops.wm.open_mainfile(filepath=str(OUT/"stylized_grill.blend"))
bpy.context.window.scene=bpy.data.scenes["SIZZLE 86 | Stylized flat-top"]
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/"stylized_grill.blend"))
