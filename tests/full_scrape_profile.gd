extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	assert(str(ProjectSettings.get_setting("application/config/custom_user_dir", "")).begins_with("BurgerScrapeIsolatedTest"))
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	await game._start_game()
	print("FULL_SCRAPE_LOADED")
	assert(is_instance_valid(game._scrape_render_warmup_root) and not game._scrape_render_warmup_root.visible, "Scrape pipelines must be warmed and hidden before gameplay")
	game._reset_cut_collector_shift(false)
	game.truck_bought_out = true
	game.spawn_timer = 99999.0
	game.street_car_wait = 99999.0
	game.street_car_active = false
	game.street_car.hide()
	for i in 90: await process_frame
	var pos: Vector3 = game.slot_positions[0]
	pos.y = game.GRILL_SURFACE_Y
	for key in ClassDB.class_get_integer_constant_list("RenderingServer"):
		if "PIPELINE" in key: print("PIPELINE_ENUM ", key, "=", ClassDB.class_get_integer_constant("RenderingServer",key))
	game._leave_grill_residue_local(0, pos, false)
	for i in 45: await process_frame
	var steps: Array[float] = []
	var frames: Array[float] = []
	game.spatula_grill_hold_last_xz = Vector2(pos.x, pos.z)
	var last := Time.get_ticks_usec()
	var pipelines := []
	for info in range(6,11): pipelines.append(RenderingServer.get_rendering_info(info))
	for i in 180:
		var tip := pos + Vector3(sin(i * 0.36) * 0.04, 0, 0)
		var began := Time.get_ticks_usec()
		game._update_spatula_grill_scrape(tip, 1.0/120.0)
		steps.append((Time.get_ticks_usec()-began)/1000.0)
		await process_frame
		var now := Time.get_ticks_usec()
		var gap := (now-last)/1000.0
		frames.append(gap)
		if gap > 40.0:
			var next_pipelines := []
			for info in range(6,11): next_pipelines.append(RenderingServer.get_rendering_info(info))
			print("PIPELINES before=", pipelines, " after=", next_pipelines)
			pipelines = next_pipelines
			print("SCRAPE_SLOW frame=", i, " gap=", gap, " script=", steps.back(), " amount=", game.grill_residue[0], " flash=", game.flash_label.text, " process_ms=", Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
		last = now
	steps.sort()
	frames.sort()
	print("FULL_SCRAPE steps_p95_ms=", steps[170], " steps_peak_ms=", steps.back(), " frame_p50_ms=", frames[90], " frame_p95_ms=", frames[170], " frame_peak_ms=", frames.back())
	assert(game.grill_residue[0] <= 0.04, "Continuous scrape must clear the stain")
	game._stop_spatula_grill_scrape_audio()
	print("FULL_SCRAPE_OK")
	game.queue_free()
	for i in 3: await process_frame
	quit()
