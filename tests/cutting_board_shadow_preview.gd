extends SceneTree
func _initialize():call_deferred("run")
func run():
	var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/main_ticket_harness.gd"));root.add_child(g);current_scene=g
	root.size=Vector2i(960,640);g.get_node("UI").hide()
	var counter=g._add_box(g.world,Vector3(4.65,.10,1.35),Vector3(0,1,.08),Color("101214"))
	counter.material_override.metallic=.32;counter.material_override.roughness=.62
	g._build_cutting_board_prop()
	var center:Vector3=g.build_cutting_board.global_position
	g.camera.look_at_from_position(center+Vector3(-.28,.67,-1.5),center-Vector3(0,.02,0))
	var light=DirectionalLight3D.new();g.world.add_child(light);light.rotation_degrees=Vector3(-45,-25,0);light.light_energy=1.4
	var env=WorldEnvironment.new();g.world.add_child(env);env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("41444A")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.65
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	var shadow:Image=root.get_texture().get_image()
	shadow.save_png("res://build/customer_polish_qa/cutting_board_shadow.png")
	g._cutting_board_shadow.hide()
	await process_frame;await RenderingServer.frame_post_draw
	var bare:Image=root.get_texture().get_image()
	var affected:=0
	for y in shadow.get_height():
		for x in shadow.get_width():
			if bare.get_pixel(x,y).get_luminance()-shadow.get_pixel(x,y).get_luminance()>.012:affected+=1
	assert(affected>300,"Blob shadow must visibly darken exposed counter pixels")
	print("BOARD_SHADOW_VISIBLE pixels=",affected);quit()
