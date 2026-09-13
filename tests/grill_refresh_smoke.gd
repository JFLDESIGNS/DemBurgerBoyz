extends SceneTree
func _initialize(): call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280,720)
	var scene := Node3D.new()
	root.add_child(scene)
	var grill = load("res://assets/machines/stylized_grill.glb").instantiate()
	grill.set_script(load("res://scripts/stylized_grill.gd"))
	scene.add_child(grill)
	grill.configure()
	assert(grill.temperature_digits != null, "Temperature screen missing")
	assert(grill.temperature_digits.text == "OFF")
	grill.set_power(true, true)
	assert(grill.temperature_digits.text == "185°")
	assert(grill.lamp_material.emission_enabled)
	assert(not grill.temperature_digits.shaded, "Only the powered temperature readout should be lit")
	var front: Node3D = grill.temperature_digits.get_parent()
	for child in front.get_children():
		if child is Label3D and child != grill.temperature_digits:
			assert(child.shaded, "Switch markings must use normal scene lighting")
	assert(absf(grill.temperature_digits.position.x) < 0.15, "Readout must be inside the center panel")
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
	assert(grill.temperature_digits.text == "OFF")
	assert(grill.temperature_digits.shaded, "The off display should not remain lit")
	print("GRILL_REFRESH_OK")
	quit()
