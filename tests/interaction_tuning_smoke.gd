extends SceneTree
func _initialize(): call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.set_script(load(get_script().resource_path.get_base_dir().path_join("interaction_tuning_fixture.gd")))
	root.add_child(game)
	game.playing = true
	game.grill.resize(game.GRILL_SLOTS)
	game.ingredient_buttons.clear()
	var ids := ["cheese","tomato","lettuce","pickle","onion","bacon","ketchup","mustard"]
	for i in ids.size():
		var button := Button.new()
		button.position = Vector2(40+i*48,100)
		button.size = Vector2(40,60)
		game.get_node("UI/Root").add_child(button)
		game.ingredient_buttons[ids[i]] = button
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(50,120)
	game._handle_strip_swipe_input(press)
	var move := InputEventMouseMotion.new()
	move.position = Vector2(414,120)
	game._handle_strip_swipe_input(move)
	assert(game.captured == ids, "Fast sweep must add every crossed ingredient once, in order")
	move.position = Vector2(50,120)
	game._handle_strip_swipe_input(move)
	assert(game.captured.size() == ids.size(), "Backtracking must not duplicate toppings")
	assert(not game._strip_hold_started, "Horizontal sweep must not grab an ingredient")
	# Dense, repeatable dirt workload exercises the actual robot target solver.
	for i in 80:
		var mesh := MeshInstance3D.new()
		game.add_child(mesh)
		mesh.position = Vector3(-0.75+float(i%10)*0.15,1.17,-0.3+float(i/10)*0.075)
		game.oil_slicks.append({"mesh":mesh,"radius":0.04})
	var start := Time.get_ticks_usec()
	for i in 60: game._roomba_dirty_target(Vector2.ZERO)
	var raw_us := Time.get_ticks_usec()-start
	game._roomba_scan_left = 0.0
	start = Time.get_ticks_usec()
	for i in 60: game._roomba_scan_dirt(Vector2.ZERO,1.0/60.0)
	var cached_us := Time.get_ticks_usec()-start
	print("ROBOT_DENSE_DIRT raw_average_ms=",float(raw_us)/60000.0," scheduled_average_ms=",float(cached_us)/60000.0)
	assert(game._roomba_cached_dirt.is_finite(), "Robot must still find dirt")
	print("INTERACTION_TUNING_OK")
	quit()
