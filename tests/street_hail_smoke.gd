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
	assert(walker.get_node("HailAccepted").visible)
	assert("ON MY WAY" in walker.get_node("HailAccepted").text)
	assert(game._update_background_hail(0,.3) and walker.position == origin)
	assert(game.customers.is_empty(), "Acceptance should be shown before departing")
	game._update_background_hail(0,.3)
	assert(walker.get_meta("street_hail") == "join_exit")
	game._update_background_hail(0,.2)
	assert(walker.position.x < origin.x and walker.visible, "Walker must quickly leave screen-right")
	assert(game.customers.is_empty(), "Replacement must not appear before walker exits")
	# A closed window preserves the accepted invitation offscreen.
	game.service_window_closed = true
	for i in 30: game._update_background_hail(0,.1)
	assert(walker.get_meta("street_hail") == "join_wait")
	assert(not walker.visible and game.customers.is_empty())
	assert(game.bg_people_active[0], "Reserved walker cannot be recycled before the matching customer spawns")
	game.service_window_closed = false
	assert(game._update_background_hail(0,.1))
	assert(game.customers.size() == 1 and not walker.visible and not game.bg_people_active[0])
	assert(walker._wawa_click_area.collision_layer == 0)
	var customer = game.customers[0]
	customer.set_process(false)
	assert(customer != walker and not customer.is_street_pedestrian)
	assert(customer.get_custom_character_preset() == preset)
	assert(customer.get_customer_voice() == walker.get_customer_voice())
	assert(customer.position == Vector3(-6.5,CUSTOMER.STAND_Y,2.25))
	assert(customer.scale == Vector3.ONE and not customer.has_meta("street_join_approach"))
	var destination = Vector3(customer.target_x,CUSTOMER.STAND_Y,2.25)
	var before = customer.global_position.distance_to(destination)
	customer._advance_customer(.25)
	assert(customer.global_position.distance_to(destination) < before, "Matching customer uses normal entrance movement")
	game._update_background_hail(0,.1)
	assert(game.customers.size() == 1, "Invitation should create only one customer")
	game.queue_free(); await process_frame
	print("STREET_HAIL_OK: exact 50/10/40 odds, greeting, no reroll, angry exit, acceptance badge, quick right exit, deferred queue, matching separate customer at normal entrance")
	quit()
