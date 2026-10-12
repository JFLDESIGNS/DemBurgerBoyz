import bpy
from pathlib import Path
OUT=Path(r'C:/Users/joe/Desktop/burgergame/models/mill_market_cutouts')
loaded={}
for mat in bpy.data.materials:
 if not mat.use_nodes:continue
 for node in mat.node_tree.nodes:
  if node.type!='TEX_IMAGE' or not node.image:continue
  path=Path(bpy.path.abspath(node.image.filepath_raw))
  if not path.exists():continue
  if str(path) not in loaded:
   fresh=bpy.data.images.load(str(path),check_existing=False);fresh.pack();loaded[str(path)]=fresh
  node.image=loaded[str(path)]
s=bpy.context.scene;s.frame_set(90)
s.camera=bpy.data.objects['CAMERA — doors closeup'];s.render.resolution_x=1600;s.render.resolution_y=1000;s.render.resolution_percentage=85;s.render.filepath=str(OUT/'revised_doors_detail.png');bpy.ops.render.render(write_still=True)
s.camera=bpy.data.objects['CAMERA — full street'];s.render.resolution_x=2048;s.render.resolution_y=1153;s.render.resolution_percentage=75;s.render.filepath=str(OUT/'revised_street_preview.png');bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Mill_Market_Animated_Doors.blend'))
print('REFRESHED_PACKED_TEXTURES',len(loaded))
