extends SceneTree
func _initialize(): call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280,720)
	var scene := Node3D.new()
	root.add_child(scene)
	var grill = load("res://assets/machines/stylized_grill.glb").instantiate()
	grill.set_script(load("res://scripts/stylized_grill.gd"))
	grill.configure() # Production may configure before entering the tree.
	scene.add_child(grill)
	var red: MeshInstance3D = grill.knob.find_child("Rotary_Vermilion",true,false)
	var center: Vector3 = grill.knob.to_local(red.to_global(red.mesh.get_aabb().get_center()))
	assert(Vector2(center.x,center.z).length()<.0001, "Red knob must rotate on the ring axis")
	assert(is_zero_approx(grill.knob.position.z), "No offset from dial ring")
	assert(grill.find_child("PowerState",true,false)==null)
	assert(grill.display_material != null, "LED screen missing")
	assert(not grill.powered and is_zero_approx(grill.display_heat))
	grill.set_power(true, true)
	assert(grill.powered and grill.lamp_material.emission_enabled)
	grill._process(2.5)
	assert(is_equal_approx(grill.display_heat, 0.5), "Half heat after 2.5 seconds")
	grill.set_power(true)
	assert(is_equal_approx(grill.display_heat, 0.5), "Repeated network power updates must not restart heat")
	grill._process(2.49)
	assert(grill.display_heat < 1.0, "Must not reach full before five seconds")
	grill._process(0.01)
	assert(is_equal_approx(grill.display_heat, 1.0), "Full heat at five seconds")
	assert(not grill.is_processing(), "Stop per-frame updates once full")
	var camera := Camera3D.new()
	scene.add_child(camera)
	var target: Vector3 = grill.knob.global_position
	camera.position = target + Vector3(0,0.16,-0.70)
	camera.look_at(target + Vector3(0,0.015,0))
	camera.current = true
	var light := DirectionalLight3D.new()
	scene.add_child(light)
	light.rotation_degrees = Vector3(-45,150,0)
	light.light_energy = 1.5
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("283338")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.65
	scene.add_child(environment)
	for frame in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("BURGER_PROBE_OUTPUT").path_join("grill_refresh.png"))
	grill.set_power(false,true)
	assert(not grill.powered and is_zero_approx(grill.display_heat), "Power off resets the LED meter")
	grill.set_power(true)
	assert(is_zero_approx(grill.display_heat), "Restart must ramp from empty")
	print("GRILL_REFRESH_OK")
	quit()
