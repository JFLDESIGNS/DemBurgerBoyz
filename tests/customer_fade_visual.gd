extends SceneTree
func _initialize():call_deferred("run")
func run():
	var camera=Camera3D.new();root.add_child(camera)
	camera.position=Vector3(0,1.2,-4);camera.look_at(Vector3(0,1.0,0));camera.current=true
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=3.2
	var env=WorldEnvironment.new();env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("374459")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.8;root.add_child(env)
	var light=DirectionalLight3D.new();root.add_child(light);light.rotation_degrees=Vector3(-35,30,0)
	var order:Array[String]=["bun_bottom","patty","bun_top"]
	var customer_script=load("res://scripts/customer.gd")
	customer_script.ensure_saved_character_files()
	var preset=customer_script.take_next_saved_character_preset()
	for i in 2:
		var c=customer_script.new()
		c.setup(order,Color.WHITE,45,0,-1,0,-1,preset,true)
		root.add_child(c);c.position=Vector3(.7 if i==0 else -.7,0,0);c.rotation.y=PI;c.set_process(false)
		if c._anim_player:c._anim_player.pause()
		for frame in 4: await process_frame
		c._apply_leave_fade_alpha(1.0 if i==0 else .4)
	for i in 8:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/gameplay_hitch_audit_20261011/fade_visual.png")
	print("FADE_VISUAL_OK");quit()
