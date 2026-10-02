extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.set_script(load("res://tests/social_shift_fixture.gd"))
	root.add_child(game); current_scene = game; game.playing = true; game.grill_on = true
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1100,500); viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera3D.new(); viewport.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 1.75
	camera.look_at_from_position(Vector3(0,.9,.7),Vector3.ZERO)
	camera.current = true
	var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-55,-25,0); light.light_energy = 1.8; viewport.add_child(light)
	var ground := MeshInstance3D.new(); var plane := PlaneMesh.new(); plane.size = Vector2(3,2); ground.mesh = plane
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color("403E3A"); mat.roughness = .5
	ground.material_override = mat; ground.position.y = -.012; viewport.add_child(ground)
	for stage in 3:
		var batch = load("res://scripts/onion_batch.gd").new(); batch.game = game
		viewport.add_child(batch); batch.set_process(false)
		batch.position.x = (stage-1)*.33
		for n in stage: batch.chop()
		batch.cook_time = stage*5.0
		batch._process(0)
		batch.halo.hide(); batch.steam.emitting = false
	await create_timer(.5).timeout
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://build/customer_polish_qa/onion_preview.png")
	print("ONION_PREVIEW_OK")
	quit()
