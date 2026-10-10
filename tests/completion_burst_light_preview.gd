extends SceneTree
func _initialize():call_deferred("run")
func run():
	root.size=Vector2i(900,600);root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/main_ticket_harness.gd"));root.add_child(g);current_scene=g;g.get_node("UI").hide()
	var canvas:=CanvasLayer.new();root.add_child(canvas)
	var burst=g._make_burger_completion_burst();canvas.add_child(burst);burst.position=Vector2(450,280);burst.show();g._update_burger_completion_burst(burst,.30)
	for child in burst.get_children():assert(not (child is Line2D and child.closed),"Burst must not have a dark contour")
	var patty:=TextureRect.new();patty.texture=load("res://scripts/food_sprites.gd").build_patty_state_tex(0,true);patty.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;patty.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;patty.position=Vector2(345,215);patty.size=Vector2(210,130);canvas.add_child(patty)
	var light=load("res://scripts/burger_completion_light.gd").new();g.world.add_child(light)
	light.pulse(Vector3(0,.35,0),.75);light.set_process(false)
	light._process(.12);assert(light.visible and light.light_energy>3)
	light._process(.18);assert(light.light_energy<2)
	light._process(.5);assert(not light.visible and light.light_energy==0)
	light.pulse(Vector3.ZERO,.75);light.stop();assert(not light.visible)
	for i in 8:await process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/customer_polish_qa/completion_burst_preview.png")
	print("COMPLETION_BURST_LIGHT_OK: outline-free burst, real light peak/settle/fade and cleanup")
	quit()
