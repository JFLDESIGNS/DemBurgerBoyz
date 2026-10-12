extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1280,720)
 var background=ColorRect.new();background.color=Color("349AC8");background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(background)
 var cover=ColorRect.new();cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(cover)
 var mat=ShaderMaterial.new();mat.shader=load("res://shaders/loading_circle_reveal.gdshader");cover.material=mat
 for progress in [0.0,.5,1.0]:
  mat.set_shader_parameter("progress",progress)
  await process_frame;await RenderingServer.frame_post_draw
  var img=root.get_texture().get_image()
  var center=img.get_pixel(640,360);var corner=img.get_pixel(4,4)
  if progress==0.0:assert(center.b<.02 and corner.b<.02)
  elif progress==.5:assert(center.b>.3 and corner.b<.02)
  else:assert(center.b>.3 and corner.b>.3)
 print("LOADING_CIRCLE_REVEAL_OK black start, transparent center, black exterior, full reveal")
 quit()
