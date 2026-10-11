extends SceneTree

const CUSTOMER = preload("res://scripts/customer.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	create_timer(120).timeout.connect(func(): push_error("STREET_HAIL_RECYCLE_TIMEOUT"); quit(1))
	var game = load("res://scenes/main.tscn").instantiate()
	game.set_script(load("res://tests/hotdog_challenge_fixture.gd"))
	root.add_child(game)
	current_scene = game
	game.playing = true
	game.day_time = 300
	game.stations = [{"items": [], "patties": []}]
	var walker = CUSTOMER.new()
	walker.is_street_pedestrian = true
	var preset = CUSTOMER.take_next_saved_character_preset()
	assert(not preset.is_empty())
	walker.setup([], Color.WHITE, 9999, 0, -1, 0, -1, preset, true)
	game.customers_root.add_child(walker)
	game.bg_people = [walker]
	game.bg_people_active = [true]
	game.bg_people_dir = [1.0]
	game.bg_people_wait = [0.0]
	for cycle in 40:
		assert(walker.restyle_street_character(preset, true))
		walker.show()
		walker.set_meta("street_hail", "")
		game.mp_background_person_hail(0, "angry")
		for tap in 5:
			game._hail_background_person(0)
		await process_frame
		walker.set_meta("street_hail_time", 0.0)
		game._update_background_hail(0, 0.1)
		assert(walker._anim_player.current_animation == "burger/Walk_Away_Angry")
		await process_frame
	# Free the target while delayed angry replies are still pending.
	walker.queue_free()
	await create_timer(1.3).timeout
	game.queue_free()
	await process_frame
	print("STREET_HAIL_RECYCLE_OK: repeated clicks, angry transitions, model recycling, pending reply teardown")
	quit()
