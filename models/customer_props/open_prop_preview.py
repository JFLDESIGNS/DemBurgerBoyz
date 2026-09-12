import bpy
from mathutils import Vector
def frame_preview():
 s=bpy.data.scenes.get('CHARACTER PREVIEWS | Refined six')
 if s:
  for w in bpy.context.window_manager.windows:
   w.scene=s
   for ar in w.screen.areas:
    if ar.type=='VIEW_3D':
     sp=ar.spaces.active;sp.shading.type='MATERIAL';sp.overlay.show_overlays=False
     rv=sp.region_3d;rv.view_perspective='ORTHO';rv.view_location=Vector((0,0,1.55));rv.view_distance=11;rv.view_rotation=s.camera.rotation_euler.to_quaternion()
 return None
bpy.app.timers.register(frame_preview,first_interval=1)
