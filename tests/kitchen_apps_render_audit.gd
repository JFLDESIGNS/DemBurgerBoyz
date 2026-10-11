extends SceneTree
## Rendered, event-labelled wall-frame measurements; run alone for useful timings.
var game
var results: Array = []
var preset: Dictionary
var next_id := 970000
var pipeline_monitors := {}
var focused := OS.get_environment("HITCH_AUDIT_FOCUSED") == "1"

func _initialize() -> void: call_deferred("run")

func phase(label: String, action: Callable, frames: int = 150, minimum_seconds: float = 0.0) -> void:
	var samples: Array = []
	var pipeline_previous := {}
	var last := Time.get_ticks_usec()
	var began := last
	action.call()
	var call_ms := (Time.get_ticks_usec() - last) / 1000.0
	while samples.size() < frames or (Time.get_ticks_usec()-began)/1000000.0 < minimum_seconds:
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append((now - last) / 1000.0)
		if label.begins_with("serve_"):
			for monitor_name in pipeline_monitors:
				var count := int(Performance.get_monitor(pipeline_monitors[monitor_name]))
				if pipeline_previous.has(monitor_name) and count != pipeline_previous[monitor_name]:
					print("SERVE_PIPELINE ",monitor_name," added=",count-pipeline_previous[monitor_name]," frame=",samples.size()," global_frame=",Engine.get_process_frames())
				pipeline_previous[monitor_name] = count
		last = now
		if samples.back() > 60.0: print("HITCH_FRAME ", label, " frame=",samples.size()," ms=",samples.back()," global_frame=",Engine.get_process_frames())
	samples.sort()
	frames = samples.size()
	var row := {"event": label, "frames": frames, "call_ms": call_ms,
		"p50_ms": samples[int(frames * .5)], "p95_ms": samples[int(frames * .95)],
		"p99_ms": samples[int(frames * .99)], "max_ms": samples.back(),
		"over_33_ms": samples.filter(func(v): return v > 33.333).size(),
		"over_50_ms": samples.filter(func(v): return v > 50.0).size(),
		"over_100_ms": samples.filter(func(v): return v > 100.0).size()}
	results.append(row)
	print("HITCH_EVENT ", JSON.stringify(row))
	save_report()

func save_report() -> void:
	var file := FileAccess.open(OS.get_environment("HITCH_AUDIT_OUTPUT"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer": DisplayServer.get_name(), "resolution": root.size,
		"events": results, "hot_paths": game.get_performance_hot_path_stats()}, "\t"))

func spawn(order: Array) -> Node3D:
	game._spawn_customer_local(order, Color.WHITE, 9999.0, 0, next_id, -1, 0, false, -1, false, preset, true)
	next_id += 1
	print("CHARACTER_DETAIL ", JSON.stringify(game.customers.back().construction_costs))
	return game.customers.back()

func ready_customer(order: Array) -> Node3D:
	var c := spawn(order)
	c.position = Vector3(c.target_x, c.STAND_Y, 2.25)
	c.is_waiting = true
	c.set_process(false)
	game._create_ticket(c)
	game.selected_customer = c
	return c

func clear_customers() -> void:
	game._clear_customers()
	game._serve_fly_busy = false

