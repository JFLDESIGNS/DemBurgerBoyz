extends SceneTree

func _initialize():
	call_deferred("run")

func run():
	create_timer(60).timeout.connect(func(): quit(1))
	var g = load("res://scenes/main.tscn").instantiate()
	g.set_script(load("res://tests/patty_pool_fixture.gd"))
	root.add_child(g)
	current_scene = g
	g.playing = true
	g.grill_on = true
	g._setup_stations_data()
	g.grill.resize(g.GRILL_SLOTS)
	g.slot_positions.resize(g.GRILL_SLOTS)
	# A detached display ball must never continue its freezer-local seat tween.
	g.patty_fridge_balls_root = Node3D.new()
	g.world.add_child(g.patty_fridge_balls_root)
	var ball = Node3D.new()
	g.patty_fridge_balls_root.add_child(ball)
	for cycle in 30:
		ball.show()
		g._animate_fridge_ball_seat(ball, Vector3(9, 9, 9), 0.01, 0.01)
		assert(g._take_fridge_display_ball_for_flight() == ball)
		g.world.add_child(ball)
		ball.position = Vector3(2, 3, 4)
		await create_timer(0.03).timeout
		assert(ball.position.is_equal_approx(Vector3(2, 3, 4)), "Detached freezer animation must not move the flyer")
		g._return_fridge_display_ball(ball)
		assert(not ball.visible and ball.get_parent() == g.patty_fridge_balls_root)
	# Burst placement must reserve unique, separated positions inside the cook area.
	var bounds: Rect2 = g._cook_place_bounds()
	var desired = Vector3(bounds.get_center().x, g.GRILL_SURFACE_Y, bounds.get_center().y)
	for i in g.GRILL_SLOTS:
		var pos: Vector3 = g._find_closest_patty_place(desired)
		if pos == Vector3.ZERO: break
		assert(bounds.grow(0.001).has_point(Vector2(pos.x, pos.z)))
		assert(not g._patty_blocked_at(pos))
		var slot: int = g._first_empty_slot()
		assert(slot >= 0)
		g._fridge_pending_places[slot] = pos
	assert(not g._fridge_pending_places.is_empty())
	# Saturate the cook area with airborne reservations while grill slots are empty.
	g._fridge_pending_places.clear()
	for x in 40:
		for z in 40:
			g._fridge_pending_places[100 + x * 40 + z] = Vector3(lerpf(bounds.position.x, bounds.end.x, x / 39.0), g.GRILL_SURFACE_Y, lerpf(bounds.position.y, bounds.end.y, z / 39.0))
	assert(g._find_closest_patty_place(desired) == Vector3.ZERO)
	g.supply_stock["patty"] = 20
	var net = root.get_node("NetManager")
	g.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	net.role = net.Role.HOST
	net.connected = true
	assert(net.is_host())
	g.mp_request_spawn_patty(desired.x, desired.z)
	assert(g.supply_stock["patty"] == 20, "Full cook area must not consume stock")
	assert(g.grill.all(func(p): return p == null), "No forced spawn when the cook area is full")
	# Timer follows only the ticket's height, never its horizontal placement.
	g.challenge_hud_panel = PanelContainer.new()
	g.add_child(g.challenge_hud_panel)
	g.ticket_box = HBoxContainer.new()
	g.add_child(g.ticket_box)
	g.ticket_box.position = Vector2(50, 27)
	g.ticket_box.size = Vector2(180, 200)
	g._challenge_phase = "active"
	g._update_challenge_hud()
	assert(is_equal_approx(g.challenge_hud_panel.global_position.x + g.challenge_hud_panel.size.x / 2, g.get_viewport().get_visible_rect().size.x / 2))
	assert(is_equal_approx(g.challenge_hud_panel.global_position.y, 27))
	print("RAPID_PLACEMENT_FREEZER_TWEEN_AND_CENTERED_TIMER_OK")
	quit()
