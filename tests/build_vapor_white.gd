extends SceneTree
func _initialize(): call_deferred("run")
func run():
 root.size=Vector2i(256,256)
 var g=load("res://scenes/main.tscn").instantiate()
 g.set_script(load("res://tests/main_ticket_harness.gd"));root.add_child(g);current_scene=g
 g.get_node("UI").hide()
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 root.content_scale_size=Vector2i.ZERO
 var bg:=ColorRect.new();bg.color=Color(.4,.2,.1);bg.size=Vector2(256,256);root.add_child(bg)
 var heat=load("res://scripts/build_patty_heat.gd").new()
 root.add_child(heat);heat.setup(g,null);heat.set_process(false)
 heat.size=Vector2(256,256)
 var viewport=heat._make_view(g)
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 heat.texture=viewport.get_texture()
 for i in 12: await process_frame
 await RenderingServer.frame_post_draw
 var img=root.get_texture().get_image()
 var base=img.get_pixel(0,255)
 var lit:=0
 for y in 256:
  for x in 256:
   var c=img.get_pixel(x,y)
   assert(c.r>=base.r-.005 and c.g>=base.g-.005 and c.b>=base.b-.005,"Steam must never darken the background")
   if c.b>base.b+.015: lit+=1
 assert(lit>100,"White steam must remain visible")
 img.save_png("res://build/customer_polish_qa/white_build_steam.png")
 print("WHITE_BUILD_STEAM_OK: visible steam never darkens background")
 quit()
