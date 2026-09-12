extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _make_game() -> Node:
	var game = load("res://scenes/main.tscn").instantiate()
	game.set_script(load("res://tests/burger_completion_harness.gd"))
	root.add_child(game)
	game.playing = true
	game.owned_machines[game.SHOP_SODA_MACHINE] = true
	game.soda_root = Node3D.new()
	game.world.add_child(game.soda_root)
	var ice_tip := Marker3D.new()
	ice_tip.name = "IceSpoutTip"
	ice_tip.position = Vector3(-0.2, 0.8, -0.3)
	ice_tip.set_meta("soda_station_id", "ice")
	game.soda_root.add_child(ice_tip)
	game.soda_spout_markers["ice"] = ice_tip
	game.cup_root = Node3D.new()
	game.cup_root.name = "DrinkCup"
	game.world.add_child(game.cup_root)
	game.cup_root.global_position = Vector3(0.5, 0.2, 0.5)
	game.cup_home = game.cup_root.global_position
	return game


func _run() -> void:
	var auto_game = _make_game()
	assert(auto_game._dispense_cup_to_fill_station(), "Rack tap was not accepted")
	for _frame in 12:
		await process_frame
	assert(not auto_game.cup_held, "Rack tap unexpectedly left the cup in hand")
	assert(auto_game._cup_parked_filling, "Rack tap did not start filling automatically")
	assert(auto_game._cup_auto_ice_soda == "icing", "Rack tap did not begin the automatic ice-to-cola cycle")
	auto_game.queue_free()
	await process_frame

	var manual_game = _make_game()
	manual_game._cup_press_screen = manual_game.get_viewport().get_mouse_position()
	manual_game._cup_press_msec = Time.get_ticks_msec() - 500
	assert(manual_game._begin_cup_hold(true), "Rack grab was not accepted")
	assert(manual_game.cup_held, "Rack grab did not put the cup in hand")
	assert(manual_game.cup_drawing, "Rack grab did not start the direct stack-to-hand draw")
	manual_game.queue_free()
	await process_frame
	print("CUP_RACK_INTERACTION_SMOKE_OK tap auto-fills; hold/drag grabs")
	quit()
