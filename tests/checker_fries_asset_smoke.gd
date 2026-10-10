extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(900, 900)
	var g = load("res://scenes/main.tscn").instantiate()
	g.set_script(load("res://tests/main_ticket_harness.gd"))
	root.add_child(g)
	current_scene = g
	g.get_node("UI").hide()
	var pack := Node3D.new()
	g.world.add_child(pack)
	g._populate_fry_pack(pack)
	var carton := pack.find_child("container_checker", true, false) as MeshInstance3D
	var fries := pack.find_child("fries", true, false) as MeshInstance3D
	var shake := pack.find_child("FriesShakeRoot", true, false) as Node3D
	assert(carton != null and fries != null and shake != null, "Pack must have the carton, fries, and shake pivot")
	assert(fries.get_parent() == shake and carton.get_parent() != shake, "Only fries should shake")
	assert(carton.material_override == null, "Do not replace the baked checker print")
	assert(carton.get_meta("fries_authored_print", false), "Authored carton print must be protected")
	var paper := carton.get_active_material(0) as StandardMaterial3D
	assert(paper != null and paper.albedo_texture != null, "Baked checker/logo texture must import")
	assert(carton.mesh.get_surface_count() == 1 and fries.mesh.get_surface_count() == 1)
	var bounds: AABB = g._mesh_aabb_in_node_space(pack)
	assert(absf(bounds.size.y - g.FRIES_PACK_TARGET_H) < .0001, "Serving height must be preserved")
	assert(absf(bounds.position.y) < .0001, "Carton must rest on its base")
	var sparkle = pack.find_child("SaltCrystalGlints",true,false)
	assert(sparkle != null and sparkle.materials.size() >= 7)
	sparkle._process(.016)
	sparkle._process(.016)
	for mat in sparkle.materials: assert(is_zero_approx(float(mat.get_shader_parameter("motion_amount"))))
	pack.position.x += .05
	sparkle._process(.016)
	for mat in sparkle.materials: assert(float(mat.get_shader_parameter("motion_amount")) > .9)
	sparkle._process(.016)
	for mat in sparkle.materials: assert(is_zero_approx(float(mat.get_shader_parameter("motion_amount"))))
	pack.position.x -= .05
	var carton_pose := carton.global_transform
	g._update_fries_pack_fry_shake(pack, .25, 1.0)
	assert(carton.global_transform.is_equal_approx(carton_pose) and shake.rotation.length() > .001, "Shake must leave carton steady")
	g._update_fries_pack_fry_shake(pack, 0.0, 0.0)
	# The remote-player foreground path must retain the same baked albedo.
	var remote := Node3D.new()
	g.world.add_child(remote)
	g._populate_fry_pack(remote)
	g._set_fries_pack_foreground(remote)
	var remote_carton := remote.find_child("container_checker", true, false) as MeshInstance3D
	var remote_paper := remote_carton.get_active_material(0) as StandardMaterial3D
	assert(remote_paper != null and remote_paper.albedo_texture == paper.albedo_texture, "Remote held packs must retain checker/logo texture")
	remote.visible = false
	var tris := 0
	for mesh_instance in [carton, fries]:
		for surface in mesh_instance.mesh.get_surface_count():
			tris += mesh_instance.mesh.surface_get_array_index_len(surface) / 3
	assert(tris <= 2000, "Finished fries should stay under 2,000 triangles")
	print("CHECKER_FRIES_OK: %d triangles; scale, grounding, baked print, fry shake, remote materials" % tris)
	await process_frame
	await process_frame
	if "--visual" in OS.get_cmdline_user_args():
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_COLOR
		env.environment.background_color = Color("343D3D")
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color.WHITE
		env.environment.ambient_light_energy = .65
		g.world.add_child(env)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-40, -25, 0)
		light.light_energy = 1.1
		g.world.add_child(light)
		g.camera.position = Vector3(-.045, .20, -.40)
		g.camera.look_at(Vector3(0, .10, 0))
		g.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		g.camera.size = .29
		g.camera.near = .005
		for i in 12: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/fry_checker_validation/game_runtime_preview.png")
		print("CHECKER_FRIES_PREVIEW_SAVED")
	# Release render instances before their temporary test materials.
	var keep_materials: Array[Material] = []
	for mesh_instance in g.find_children("*", "MeshInstance3D", true, false):
		if mesh_instance.mesh != null:
			for surface in mesh_instance.mesh.get_surface_count():
				keep_materials.append(mesh_instance.get_active_material(surface))
		if mesh_instance.material_override != null:
			keep_materials.append(mesh_instance.material_override)
	g.queue_free()
	await process_frame
	await process_frame
	quit()
