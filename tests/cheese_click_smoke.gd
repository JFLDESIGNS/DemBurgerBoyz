extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Input.use_accumulated_input = false
	create_timer(20.0).timeout.connect(func(): quit(1))
	var g = load("res://scenes/main.tscn").instantiate()
	g.set_script(load("res://tests/cheese_click_fixture.gd"))
	root.add_child(g)
	g.set_process_input(false)
	g.set_process_unhandled_input(false)
	g.playing = true
	var button := Control.new()
	button.position = Vector2(100, 100)
	button.size = Vector2(100, 100)
	g.add_child(button)
	g.ingredient_buttons = {"cheese": button}
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(150, 150)
	Input.parse_input_event(press.duplicate())
	assert(g._handle_strip_swipe_input(press))
	# Keep the real pointer inside the tray for the hold-time check.
	g._strip_hold_origin = root.get_mouse_position()
	g._update_strip_hold_pickup(0.22)
	assert(g.pickups == 0, "A normal cheese click must not become a held slice after 120 ms")
	var release := press.duplicate()
	release.pressed = false
	assert(g._handle_strip_swipe_input(release))
	Input.parse_input_event(release.duplicate())
	assert(g.added == ["cheese"], "A tap must add cheese exactly once")
	g._begin_strip_hold_tracking("cheese", root.get_mouse_position())
	Input.parse_input_event(press.duplicate())
	g._update_strip_hold_pickup(0.31)
	assert(g.pickups == 1, "An intentional long hold must still pick up cheese")
	Input.parse_input_event(release.duplicate())
	g.ingredient_buttons.clear()
	g.camera.position = Vector3(0, 3, 4)
	g.camera.look_at(Vector3.ZERO)
	var tray := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1, 0.2, 1)
	tray.mesh = box
	g.add_child(tray)
	g.ingredient_bin_nodes["cheese"] = tray
	var hit: Vector2 = g.camera.unproject_position(Vector3.ZERO)
	assert(g._strip_ingredient_at(hit) == "cheese", "Visible tray outside the UI button must claim the click")
	assert(not g._try_patty_fridge_click(hit), "Freezer must yield the cheese tray click")
	tray.hide()
	assert(g._strip_ingredient_at(hit) == "", "Hidden trays must not steal clicks")
	g.queue_free()
	await process_frame
	print("CHEESE_CLICK_OK: normal taps, deliberate holds, projected tray, freezer priority")
	quit()
