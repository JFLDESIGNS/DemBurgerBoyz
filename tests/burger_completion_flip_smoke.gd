extends SceneTree

const Patty = preload("res://scripts/patty.gd")
const Customer = preload("res://scripts/customer.gd")
const Audio = preload("res://scripts/game_audio.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var watchdog := create_timer(40.0)
	var timeout_callback := quit.bind(1)
	watchdog.timeout.connect(timeout_callback)
	var game = load("res://scenes/main.tscn").instantiate()
	game.set_script(load(get_script().resource_path.get_base_dir().path_join("burger_completion_harness.gd")))
	root.add_child(game)
	current_scene = game
	game.set_process_input(false)
	for child in game.get_node("UI/Root").get_children():
		if child is CanvasItem: child.hide()
	var preview := Control.new()
	preview.position = Vector2(360, 330)
	preview.size = Vector2(220, 180)
	game.get_node("UI/Root").add_child(preview)
	game.stations = [{"items": ["bun_bottom", "patty", "lettuce", "tomato", "bun_top"], "patties": [], "preview": preview, "panel": null}]
	game._ensure_serve_fx_pools()
	var customer = Customer.new()
	game.add_child(customer)
	customer.position = Vector3(0.6, 0.0, 1.0)
	customer.is_waiting = true
	customer.order = ["bun_bottom", "patty", "lettuce", "tomato", "bun_top"] as Array[String]
	for i in 10: await process_frame
	customer.start_order_clock()
	customer.order_elapsed_sec = 4.95
	game.playing = true
	game._begin_serve_at(customer, 0, false)
	assert(game.commits == 1 and is_equal_approx(game.scored_wait, 4.95), "Score must commit before the visual hold")
	assert(not customer._order_clock_on, "Serve entry must stop the actual customer clock")
	var fly: Control
	for candidate in game._serve_fly_root_pool:
		if candidate.visible: fly = candidate
	assert(fly != null)
	var stack := fly.get_node("ServeFlyStack") as Control
	var burst := fly.get_node("BurgerCompleteBurst") as Node2D
	assert(burst.visible and burst.get_index() < stack.get_index(), "Comic burst must sit behind the burger")
	var start: Vector2 = stack.get_global_transform() * stack.pivot_offset
	game._begin_serve_at(customer, 0, false)
	assert(game.commits == 1, "Repeat serve during the hold must not score twice")
	await create_timer(0.25).timeout
	assert((stack.get_global_transform() * stack.pivot_offset).is_equal_approx(start) and burst.visible, "Completed burger must remain in place during the hold")
	assert(is_equal_approx(customer.order_elapsed_sec, 4.95), "Hold must not change speed scoring")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png("res://debug_captures/burger_completion.png")
	await create_timer(0.2).timeout
	assert((stack.get_global_transform() * stack.pivot_offset).is_equal_approx(start), "Burger must not fly before half a second")
	await create_timer(0.25).timeout
	assert(not burst.visible and not (stack.get_global_transform() * stack.pivot_offset).is_equal_approx(start), "Burger must launch after the hold")
	await create_timer(0.6).timeout
	assert(not fly.visible and not game._serve_fly_busy and preview.modulate.a == 1.0, "Serve must restore preview and release the pooled effect")
	assert(game.commits == 1 and is_equal_approx(customer.order_elapsed_sec, 4.95))
	# Reuse must reset all presentation state.
	game.stations[0]["items"] = ["bun_bottom", "patty", "bun_top"]
	game._play_serve_fly_to_mouth(0, customer, func(): pass)
	assert(fly.visible and burst.visible and burst.modulate.a == 1.0)
	await create_timer(1.3).timeout
	assert(not fly.visible and not burst.visible)

	var audio = Audio.new()
	game.add_child(audio)
	for entry in [["perfect_announcer", "res://sounds/perfect.wav"], ["order_greatjob_announcer", "res://sounds/greatjob.wav"], ["order_ohhh_announcer", "res://sounds/ohhh.wav"]]:
		audio._load_announcer_stream(entry[0], entry[1])
	await audio._prewarm_cache_entry_async("flip", audio._make_flip)
	await audio._prewarm_cache_entry_async("spatula_whoosh", audio._make_spatula_whoosh)

	# Real flip grades and texture update costs, independent of the pull gesture.
	var patty = Patty.new()
	game.add_child(patty)
	patty.set_process(false)
	var samples: Array[float] = []
	for grade in ["perfect", "great", "late"]:
		patty.flipped_once = false
		patty.cook_time = 16.0
		patty._update_cook_gradient()
		var began := Time.get_ticks_usec()
		assert(patty.flip(grade))
		samples.append((Time.get_ticks_usec() - began) / 1000.0)
		assert(patty.last_flip_grade == grade and patty.first_side_time == 16.0 and patty.cook_time == 0.0)
		assert(not patty.flip(grade), "A patty must not flip twice")
		await create_timer(0.2).timeout
	print("PATTY_FLIP_CPU_MS ", samples)

	game._ensure_spatula_fx_pools()
	game._begin_spatula_flip_fx()
	var fx = game._spatula_ribbon_root
	var ring = game._spatula_circle_mi.mesh
	var ribbon = game._spatula_ribbon_meshes[0].mesh
	for i in 8:
		game._tick_spatula_flip_fx(0.016, Vector3(i * 0.02, 0.0, 0.0))
		assert(game._spatula_circle_mi.mesh == ring and game._spatula_ribbon_meshes[0].mesh == ribbon, "Flourish frames must retain mesh resources")
	game._clear_spatula_flip_ribbons()
	assert(is_instance_valid(fx) and not fx.visible)
	game._begin_spatula_flip_fx()
	assert(game._spatula_ribbon_root == fx and game._spatula_circle_mi.mesh == ring)
	game._clear_spatula_flip_ribbons()

	var count: int = audio._cache.size()
	for grade in ["perfect", "great", "late"]: audio.play_flip_grade_announcer(grade)
	audio.play_delivery_time_announcer(4.95)
	assert(audio._cache.size() == count, "Flip/serve announcers must reuse prewarmed keys")
	print("BURGER_COMPLETION_FLIP_SMOKE_OK")
	watchdog.timeout.disconnect(timeout_callback)
	game.queue_free()
	await process_frame
	await process_frame
	quit()
