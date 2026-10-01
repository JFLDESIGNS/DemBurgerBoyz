extends SceneTree
func _initialize(): call_deferred("run")
func run() -> void:
	create_timer(120).timeout.connect(func():push_error("HOTDOG_TIMEOUT");quit(1))
	var g = load("res://scenes/main.tscn").instantiate()
	g.set_script(load("res://tests/hotdog_challenge_fixture.gd"))
	root.add_child(g); current_scene = g
	g.playing = true; g._kitchen_ready = true
	g.stations = [{"items":[],"patties":[]}]
	var normal = Node3D.new();g.customers_root.add_child(normal);g.customers.append(normal)
	g._create_ticket(normal);g.selected_customer = normal
	var boss = g._ensure_hotdog_challenge()
	boss.set_process(false)
	var key = InputEventKey.new();key.keycode = KEY_PERIOD;key.pressed = true
	assert(boss.handle_key(key));assert(boss.phase == "rumble")
	assert(boss.music.playing and boss.music.stream.loop)
	assert(not normal.visible and normal.process_mode == Node.PROCESS_MODE_DISABLED)
	assert(g._challenge_blocks_spawns())
	assert(g.slot_camera_shake_t > 0)
	assert(not boss.start(),"Repeat trigger must not reset progress")
	var unique = {}
	for recipe in boss.recipes: unique[str(recipe)] = true
	assert(unique.size() == 26)
	for seed_value in range(12):
		var deck = boss.make_recipes(seed_value)
		assert(deck.size() == 26)
		for order in deck.slice(18):
			assert(order.count("patty") in [2,3] and order.size() >= 8 and order.size() <= 13)
	var smash_variants = {}
	for i in 6:
		boss.start_smash(); smash_variants[boss.clip] = true
	assert(smash_variants.has("hammer_double"))
	assert(smash_variants.has("hammer_left") or smash_variants.has("hammer_right"))
	boss.impact_at = -1
	assert(boss.customer.player.has_animation("revive"))
	boss.advance_phase();assert(boss.phase == "emerge")
	assert(boss.concrete.playing and boss.voice.playing)
	assert(boss.concrete.volume_db == -3.0 and boss.voice.volume_db == 2.0)
	assert(boss.voice.stream.resource_path.ends_with("bossahhhhhentrance.wav"))
	assert(boss.concrete.stream.get_length() <= 1.85)
	assert(is_equal_approx(boss.music.volume_db, linear_to_db(.62)), "Entrance voice must not lower music")
	for voice_kind in ["eat", "laugh", "wawawa", "revive_roar"]:
		boss.play_sound(voice_kind)
		assert(is_equal_approx(boss.music.volume_db, linear_to_db(.62)), "Boss voice must not lower music: " + voice_kind)
	boss.advance_phase();assert(boss.phase == "ready")
	assert(boss.next_order_preview.order == boss.recipe_at(1))
	assert(g.tickets[boss.next_order_preview].visible)
	assert(g.tickets[boss.next_order_preview].get_meta("timer_label").text == "UP NEXT")
	g._select_ticket(boss.next_order_preview)
	assert(g.selected_customer == boss.customer and not boss.next_order_preview.is_waiting)
	assert(not g._ticket_line_is_done("patty", ["patty"], boss.next_order_preview))
	assert(g._resolve_serve_customer() == boss.customer)
	var ticket_timer = g.tickets[boss.customer].get_meta("timer_label")
	assert(ticket_timer.text == "17.0s LEFT")
	boss.ambient_left = 20.0
	boss._process(10.0)
	assert(boss.can_serve() and boss.mistakes == 0)
	assert(ticket_timer.text == "7.0s LEFT")
	boss._process(2.1)
	assert(ticket_timer.text == "4.9s LEFT")
	assert(ticket_timer.get_theme_color("font_color") == Color("C62828"))
	var first = boss.customer.order.duplicate()
	g.stations[0].items = ["bun_bottom","patty","unknown_topping","bun_top"]
	g._complete_serve(0,boss.customer)
	boss._process(.01)
	assert(boss.phase == "attack" and boss.perfect == 0 and boss.mistakes == 1)
	assert(boss.customer.order == first,"Failed ticket stays frozen during the reaction")
	assert(not g._order_can_receive_burger(boss.customer))
	var before = boss.impact_serial
	boss._process(boss.timer*.6)
	assert(boss.impact_serial == before+1,"Hook must shake camera at impact")
	boss.advance_phase();assert(boss.phase == "smash")
	before = boss.impact_serial
	boss._process(boss.timer*.6)
	assert(boss.impact_serial == before+1,"Ground smash must shake camera at impact")
	assert(boss.impact_sound.playing and boss.effects.playing and boss.effects.stream in [boss.sound_streams["smash1"],boss.sound_streams["smash2"]])
	boss.advance_phase()
	assert(boss.customer.order != first, "Wrong orders must be replaced")
	# Expired orders count once, change recipe, and get a fresh seventeen seconds.
	var second = boss.customer.order.duplicate()
	boss._process(17.01)
	assert(boss.phase == "attack" and boss.mistakes == 2 and boss.failure_reason == "TIME UP!")
	boss.advance_phase(); boss.advance_phase()
	assert(boss.customer.order != second and boss.order_left == 17.0)
	# Ambient hammer pauses rather than resets the current order clock.
	boss.ambient_left = .01
	boss._process(.1)
	assert(boss.phase == "idle_smash")
	assert("PAUSED" in g.tickets[boss.customer].get_meta("timer_label").text)
	var remaining = boss.order_left
	boss._process(.05)
	assert(boss.order_left == remaining)
	boss.advance_phase()
	assert(boss.phase == "ready" and boss.order_left == remaining)
	assert(not "PAUSED" in g.tickets[boss.customer].get_meta("timer_label").text)
	boss.laugh_left = 20; boss.voice_left = 0
	boss.chatter_left = .01; boss._process(.02)
	assert(boss.voice.playing and is_equal_approx(boss.voice.pitch_scale,.58))
	boss.laugh_left = .01; boss.voice_left = 0; boss._process(.02)
	assert(boss.voice.playing and boss.voice.stream.resource_path.ends_with("laughboss.wav"))
	assert(boss.laugh_left >= 16)
	assert(is_equal_approx(boss.voice.pitch_scale,.70))
	assert(boss.voice_left > boss.voice.stream.get_length())
	assert(AudioServer.is_bus_effect_enabled(AudioServer.get_bus_index("BaronBratVoice"),1))
	# A valid handoff freezes the deadline even when the flight crosses it.
	boss.order_left = .01
	g._begin_customer_serve_handoff(boss.customer)
	boss._process(.5)
	assert(boss.phase == "feeding" and boss.order_left == .01 and boss.mistakes == 2)
	boss.begin_eating()
	assert(boss.clip == "eat_thrown_burger")
	boss.customer.start_eating_burger()
	assert(boss.voice.playing and boss.voice.stream.resource_path.ends_with("eatboss.wav"))
	assert(boss.eat_sound_played)
	boss.voice_left = .4
	boss.customer.chomp_burger()
	assert(boss.voice_left == .4, "Repeated bites must not restart the eating sound")
	g.stations[0].items = boss.customer.order.duplicate()
	g._complete_serve(0,boss.customer); boss._process(.01)
	assert(boss.perfect == 1)
	for i in range(1,15):
		assert(boss.phase == "ready")
		if i >= 10:
			assert(boss.customer.order.count("patty") in [2,3], "Final five must be multi-patty orders")
		if i < 14:
			assert(boss.next_order_preview.order == boss.recipe_at(i+1))
			assert(g.tickets[boss.next_order_preview].visible)
		else:
			assert(not g.tickets[boss.next_order_preview].visible, "Final burger has no phantom next order")
		g.stations[0].items = boss.customer.order.duplicate()
		g._complete_serve(0,boss.customer)
		# Duplicate completion cannot credit or advance the same burger twice.
		var paid = g.credited
		g._complete_serve(0,boss.customer)
		assert(g.credited == paid)
		boss._process(.01)
		assert(boss.perfect == i+1)
		if i+1 in [5,10]:
			assert(boss.phase == "slump")
			var hold = boss.timer - boss.customer.player.get_animation("slump").length
			assert(is_equal_approx(hold, 3.4 if i+1 == 10 else 1.35))
			boss.concrete.stop()
			boss.advance_phase();assert(boss.phase == "revive")
			assert(boss.timer <= .551 and boss.customer.player.speed_scale > 1.0)
			assert(boss.voice.playing and boss.voice.stream == boss.sound_streams["bossahhhhhentrance"])
			assert(not boss.concrete.playing, "Revival roars without replaying concrete breakout")
			boss.advance_phase()
			var recovery_clips = []
			var frozen_clock = boss.order_left
			for recovery_phase in ["revive_smash_first", "revive_smash_second"]:
				assert(boss.phase == recovery_phase and not boss.can_serve())
				assert(boss.customer.player.speed_scale == 1.0)
				recovery_clips.append(boss.clip)
				var impacts_before = boss.impact_serial
				boss._process(boss.timer * .6)
				assert(boss.impact_serial == impacts_before + 1)
				assert(boss.effects.playing and boss.impact_sound.playing)
				assert(boss.order_left == frozen_clock)
				boss._process(boss.timer + .01)
			assert(recovery_clips.has("hammer_double") and recovery_clips[0] != recovery_clips[1])
			assert(boss.phase == "ready" and boss.order_left == boss.ORDER_SECONDS)
	assert(boss.milestone_history == [5,10])
	assert(boss.phase == "victory")
	assert(boss.clip == "slump_defeat", "Final victory must use the real collapse")
	assert(boss.victory_played and not boss.music.playing)
	boss.advance_phase();assert(boss.phase == "sinking")
	boss._process(1.0)
	assert(boss.clip == "ground_exit" and boss.customer.position == boss.boss_position, "Ground stays in place while the skeleton sinks")
	assert(boss.customer.player.current_animation_position < boss.customer.player.get_animation("ground_breakout").length)
	boss._process(1.01)
	assert(boss.phase == "results" and is_instance_valid(boss.result_screen))
	assert(not boss.customer.visible and not boss.can_serve())
	boss._process(10)
	assert(boss.phase == "results", "Victory card waits for acknowledgement")
	boss.finish_results();assert(not boss.active() and boss.result_screen == null)
	assert(boss.next_order_preview == null and g.tickets.size() == 1)
	assert(not boss.music.playing and not boss.voice.playing and not boss.effects.playing and not boss.concrete.playing)
	assert(normal.visible and normal.process_mode == Node.PROCESS_MODE_INHERIT)
	assert(g.selected_customer == normal)
	assert(g.customers.size() == 1)
	assert(not g._challenge_blocks_spawns())
	assert(boss.start())
	boss.advance_phase(); boss.advance_phase()
	for loss in 3:
		boss._process(17.01)
		assert(boss.mistakes == loss+1)
		if loss < 2:
			assert(boss.phase == "attack")
			boss.advance_phase(); boss.advance_phase()
	assert(boss.phase == "defeat" and not boss.can_serve())
	boss.advance_phase(); assert(boss.phase == "defeat_laugh" and boss.voice.volume_db == 5.0)
	boss.advance_phase(); assert(boss.phase == "defeat_smash" and boss.clip == "hammer_double")
	var patty = load("res://scripts/patty.gd").new();g.add_child(patty);patty.heating=false;patty.cook_time=3.0;g.grill.append(patty)
	boss._process(boss.timer*.6)
	assert(is_instance_valid(patty._done_jump_tw) and patty.cook_time==3.0 and not patty.flipped_once)
	boss.advance_phase(); assert(boss.phase == "defeat_sinking" and boss.clip == "ground_exit")
	boss._process(boss.SINK_SECONDS+.01)
	assert(not boss.active() and not boss.music.playing and normal.visible)
	# Live hidden controls update the scene and persist the exact placement.
	var controls = VBoxContainer.new(); g.get_node("UI/Root").add_child(controls)
	boss.build_hidden_controls(controls)
	assert(boss.start())
	g.options_hidden_tree_light_sliders["hotdog_position_2"].value = 7.2
	g.options_hidden_tree_light_sliders["hotdog_scale"].value = 1.15
	assert(is_equal_approx(boss.customer.position.z,7.2))
	assert(boss.customer.scale.is_equal_approx(Vector3.ONE*1.15))
	var saved = ConfigFile.new(); assert(saved.load(boss.PLACEMENT_FILE) == OK)
	assert(is_equal_approx(saved.get_value("boss","scale"),1.15))
	g.options_hidden_tree_light_sliders["hotdog_position_2"].value = 6.3
	g.options_hidden_tree_light_sliders["hotdog_scale"].value = 1.0
	boss.cancel();assert(not boss.active())
	g.queue_free()
	await process_frame
	print("HOTDOG_CHALLENGE_OK: period trigger, 26 unique recipes, timed replacement, handoff clock, ambient smashes, voice, 5/10 milestones, finale stacks, victory card and sink, 3-loss defeat, placement controls, cleanup")
	quit()
