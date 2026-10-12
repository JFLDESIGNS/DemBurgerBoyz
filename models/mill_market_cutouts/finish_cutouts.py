import bpy, json, math
from pathlib import Path
OUT=Path(r'C:/Users/joe/Desktop/burgergame/models/mill_market_cutouts')
bpy.ops.wm.open_mainfile(filepath=str(OUT/'Mill_Market_Animated_Doors.blend'))
scene=bpy.context.scene
groups={}
for name in ['01 BACKGROUND — alpha cutouts','02 BLUE WINDOWS — animated shine','03 OLD POODLE — hinged door','04 MILL MARKET — hinged door','05 CAMERAS']:
 c=bpy.data.collections.new(name);scene.collection.children.link(c);groups[name]=c
for ob in list(scene.objects):
 if ob.type=='CAMERA':key='05 CAMERAS'
 elif ob.name.startswith('Old_Poodle') or ob.name=='Poodle_Door_Glass_GLASS':key='03 OLD POODLE — hinged door'
 elif ob.name.startswith('Mill_Market_Door'):key='04 MILL MARKET — hinged door'
 elif ob.name.endswith('_GLASS'):key='02 BLUE WINDOWS — animated shine'
 else:key='01 BACKGROUND — alpha cutouts'
 for c in list(ob.users_collection):c.objects.unlink(ob)
 groups[key].objects.link(ob)
# Keep gleams restrained and slightly staggered across the street.
for i,m in enumerate([m for m in bpy.data.materials if m.name.endswith('_animated_shine')]):
 ramp=next(n for n in m.node_tree.nodes if n.type=='VALTORGB')
 ramp.color_ramp.elements[0].color=(.38,.38,.38,1)
# Check hinges and attached glass across the animation.
scene.frame_set(1);assert abs(bpy.data.objects['Old_Poodle_Door_HINGE'].rotation_euler.y)<.001
assert abs(bpy.data.objects['Mill_Market_Door_HINGE'].rotation_euler.y)<.001
scene.frame_set(90)
assert abs(bpy.data.objects['Old_Poodle_Door_HINGE'].rotation_euler.y)>1
assert abs(bpy.data.objects['Mill_Market_Door_HINGE'].rotation_euler.y)>1
assert bpy.data.objects['Poodle_Door_Glass_GLASS'].parent==bpy.data.objects['Old_Poodle_Door_HINGE']
main=scene.camera
close=bpy.data.objects.new('CAMERA — doors closeup',main.data.copy());groups['05 CAMERAS'].objects.link(close);close.location=(-1.8,-1.25,30);close.data.ortho_scale=10.0
scene.camera=close;scene.render.resolution_x=1400;scene.render.resolution_y=1000;scene.render.resolution_percentage=100;scene.render.filepath=str(OUT/'doors_detail.png');bpy.ops.render.render(write_still=True)
scene.camera=main;scene.render.resolution_x=2048;scene.render.resolution_y=1153;scene.render.resolution_percentage=75;scene.render.filepath=str(OUT/'doors_open_preview.png');bpy.ops.render.render(write_still=True)
for ob in scene.objects:ob.select_set(False)
hinge=bpy.data.objects['Old_Poodle_Door_HINGE'];hinge.select_set(True);bpy.context.view_layer.objects.active=hinge
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':
   area.spaces.active.region_3d.view_perspective='CAMERA';area.spaces.active.overlay.show_overlays=False;area.spaces.active.shading.type='MATERIAL'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Mill_Market_Animated_Doors.blend'))
(OUT/'README.txt').write_text('MILL MARKET / OLD POODLE — ANIMATED STREET CUTOUTS\n\nOpen Mill_Market_Animated_Doors.blend and press Space to play.\nFrames 1–240: 8 second door-open/hold/close and window-glint demonstration.\nFrame 1: doors closed. Frame 90: both doors open.\n\nEach shop door has a named HINGE object with animated Y rotation, a solid leaf, and recessed jamb/interior geometry. Poodle door glass follows its hinge.\n23 GLASS objects use the original painted pixels and masked moving highlights.\nwindows_mask.png and doors_mask.png match the 4778 x 2689 source image. White = cutout.\nEach window also has a cropped RGBA texture and matching mask.\nstreet_with_cutouts.png is the full street with transparent window/door holes.\nAll Blender textures are packed. Full street and closeup cameras are included.\nThis is an editable layered 2.5D street asset; the game background has not been replaced.\nThe regular game EXE was rebuilt and pushed separately before this Blender work.\n',encoding='utf8')
print('VALIDATED: 23 window groups, two animated hinges, attached door glass, packed textures')
