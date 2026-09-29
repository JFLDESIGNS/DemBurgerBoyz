extends SceneTree
func _initialize(): call_deferred("run")
func run() -> void:
	create_timer(240).timeout.connect(func():push_error("HOTDOG_GAME_TIMEOUT");quit(1))
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game);current_scene=game
	while not game.menu_ready: await process_frame
	await game._start_game(false)
	game._clear_bts_day_intro(false)
	game._clear_customers()
	game._bts_day1_performance_done = true
	game._boss_intro_running = false
	game.spawn_timer = 99999
	assert(game._hotdog_challenge.start())
	await create_timer(4).timeout
	var boss = game._hotdog_challenge
	assert(boss.phase == "ready")
	assert(game.tickets.has(boss.customer))
	assert(not game.shadow_catcher_root.visible)
	assert(boss.street_saved.size() == 2)
	for spectator in game.bg_people:
		assert(spectator.visible and spectator._anim_state == "idle")
		assert(spectator._wawa_click_area.collision_layer == 0)
		var head_pos = game.camera.unproject_position(spectator.to_global(Vector3(0,1.33,0)))
		assert(root.get_visible_rect().has_point(head_pos), "Spectators must be visible on the sides")
		var across = head_pos.x / root.get_visible_rect().size.x
		assert(across < .22 or across > .78, "Spectators should watch from the background edges")
	var matte_surfaces = 0
	for mesh in boss.customer.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var material = mesh.get_active_material(surface)
			if material is StandardMaterial3D and "Liquorice" in material.resource_name:
				assert(material.disable_receive_shadows and material.metallic_specular == 0)
				matte_surfaces += 1
	assert(matte_surfaces > 0)
	var ticket_timer = game.tickets[boss.customer].get_meta("timer_label")
	assert(ticket_timer.text == "%.1fs LEFT" % boss.order_left)
	assert(boss.order_left > 10 and boss.order_left <= 17)
	assert(boss.customer.player.is_playing())
	assert(not game.camera.is_position_behind(boss.customer.mouth_global()))
	var point = game.camera.unproject_position(boss.customer.mouth_global())
	assert(root.get_visible_rect().has_point(point),"Boss mouth must be visible from kitchen")
	var clock = game.day_time
	await create_timer(.25).timeout
	assert(is_equal_approx(clock,game.day_time),"Boss challenge pauses shift clock")
	# Exercise the actual physics click path for a visible sidewalk walker.
	boss.cancel()
	assert(game.shadow_catcher_root.visible and boss.street_saved.is_empty())
	game._start_background_person(0)
	var walker = game.bg_people[0]
	walker.position = Vector3(1,game._bg_people_y(),game._bg_people_z())
	await physics_frame; await physics_frame
	var head = walker.to_global(Vector3(0,1.33,.06))
	var click = game.camera.unproject_position(head)
	assert(game._try_customer_wawa_click(click), "Clicking a visible walker must reach the hail handler")
	assert(str(walker.get_meta("street_hail", "")) in ["ignore","angry","angry_walk","join"])
	assert(game.burgerpals_startup_player.playing)
	print("STREET_CLICK_GAMEPLAY_OK: real kitchen raycast, visible pedestrian, greeting and reaction")
	print("HOTDOG_GAMEPLAY_OK: real kitchen, ticket, model, animation, visible mouth, frozen shift clock")
	if "--stay" in OS.get_cmdline_user_args(): return
	game.queue_free()
	await process_frame
	quit()
