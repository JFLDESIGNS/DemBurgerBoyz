extends SceneTree
const Audio = preload("res://scripts/game_audio.gd")
const Vehicle = preload("res://scripts/street_vehicle.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.set_script(load(get_script().resource_path.get_base_dir().path_join("burger_completion_harness.gd")))
	root.add_child(game)
	current_scene = game
	game.set_process_input(false)
	for child in game.get_node("UI/Root").get_children():
		if child is CanvasItem: child.hide()
	var soda := Node3D.new()
	game.world.add_child(soda)
	game.soda_root = soda
	var visual = load("res://assets/machines/pop_machine.glb").instantiate()
	visual.name = "FountainModel"
	soda.add_child(visual)
	game._sync_refined_soda_visual()
	game._setup_soda_dispense_clips(visual)
	assert(game.soda_dispense_clips.size() == 2)
	for fid in ["cola", "ice"]:
		var lever := visual.find_child("Stick_" + fid, true, false) as Node3D
		var mesh := lever.get_child(0) as MeshInstance3D
		var bounds: AABB = mesh.transform * mesh.get_aabb()
		assert(absf(bounds.end.y) < 0.002, "Metal lever top must meet its hinge, without a second height offset")
		assert(bounds.position.y < -0.20 and bounds.position.y > -0.25, "Lever must hang down below the dispenser")
		assert(absf(bounds.get_center().x) < 0.02, "Lever must stay centered on its own valve")
	game.soda_station_scale *= 1.25
	game._sync_refined_soda_visual()
	for clip in game.soda_dispense_clips:
		assert(clip.node.position.is_equal_approx(clip.rest_pos), "Tuning must preserve hinge-local positioning")
	game.soda_station_scale /= 1.25
	game._sync_refined_soda_visual()
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -25, 0)
	light.light_energy = 2.0
	game.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.12,0.15,0.19)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.7
	game.add_child(env)
	game.camera.position = Vector3(1.05, 0.93, -1.55)
	game.camera.look_at(Vector3(0, 0.45, -0.12))
	for i in 8: await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png(OS.get_environment("BURGER_PROBE_OUTPUT").path_join("soda_prongs_fixed.png"))

	var audio := Audio.new()
	game.add_child(audio)
	game.game_audio = audio
	# Reproduce the old missing-variant path before warming the full bank.
	var began := Time.get_ticks_usec()
	audio._play_cached("debris_kuhh_7", audio._make_debris_kuhh, 1.0, 0.4)
	var cold_ms := (Time.get_ticks_usec() - began) / 1000.0
	await audio.prewarm_spatula_audio()
	for i in audio.DEBRIS_BASS_VARIANTS: assert(audio._cache.has("debris_bass_%d" % i))
	for i in audio.DEBRIS_KUHH_VARIANTS: assert(audio._cache.has("debris_kuhh_%d" % i))
	var count := audio._cache.size()
	var warm_peak_ms := 0.0
	for i in audio.DEBRIS_KUHH_VARIANTS:
		began = Time.get_ticks_usec()
		audio._play_cached("debris_kuhh_%d" % i, audio._make_debris_kuhh, 1.0, 0.4)
		warm_peak_ms = maxf(warm_peak_ms, (Time.get_ticks_usec()-began)/1000.0)
	assert(count == audio._cache.size())
	print("SCRAPE_AUDIO cold_missing_variant_ms=", cold_ms, " warmed_peak_ms=", warm_peak_ms)
	for field in ["grill_residue", "brush_swipe_travel", "brush_swipe_cool"]:
		game[field].resize(game.GRILL_SLOTS)
		game[field].fill(0.0)
	game.grill_residue_chunks.resize(game.GRILL_SLOTS)
	game.grill_residue_kind.resize(game.GRILL_SLOTS)
	game.grill_residue_centers.resize(game.GRILL_SLOTS)
	for i in game.GRILL_SLOTS:
		game.grill_residue_chunks[i] = []
		game.grill_residue_kind[i] = ""
	var at := Vector3(game.GRILL_CENTER_X, game.GRILL_SURFACE_Y, game.GRILL_SURFACE_Z)
	game._leave_grill_residue_local(0, at, false)
	assert(game.grill_residue[0] > 0.0)
	began = Time.get_ticks_usec()
	game._scrape_residue_hit(0, Vector2.RIGHT, true)
	print("SCRAPE_HIT cpu_ms=", (Time.get_ticks_usec()-began)/1000.0)
	game._scrape_finish_clean_local(0)
	assert(game.grill_residue[0] == 0.0 and game.debris_piles.is_empty())
	soda.hide()
	game.grill_root.hide()
	var car := Vehicle.new()
	game.world.add_child(car)
	var scenes: Array = []
	for path in Vehicle.MODEL_PATHS: scenes.append(load(path))
	car.set_pool(scenes)
	var peak_us := 0
	var total_us := 0
	for variant in car.models.size():
		car.set_variant(variant)
		var visible_count := 0
		for model in car.models:
			if model.visible: visible_count += 1
		assert(visible_count == 1, "Only one car variant may be visible")
		for i in 300:
			began = Time.get_ticks_usec()
			car.advance_driving(1.0/120.0, 3.0)
			var us := Time.get_ticks_usec()-began
			total_us += us
			peak_us = maxi(peak_us, us)
	print("TRAFFIC_ANIMATION mean_ms=", total_us / 2100000.0, " peak_ms=", peak_us / 1000.0)
	if DisplayServer.get_name() != "headless":
		game.camera.position = Vector3(6, 3, -7)
		game.camera.look_at(Vector3(0, 1, 0))
		for visible in [false, true]:
			car.visible = visible
			for i in 15: await process_frame
			await RenderingServer.frame_post_draw
			print("TRAFFIC_RENDER visible=", visible, " draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " primitives=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	print("SODA_SCRAPE_TRAFFIC_OK")
	game.queue_free()
	for i in 3: await process_frame
	quit()
