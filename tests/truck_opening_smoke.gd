extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var g = load("res://scenes/main.tscn").instantiate()
	g.set_script(load("res://tests/main_ticket_harness.gd"))
	root.add_child(g); current_scene = g
	g.window_bunting_root = Node3D.new(); g.world.add_child(g.window_bunting_root)
	g.window_bunting_root.position = Vector3(0,2.57,1.52)
	g.open_closed_sign = Node3D.new(); g.world.add_child(g.open_closed_sign)
	var sun = DirectionalLight3D.new(); sun.light_energy = 2.0; g.world.add_child(sun)
	var opening = load("res://scripts/truck_opening.gd").new(); g.add_child(opening); opening.set_process(false)
	var mask = g.camera.cull_mask
	opening.setup(g)
	assert(opening.DURATION == 6.0 and opening.blocker.mouse_filter == Control.MOUSE_FILTER_STOP)
	assert(sun.light_energy < .2 and opening.shutter.visible)
	assert(opening.blocker is ColorRect and opening.blocker.color.a > .8)
	assert((g.camera.cull_mask & g.LOADING_WARMUP_LAYER) == 0)
	opening.age = 1.0
	opening._process(0.0)
	assert(opening.garage_player.playing)
	var garage_full: float = opening.garage_player.volume_db
	opening.age = 2.95
	opening._process(0.0)
	assert(opening.garage_player.volume_db < garage_full - 6.0, "Garage sound must fade before opening finishes")
	opening.age = 3.35
	opening._process(0.0)
	assert(not opening.garage_player.playing, "Garage sound must stop before the jingle")
	opening.sample(4.20)
	assert(is_equal_approx(g.open_closed_sign.rotation_degrees.y,g.OPEN_CLOSED_SIGN_YAW_CLOSED))
	assert(g.window_bunting_root.position.distance_to(Vector3(0,2.57,1.52)) < .05)
	opening.sample(2.0)
	assert(opening.shutter.scale.y < 1.0 and opening.shutter.scale.y > .1)
	opening.sample(6.0)
	assert(is_zero_approx(opening.blocker.color.a))
	assert(not opening.shutter.visible and is_equal_approx(sun.light_energy,2.0))
	assert(g.window_bunting_root.position.is_equal_approx(Vector3(0,2.57,1.52)))
	assert(is_equal_approx(g.open_closed_sign.rotation_degrees.y,g.OPEN_CLOSED_SIGN_YAW_OPEN))
	opening.queue_free(); await process_frame
	assert(g.camera.cull_mask == mask)
	print("TRUCK_OPENING_OK: six-second reveal, dark-to-light, shutter, bunting, sign, input blocker, cleanup")
	g.queue_free(); await process_frame; quit()
