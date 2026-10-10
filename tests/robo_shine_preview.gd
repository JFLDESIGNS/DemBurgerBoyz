extends SceneTree
func _initialize(): call_deferred("run")
func run():
	root.size=Vector2i(800,600)
	var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/main_ticket_harness.gd"));root.add_child(g);current_scene=g
	g.get_node("UI").hide()
	g.roomba_home_pos=Vector3.ZERO
	g._build_grill_roomba()
	g.grill_roomba_root.show();g.grill_roomba_root.position=Vector3.ZERO
	var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.7;g.add_child(env)
	var light=DirectionalLight3D.new();g.add_child(light);light.rotation_degrees=Vector3(-45,-25,0)
	g.camera.position=Vector3(.24,.4,-.38);g.camera.look_at(Vector3.ZERO)
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	var first=root.get_texture().get_image()
	first.save_png("res://build/customer_polish_qa/robo_shine.png")
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	var second=root.get_texture().get_image()
	assert(first.get_data()==second.get_data(),"Top shine must stay still when robot is stationary")
	g.grill_roomba_root.rotation.y += .8
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	var turned=root.get_texture().get_image()
	assert(first.get_data()!=turned.get_data(),"Shine must respond to robot rotation")
	assert(g.world.has_node("RoboChefChargingPad/DockLight"))
	assert(g.grill_roomba_root.has_node("DynamicToonTopShine"))
	assert(not g.grill_roomba_root.has_node("ToonTopReflection0"))
	print("ROBO_SHINE_OK: stationary frames match, rotation changes reflection, charging pad present")
	quit()
