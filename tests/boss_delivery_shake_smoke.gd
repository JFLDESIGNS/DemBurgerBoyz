extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	create_timer(60).timeout.connect(func(): push_error("BOSS_DELIVERY_TIMEOUT"); quit(1))
	var game = load("res://scenes/main.tscn").instantiate()
	game.set_script(load("res://tests/interaction_delivery_fixture.gd"))
	root.add_child(game); current_scene = game; game.playing = true
	game.window_cat = load("res://scripts/window_cat.gd").new(); game.world.add_child(game.window_cat)
	var boss = load("res://scripts/hotdog_challenge.gd").new()
	game.add_child(boss); boss.set_process(false); boss.phase = "ready"
	game._hotdog_challenge = boss
	game.street_car_active = true
	game._begin_cat_supply_delivery("lettuce", 8, "stock")
	var delivery = game.mail_delivery_truck
	delivery.advance(.01)
	assert(delivery.on_foot and delivery.phase == "walk" and not delivery.truck.visible)
	assert(not delivery.drive_audio.playing and not delivery.horn_audio.playing and not delivery.skid_audio.playing)
	assert(game.camera.unproject_position(delivery.doorstep).x < 0, "Courier enters from offscreen left")
	for i in 1600:
		if is_instance_valid(game.mail_delivery_truck):
			assert(not game.mail_delivery_truck.truck.visible)
			assert(game.mail_delivery_truck.phase not in ["arrive", "hop_out", "hop_in", "depart"])
		game._update_supply_orders(1.0/60)
	assert(game.credits == [["lettuce",8,"stock"]], "Walking courier still credits exactly once")
	assert(game.mail_delivery_truck == null and game.window_cat.is_processing())
	# A challenge starting during a normal truck approach switches to the same foot route.
	boss.phase = ""; game.street_car_active = false
	game._begin_cat_supply_delivery("tomato", 8, "stock")
	delivery = game.mail_delivery_truck; delivery.advance(.1)
	assert(delivery.phase == "arrive" and delivery.truck.visible)
	boss.phase = "ready"; delivery.advance(.1)
	assert(delivery.on_foot and delivery.phase == "walk" and not delivery.truck.visible)
	game._clear_supply_delivery_fx()
	game.camera.position = game.slot_camera_base_pos
	var variants = {}
	for attempt in 8:
		game._start_slot_camera_shake(.5, .075)
		variants[str(game.slot_camera_shake_points[1])] = true
		var crossings = 0; var previous_sign = 0
		for frame in 60:
			game._update_slot_camera_shake(1.0/120)
			var offset = game.camera.position - game.slot_camera_base_pos
			assert(offset.length() < .09)
			var direction = int(signf(offset.x)) if absf(offset.x) > .00001 else 0
			if direction != 0:
				if previous_sign != 0 and direction != previous_sign: crossings += 1
				previous_sign = direction
		assert(crossings <= 1, "Impact should have only one rebound")
		assert(game.camera.position.is_equal_approx(game.slot_camera_base_pos))
	assert(variants.size() > 1, "Hits should vary in direction and strength")
	game.queue_free(); await process_frame
	print("BOSS_DELIVERY_SHAKE_OK: left-entry courier, no truck, stock once, mid-delivery switch, one randomized rebound")
	quit()
