import bpy, math
from pathlib import Path
from mathutils import Vector
p=Path('C:/Users/joe/Desktop/burgergame/assets/machines')
s=bpy.context.scene
assert bpy.data.collections.get('GRILL | Export'), 'Open stylized_grill.blend'
s.frame_set(1)
if s.get('compact_revision')!=2:
    for name in ['BrandName','BrandSubtitle','BrandBadge','SplashBadgeType','SplashBadge','SplashBadgeMount']:
        o=bpy.data.objects.get(name)
        if o:bpy.data.objects.remove(o,do_unlink=True)
    # Lower the rear guard and shorten both side returns to the rear 29 cm.
    rear=bpy.data.objects['RearSplashguard']
    rear.location.z=.0595
    for v in rear.data.vertices:v.co.z*=.5
    rear.modifiers[0].width=.007
    cap=bpy.data.objects['RearRolledCap'];cap.location.z=.097
    for v in cap.data.vertices:v.co.y*=.75;v.co.z*=.67
    cap.modifiers[0].width=.008
    stripe=bpy.data.objects['RearEnamelStripe'];stripe.location.z=.063
    for v in stripe.data.vertices:v.co.z*=.6
    for sign,label in [(-1,'Left'),(1,'Right')]:
        x=sign*.904;t=.013
        profile=[(.20,.023),(.49,.023),(.49,.092),(.345,.092),(.20,.042)]
        o=bpy.data.objects[label+'TaperedSplashguard']
        coords=[(x+dx,y,z) for dx in [-t/2,t/2] for y,z in profile]
        for v,co in zip(o.data.vertices,coords):v.co=co
        for name,a,b in [
            (label+'GuardRolledEdge',(x,.206,.042),(x,.345,.092)),
            (label+'GuardUpperEdge',(x,.345,.092),(x,.484,.092))]:
            o=bpy.data.objects[name];a=Vector(a);b=Vector(b)
            old_depth=max(v.co.z for v in o.data.vertices)-min(v.co.z for v in o.data.vertices)
            for v in o.data.vertices:v.co.z*=(b-a).length/old_depth;v.co.x*=.78;v.co.y*=.78
            o.location=(a+b)/2;o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
        for name in [label+'FootCollar-0.34',label+'FootCollar0.35']:
            o=bpy.data.objects[name];o.location.z=-.059
        for name in [label+'RubberFoot-0.34',label+'RubberFoot0.35']:
            o=bpy.data.objects[name];o.location.z=-.073
    for o in list(bpy.data.collections['GRILL | Export'].objects):
        if o.name.startswith('GuardRivet'):o.location.z=.067
    body=bpy.data.objects['EnamelBody'];body.location.z=-.026
    for v in body.data.vertices:v.co.z*=.54
    body.modifiers[0].width=.015
    bpy.data.objects['LowerShadowSeam'].location.z=-.051
    # Slim the fascia but retain a generous independent round rotary control.
    front=bpy.data.objects['ControlPanelMount'];front.location.z=-.024
    for o in list(front.children):
        if o.type=='MESH' and o.name not in ['PowerIndicator','PilotBezel']:
            for v in o.data.vertices:v.co.y*=.60
            o.location.y*=.60
        if o.name.startswith('GreaseDrawer') or o.name.startswith('DrawerHandleMount') or o.name=='DrawerLabel':
            o.location.x-=.405
        if o.name.startswith('CoolingVent') or o.name.startswith('VentHighlight'):
            o.location.x+=.315
    dial=bpy.data.objects['DialMount'];dial.location.x=0;dial.location.y=-.012;dial.location.z=.042;dial.scale=(1.8,1.8,1.8)
    bpy.data.objects['PowerLabel'].data.body='POWER'
    for name in ['PilotBezel','PowerIndicator','PilotLabel']:
        bpy.data.objects[name].location.x=.26
    for name in ['BrandName','BrandName.001','BrandSubtitle']:
        o=bpy.data.objects.get(name)
        if o and o in list(bpy.data.collections['GRILL | Export'].objects):bpy.data.objects.remove(o,do_unlink=True)
    # The modeled plate is only a Blender preview reference; game retains its original surface.
    bpy.data.objects['CookingSurface']['purpose']='Preview reference only; hidden in-game in favor of existing cooking surface.'
    s['compact_revision']=2
    s['design']='Compact body; short low splash returns; no branding; central 1.8x power dial.'
    s.name='Stylized Grill | Compact'
    bpy.data.objects['StylizedGrill']['description']='Compact stylized grill with short splash returns and oversized center power dial.'
    bpy.data.objects['PreviewGround'].location.z=-.116
# Comfortable material-preview framing.
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_perspective='CAMERA'
            area.spaces.active.region_3d.view_camera_zoom=15
            area.spaces.active.region_3d.view_camera_offset=(0,0)
            area.spaces.active.shading.type='MATERIAL'
s.render.filepath=str(p/'stylized_grill_preview.png')
bpy.ops.wm.save_as_mainfile(filepath=str(p/'stylized_grill.blend'))
exec(compile((p/'export_stylized_grill.py').read_text(encoding='utf-8'),str(p/'export_stylized_grill.py'),'exec'))
print('COMPACT_REVISION_SAVED')
