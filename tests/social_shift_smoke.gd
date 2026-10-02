extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	create_timer(100).timeout.connect(func(): push_error("SOCIAL_TIMEOUT"); quit(1))
	var game = load("res://scenes/main.tscn").instantiate()
	game.set_script(load(get_script().resource_path.get_base_dir().path_join("social_shift_fixture.gd")))
	root.add_child(game); current_scene = game; game.playing = true
	assert(game._shift_length() == 900.0)
	game.day = 2; assert(game._shift_length() == 900.0)
	game.day = 3; assert(game._shift_length() == 900.0)
	assert(not "mail cat" in game.BOSS_FRYER_ADVICE.to_lower())
	var cat = load("res://scripts/window_cat.gd").new()
	var calls = []
	cat.wants_meow.connect(func(pitch): calls.append(pitch))
	cat._state = "peek"; cat.visible = true
	cat._update_begging_meows(5.99); assert(calls.is_empty())
	cat._update_begging_meows(.02); assert(calls.size()==1)
	cat._visit_fed = true; cat._update_begging_meows(20.0); assert(calls.size()==1)
	cat.free()
	var social = load("res://scripts/customer_social.gd").new()
	social.game = game; game.add_child(social); social.set_process(false); game._customer_social = social
	var counts = {"reply":0,"away":0,"love":0,"quiet":0}
	for i in 100: counts[social.outcome((i+.5)/100.0)] += 1
	assert(counts == {"reply":65,"away":20,"love":2,"quiet":13})
	var customers = []
	for i in 2:
		var c = load("res://scripts/customer.gd").new()
		c.setup(["bun_bottom","patty","bun_top"] as Array[String],Color.WHITE,90.0,i,0,0,-1,{},true)
		game.customers_root.add_child(c); c.set_process(false)
		c.is_waiting = true; c.position = Vector3(i*1.3,.1,2.25)
		c.order_elapsed_sec = 12.0+i
		game.customers.append(c); customers.append(c)
	game.selected_customer = customers[0]
	social.pair_customers(customers[0],customers[1])
	assert(game.tickets[customers[0]].visible and game.tickets[customers[1]].visible)
	for c in customers:
		assert(game.tickets[c].get_meta("title_label").text.ends_with(" ♥"))
	assert(customers[0].order_elapsed_sec==12.0 and customers[1].order_elapsed_sec==13.0)
	assert(social.partner(customers[0]) == customers[1] and social.couples.size()==1)
	game._remove_ticket(customers[0]); game.selected_customer=customers[1]; game._highlight_tickets()
	assert(game.tickets[customers[1]].visible,"Second meal becomes the main slip")
	game._begin_ticket_transition(); game._highlight_tickets()
	assert(not game.tickets[customers[1]].visible)
	await create_timer(.4).timeout; game._highlight_tickets(); assert(game.tickets[customers[1]].visible)
	var live_cat = load("res://scripts/window_cat.gd").new()
	game.add_child(live_cat); live_cat.set_process(false); game.window_cat = live_cat
	live_cat._state = "peek"; live_cat.visible = true; live_cat._timer = 8.0
	live_cat.position = Vector3(2.1,.74,2.01)
	live_cat.react_to_customer(customers[0],true); assert(live_cat._hearts.emitting)
	live_cat.react_to_customer(customers[0],false); assert(live_cat._state == "social_swat")
	live_cat._process(.6); assert(live_cat._state == "running" and live_cat._fat == 0.0)
	live_cat._set_chonk_fraction(1.0)
	live_cat.position = Vector3(0,.1,0)
	var walker = Node3D.new(); game.add_child(walker); walker.position=Vector3(-3,.1,0)
	var closest = 100.0
	for i in 400:
		walker.position = preload("res://scripts/crowd_spacing.gd").steer(walker,walker.position,walker.position+Vector3(.025,0,0),[live_cat],.016)
		closest = minf(closest,Vector2(walker.position.x,walker.position.z).length())
	assert(walker.position.x > 2.5 and closest >= 1.79,"Walkers route around even the giant cat")
	walker.queue_free(); live_cat.queue_free()
	for stars in [1.0,2.5,4.5]:
		customers[0].set_meta("meal_stars",stars)
		customers[0].complete_serve(10,true)
		assert(not customers[0]._leave_do_dance and not customers[0].get_meta("five_star_dance"))
	var previous = 6.0
	for seconds in [5.0,15.0,16.0,26.0,46.0,86.0]:
		var rating = game._review_stars_from_serve(10,false,false,{"stars":5.0,"wait":seconds},1.0)
		assert(rating <= previous)
		if seconds > 15.0: assert(rating < 5.0)
		previous = rating
	customers[0].set_meta("meal_stars",5.0)
	customers[0]._leave_start_x = 1.5
	customers[0]._leave_dance_x = 1.5
	customers[0]._leave_phase = "dance"; customers[0]._leave_dance_started = true; customers[0]._leave_dance_done = true
	customers[0]._update_sidewalk_leave(.01)
	assert(is_equal_approx(customers[0].global_position.x, 1.5))
	assert(customers[0]._leave_phase == "review")
	assert(customers[0]._anim_player.current_animation == "burger/Phone_Two_Hands")
	customers[0]._update_sidewalk_leave(.6)
	assert(customers[0]._departure_review_shown and not customers[0]._review_card_is_showing())
	assert(is_instance_valid(game._review_toast))
	var first_review = game._review_toast
	customers[0]._show_departure_review()
	assert(game._review_toast == first_review, "Review must only appear once")
	customers[1].set_meta("meal_aside", true)
	customers[1]._begin_sidewalk_leave(false)
	assert(customers[1]._leave_phase == "review", "Non-dancers review at their current meal spot")
	customers[1].is_leaving = false
	game._show_boss_caption("THE BOSS", "Kitchen paused while I explain this upgrade.", 2.0)
	assert(game._boss_speech_active() and is_instance_valid(game._boss_speech_bubble))
	var frozen_patty = load("res://scripts/patty.gd").new()
	game.add_child(frozen_patty)
	frozen_patty.heating = true
	var before_cook: float = frozen_patty.cook_time
	frozen_patty._process(1.0)
	assert(frozen_patty.cook_time == before_cook, "Boss speech must freeze patty cooking")
	game._hide_boss_caption()
	assert(not game._boss_speech_active())
	frozen_patty.queue_free()
	customers[1]._play_burger_clip("Point_Finger_Yell")
	var feet = customers[1].get_node("CharacterFootsteps")
	feet._update_point_voice(); assert(feet.point_voice.playing and feet.point_voice.pitch_scale > 1.0)
	customers[1]._play_burger_clip("Idle_Forward"); feet._update_point_voice(); assert(not feet.point_voice.playing)
	customers[1].set_meta("recruited_running",true); customers[1].play_street_run(1.25)
	assert(customers[1]._anim_player.current_animation.ends_with("/Run"),"Recruited customers must actually run, not just move faster")
	feet._process(.01); assert(feet.audio.stream == feet.COURIER_RUN and feet.audio.volume_db < -10.0)
	customers[1].set_meta("recruited_running",false); feet._process(.01); assert(not feet.audio.playing)
	game.fryer_root = load("res://assets/machines/fryer.glb").instantiate(); game.add_child(game.fryer_root)
	game._show_boss_machine(game.SHOP_FRYER_MACHINE,2.0)
	var showcase = game.get_node("UI/Root/BossMachineShowcase")
	assert(showcase.price.text == "$100" and showcase.turntable.get_child_count()==1)
	social.spawn_couple(social.couples[0]); assert(social.walkers.size()==2)
	var first_walker = social.walkers[0].get_ref()
	var second_walker = social.walkers[1].get_ref()
	assert(first_walker.scale == Vector3.ONE * game._bg_people_scale())
	var offset = second_walker.position-first_walker.position
	var before_hearts = first_walker.get_child_count()
	first_walker.set_meta("couple_heart_left",0.0)
	social._process(.25)
	assert((second_walker.position-first_walker.position).is_equal_approx(offset), "Couples keep their spacing at one shared speed")
	assert(first_walker.get_child_count()>before_hearts, "Background couples occasionally emit fresh hearts")
	game.start_overlay.hide()
	game.flash_label.text = game.BOSS_FRYER_ADVICE
	game.flash_label.show(); game._layout_flash_label()
	if DisplayServer.get_name() != "headless":
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://output/social_showcase.png"))
	print("SOCIAL_SHIFT_OK")
	game.queue_free(); await process_frame; quit()
