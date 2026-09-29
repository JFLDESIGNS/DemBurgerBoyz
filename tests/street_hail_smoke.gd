extends SceneTree
const CUSTOMER = preload("res://scripts/customer.gd")

func _initialize(): call_deferred("run")

func run() -> void:
	create_timer(90).timeout.connect(func():push_error("STREET_HAIL_TIMEOUT");quit(1))
	var game = load("res://scenes/main.tscn").instantiate()
	game.set_script(load("res://tests/hotdog_challenge_fixture.gd"))
	root.add_child(game); current_scene = game
	game.playing = true; game.day_time = 300
	game.stations = [{"items":[],"patties":[]}]
	var counts = {"ignore":0,"angry":0,"join":0}
	for roll in 100: counts[game._street_hail_outcome(roll)] += 1
	assert(counts == {"ignore":50,"angry":10,"join":40})
	var preset = CUSTOMER.take_next_saved_character_preset()
	assert(not preset.is_empty())
	var walker = CUSTOMER.new()
	walker.is_street_pedestrian = true
	walker.setup([],Color.WHITE,9999,0,-1,0,-1,preset,true)
	game.customers_root.add_child(walker); walker.set_process(false)
	walker.position = Vector3(2,0,8.65)
	game.bg_people = [walker]; game.bg_people_active = [true]
	game.bg_people_dir = [1.0]; game.bg_people_wait = [0.0]
	assert(is_instance_valid(walker._wawa_click_area))
	assert(walker._wawa_click_area.get_child(0).shape is CapsuleShape3D)
	game.mp_background_person_hail(0,"ignore")
	assert(game.burgerpals_startup_player.playing)
	game._hail_background_person(0)
	assert(walker.get_meta("street_hail") == "ignore", "Repeated clicks must preserve the first roll")
	assert(not game._update_background_hail(0,.1))
	assert(game.customers.is_empty())
	walker.set_meta("street_hail", "")
	game.mp_background_person_hail(0,"angry")
	assert(walker._anim_player.current_animation == "burger/Point_Finger_Yell")
	assert(walker.rotation_degrees.y == CUSTOMER.FACE_TRUCK_YAW)
	var origin = walker.position
	assert(game._update_background_hail(0,.1) and walker.position == origin)
	walker.set_meta("street_hail_time",0.0)
	assert(not game._update_background_hail(0,.01))
	assert(walker._anim_player.current_animation == "burger/Walk_Away_Angry")
	assert(walker._anim_player.get_animation("burger/Walk_Away_Angry").loop_mode == Animation.LOOP_LINEAR)
	walker.set_meta("street_hail", "")
	game.mp_background_person_hail(0,"join")
	# A closed window defers the accepted invitation instead of changing the roll.
	game.service_window_closed = true
	assert(game._update_background_hail(0,.1) and game.customers.is_empty())
	game.service_window_closed = false
	assert(game._update_background_hail(0,.1))
	assert(game.customers.size() == 1 and not walker.visible and not game.bg_people_active[0])
	assert(walker._wawa_click_area.collision_layer == 0)
	var customer = game.customers[0]
	customer.set_process(false)
	assert(customer.get_custom_character_preset() == preset)
	assert(customer.global_position == origin and customer.get_meta("street_join_approach"))
	var destination = Vector3(customer.target_x,CUSTOMER.STAND_Y,2.25)
	var before = customer.global_position.distance_to(destination)
	customer._advance_customer(.25)
	assert(customer.global_position.distance_to(destination) < before)
	for i in 100:
		if not customer.has_meta("street_join_approach"): break
		customer._advance_customer(.1)
	assert(not customer.has_meta("street_join_approach"))
	assert(customer.global_position.distance_to(destination) < .1)
	game.queue_free(); await process_frame
	print("STREET_HAIL_OK: exact 50/10/40 odds, greeting, no reroll, pointing, angry exit, deferred queue, same character approaches truck")
	quit()
