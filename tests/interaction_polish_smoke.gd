extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280,720); root.content_scale_size = Vector2i(1280,720)
	create_timer(90).timeout.connect(func(): quit(1))
	var game = load("res://scenes/main.tscn").instantiate()
	game.set_script(load(get_script().resource_path.get_base_dir().path_join("interaction_delivery_fixture.gd")))
	root.add_child(game); current_scene = game; game.get_node("UI").hide()
	for i in game.STATION_COUNT: game.stations.append({})
	game.playing = true
	game.supply_stock["cheese"] = 5
	var cheese_button := Button.new(); cheese_button.position = Vector2(50,50); cheese_button.size = Vector2(140,80); game.add_child(cheese_button); game.ingredient_buttons["cheese"] = cheese_button
	game.pointer = Vector2(100,90)
	var press := InputEventMouseButton.new(); press.button_index = MOUSE_BUTTON_LEFT; press.pressed = true; press.position = game.pointer
	game._handle_strip_swipe_input(press)
	game.pointer = Vector2(101,82)
	var drag_event := InputEventMouseMotion.new(); drag_event.position = game.pointer
	game._handle_strip_swipe_input(drag_event)
	assert(game.cheese_held and game._cheese_lmb_drag, "An eight-pixel upward drag should immediately grab cheese")
	game._cancel_cheese_hold_silent(); cheese_button.queue_free(); game.ingredient_buttons.clear()
	var active := Node3D.new(); var queued := Node3D.new(); game.add_child(active); game.add_child(queued)
	game.selected_customer = active
	for ingredient in ["bun_bottom", "patty", "cheese", "bun_top"]:
		assert(game._ticket_line_is_done(ingredient, [ingredient], active))
		assert(not game._ticket_line_is_done(ingredient, [ingredient], queued), "Suborders cannot borrow the current burger")
	game.selected_customer = queued
	assert(game._ticket_line_is_done("cheese", ["cheese"], queued))
	assert(not game._ticket_line_is_done("cheese", ["cheese"], active))
	var camera := Camera3D.new(); game.add_child(camera); camera.position = Vector3(0,.65,1.2); camera.look_at(Vector3(0,.03,0)); camera.current = true; game.camera = camera
	var light := DirectionalLight3D.new(); game.add_child(light); light.rotation_degrees = Vector3(-45,-30,0)
	var env := WorldEnvironment.new(); env.environment = Environment.new(); env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color("544e47"); env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color.WHITE; env.environment.ambient_light_energy = .8; game.add_child(env)
	var patties := []
	for i in 3:
		var p = load("res://scripts/patty.gd").new(); game.world.add_child(p); p.set_process(false); p.position = Vector3((i-1)*.32,0,0); p.base_y = 0; p.cook_time = 12; p._update_cook_gradient(); p._update_frost_visual(); p._set_hint_mode("cooking", "COOKING...", Color("FFD16A")); p._update_hint_scale(1); p._top_bubbles.emitting = true; patties.append(p)
	game.grill = patties
	await process_frame
	var center := camera.unproject_position(patties[1].global_position + Vector3(0,.03,0))
	assert(game._pick_cheese_patty_at_screen(center + Vector2(0,50)) == patties[1], "Forgiving cheese drop radius")
	patties[1].has_cheese = true
	assert(game._pick_cheese_patty_at_screen(center) != patties[1], "Already cheesed patties cannot steal a drop")
	patties[1].has_cheese = false
	game._ensure_cheese_ghost(); game.cheese_ghost.visible = true; game.cheese_ghost.position = patties[0].get_cheese_seat_global(); game.cheese_ghost.position.y += .01
	assert(game.cheese_ghost_mat.render_priority > patties[0].PATTY_BODY_PRIORITY)
	if DisplayServer.get_name() != "headless":
		await create_timer(1).timeout; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://output/cooking_polish.png"))
	for p in patties: p.hide()
	game.cheese_ghost.hide()
	var c = load("res://scripts/customer.gd").new(); c.setup(["bun_bottom","patty","bun_top"] as Array[String],Color.WHITE,90,0,0,0,-1,{"format_version":11,"body_type":"kenney_chunky_toon","top_catalog_version":1,"top_style":1,"bottom_catalog_version":1,"bottom_style":2,"hair_style":3},true); game.add_child(c); c.is_waiting = true; c.set_process(false)
	c.position = Vector3.ZERO; c.rotation = Vector3.ZERO
	var life = c.get_node("CustomerLife"); life.set_process(false)
	var seen := {}
	for i in 80:
		var previous: int = life.away_target_index
		life.choose_away_target(Vector3(0,1,3)); seen[life.away_target_index] = true
		assert(life.away_target_index != previous)
	assert(seen.size() == 4)
	c._play_burger_clip("Idle_Forward"); life.forced_target = Vector3(2,1.5,3)
	for i in 90: life._process(1.0/60.0)
	assert(life.look.look_weight > .8, "Head must follow the same attention target as eyes")
	assert(absf(life.body_yaw) > .1 and absf(life.body_yaw) <= .301)
	camera.position = Vector3(.2,1.1,3.4); camera.look_at(Vector3(0,1,0))
	if DisplayServer.get_name() != "headless":
		await create_timer(.2).timeout; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://output/gaze_polish.png"))
	c._play_burger_clip("Phone_Two_Hands")
	for i in 90: life._process(1.0/60.0)
	assert(absf(life.body_yaw) > .18, "Phone pose turns the body")
	if DisplayServer.get_name() != "headless":
		life.modular.top_style = 1
		life.forced_target = Vector3.INF
		life.look.look_weight = 0.0
		c._body.rotation.y = 0
		camera.position = Vector3(.7,1.3,2.1); camera.look_at(Vector3(0,1.15,0))
		var player: AnimationPlayer = c._anim_player
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for motion in ["grill_dance", "run"]:
			if motion == "run": c.play_street_run(1.0)
			else: c._play_anim(motion)
			for frame in [0.25,0.5,0.75]:
				player.advance(frame)
				await process_frame; await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://output/sleeve_%s_%s.png" % [motion,str(frame)]))
	c.react_burnt_bite(true); assert(c._shake_rate <= .25 and c._shake_time <= 1.05)
	c.is_waiting = false
	for i in 180: life._process(1.0/60.0)
	assert(absf(life.body_yaw) < .001 and life.look.look_weight < .001, "Attention releases on serving and leaving")
	if DisplayServer.get_name() != "headless":
		c.hide()
		var overlay := Control.new(); game.add_child(overlay)
		var burst: Node2D = game._make_burger_completion_burst(); overlay.add_child(burst); burst.show(); burst.position = Vector2(640,360); burst.rotation = -.1; game._update_burger_completion_burst(burst,.4)
		game.stations[0]["items"] = ["bun_bottom","patty","lettuce","tomato","bun_top"]
		game.stations[0]["patties"] = []
		var built: Dictionary = game._build_serve_fly_stack(overlay,0)
		built.stack.pivot_offset = built.pivot
		game._place_burger_sprite_center(built.stack, Vector2(640,360))
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://output/burger_burst_polish.png"))
	print("INTERACTION_POLISH_OK")
	game.queue_free(); await process_frame; quit()