func run() -> void:
	for constant in ClassDB.class_get_integer_constant_list("Performance"):
		if "PIPELINE" in constant:
			pipeline_monitors[constant] = ClassDB.class_get_integer_constant("Performance",constant)
	print("PIPELINE_MONITORS ",pipeline_monitors)
	create_timer(330).timeout.connect(func(): push_error("GAMEPLAY_HITCH_AUDIT_TIMEOUT"); quit(1))
	game = load("res://scenes/main.tscn").instantiate()
	game.set_script(load("res://tests/gameplay_hitch_audit_fixture.gd"))
	root.add_child(game); current_scene = game
	await game._start_game(false)
	game._clear_bts_day_intro(false)
	game._bts_day1_performance_done = true
	game._boss_intro_running = false
	game.spawn_timer = 999999.0
	game.day_time = 99999.0
	game.truck_bought_out = true
	game._reset_cut_collector_shift(false)
	if is_instance_valid(game._shift_events): game._shift_events.set_process(false)
	if is_instance_valid(game._customer_social): game._customer_social.set_process(false)
	clear_customers()
	preset = game.CustomerScript.take_next_saved_character_preset()
	assert(not preset.is_empty())
	game._set_phone_in_truck(true)
	game._set_phone_expanded(true)
	for app in ["home","shop","social","maps","bank","orders","achievements","grubbah","snak","gnop","smush","muvye"]:
		await phase("phone_"+app,func():game._set_phone_app(app),30)
		assert(game._phone_app_id==app)
	game._set_phone_app("shop")
	var shop_ids:Array=[]
	for row in game.phone_inventory_box.get_children():shop_ids.append(row.get_instance_id())
	for i in 20:game._refresh_phone_ui()
	var shop_after:Array=[]
	for row in game.phone_inventory_box.get_children():shop_after.append(row.get_instance_id())
	assert(shop_ids==shop_after,"Unchanged shop updates preserve rows")
	game._set_phone_expanded(false)
	await create_timer(.3).timeout
	assert(game._phone_lock_screen.visible)
	game._phone_lock_screen.pressed.emit()
	await create_timer(.3).timeout
	assert(not game._phone_lock_screen.visible)
	game._set_phone_app("home")
	print("ALL_PHONE_APPS_RENDER_AUDIT_OK")
	await phase("idle_baseline", func(): pass, 180)
	while not game._background_load_complete: await process_frame
	await phase("idle_settled", func(): pass, 180)
	for i in 3:
		await phase("customer_arrival_%d" % i, func(): spawn(["bun_bottom", "patty", "bun_top"]))
	await phase("customers_leave", func():
		for c in game.customers.duplicate():
			c.leave_mad()
			game._on_customer_left(c, true)
	, 300, 8.0)
	clear_customers()
	if not focused:
		await phase("background_walkers_restyle", func():
			for i in game.bg_people.size():
				game.bg_people_active[i] = false
				game._start_background_person(i)
		, 180)
		await phase("background_angry_click", func():
			for i in game.bg_people.size():
				if game.bg_people_active[i]: game.mp_background_person_hail(i, "angry")
		, 180)
		await phase("boss_arrival", func(): game._spawn_cut_collector_local("pep"), 240)
		game._reset_cut_collector_shift(false)
		await phase("supply_delivery", func(): game._begin_cat_supply_delivery("lettuce", 8, "stock"), 1500)
		game._clear_supply_delivery_fx()
	var photo_probe := OS.get_environment("HITCH_BURGER_PHOTO_PROBE") == "1"
	var serve_items: Array = ["normal", "no_photo", "no_review", "normal_repeat"] if photo_probe else (["burger", "fries"] if focused else ["burger", "soda_cola", "fries", "icecream"])
	for probe_item in serve_items:
		var item: String = "burger" if photo_probe else str(probe_item)
		game.burger_probe_mode = OS.get_environment("HITCH_FIRST_SERVE_MODE") if not OS.get_environment("HITCH_FIRST_SERVE_MODE").is_empty() else (str(probe_item) if photo_probe else "normal")
		clear_customers()
		var order: Array = ["bun_bottom", "patty", "bun_top"] if item == "burger" else [item]
		var c := ready_customer(order)
		if item == "burger":
			var p = game._take_prewarmed_patty()
			p.set_process(false); p.cook_time = 8.0; p.first_side_time = 8.0; p.flipped_once = true
			game.stations[0].items = ["bun_bottom", "patty", "bun_top"] as Array[String]
			game.stations[0].patties = [p]
			game._refresh_station(0)
		elif item == "soda_cola":
			game.cup_root = game._create_drink_cup_node()
			game.world.add_child(game.cup_root)
			game.cup_soda_fill = 1.0; game.cup_flavor = "cola"
			game._mp_apply_remote_cup_fill(game.cup_root, "cola", 1.0, 0.0, 0.0, false)
		elif item == "fries":
			game.fryer_ready_servings = 3
			game._refresh_ready_fries_visuals()
		else:
			game._spawn_and_bind_empty_icecream_cone()
			game.icecream_cone_fill = 1.0
			game._refresh_icecream_cone_visuals()
		for i in 30: await process_frame
		if photo_probe and game.stations[0].get("review_thumb") != null:
			var texture: Texture2D = game.stations[0].review_thumb
			if texture.has_meta("sales_png"):
				var decoded := Image.new()
				assert(decoded.load_png_from_buffer(texture.get_meta("sales_png")) == OK)
				assert(decoded.get_size() == Vector2i(160,160))
				assert(decoded.load_png_from_buffer(texture.get_meta("review_png")) == OK)
				assert(decoded.get_size() == Vector2i(192,192))
				print("BURGER_PHOTO_BYTES_OK")
		var served_before: int = game.total_served
		await phase("serve_" + (str(probe_item) if photo_probe else item), func():
			match item:
				"burger": game._begin_serve_at(c, 0, false)
				"soda_cola": game._begin_soda_only_serve(c)
				"fries": game._begin_fries_only_serve(c)
				"icecream": game._begin_icecream_customer_hand(c)
		, 300, 7.0)
		assert(game.total_served > served_before, "Serving failed: " + item)
	await phase("chef_reward_burst", func():
		for i in 8: game._chef_award_once(null, "audit", 10, "Audit reward")
	)
	print("GAMEPLAY_HITCH_AUDIT_OK")
	game.queue_free()
	await process_frame
	quit()
