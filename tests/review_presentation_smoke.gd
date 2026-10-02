extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	create_timer(25).timeout.connect(func(): quit(1))
	root.size = Vector2i(1280,720)
	var game = load("res://scenes/main.tscn").instantiate()
	game.set_script(load("res://tests/main_ticket_harness.gd"))
	root.add_child(game); current_scene = game
	for child in game.get_node("UI/Root").get_children():
		if child is CanvasItem: child.hide()
	game._show_customer_review_ui(4.5, "My order: 100% accuracy, PERFECT 100%, SEASONED, fresh and ready. I'd come back!")
	assert(game._review_toast.offset_top == 202)
	var c = load("res://scripts/customer.gd").new()
	c.setup(["bun_bottom","patty","bun_top"] as Array[String],Color.WHITE,90.0,0,0,0,-1,{},true)
	game.add_child(c); c.set_process(false)
	c.position = Vector3(1.1304, .1, 2.25)
	c._celebrating = true
	c.step_aside_for_meal(c.global_position.x + 1.65)
	assert(not c._celebrating and c._anim_state == "walk")
	assert(c._anim_player.current_animation == c._walk_anim_path)
	await create_timer(.3).timeout
	c.set_physics_process(false)
	game._show_customer_review_ui(4.5, "My order: 100% accuracy, PERFECT 100%, SEASONED, fresh and ready. I'd come back!", c)
	await process_frame
	await process_frame
	var camera := root.get_camera_3d()
	var ui := game.get_node("UI/Root") as Control
	var body_ui := ui.get_global_transform_with_canvas().affine_inverse() * camera.unproject_position(c.global_position)
	print("REVIEW_PLACEMENT: ", game._review_toast.get_rect(), " body=", body_ui)
	assert(game._review_toast.position.x + game._review_toast.size.x < body_ui.x)
	assert(game._review_toast.offset_top == 202)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/customer_polish_qa/review_layout.png")
	print("REVIEW_PRESENTATION_OK: layout and immediate walk animation")
	for phase in ["dance", "review"]:
		c.remove_meta("review_made_room")
		c._leave_phase = phase
		c._leave_walk_x = c.global_position.x
		c._departure_review_shown = phase == "review"
		c._celebrating = phase == "dance"
		var start_x: float = c.global_position.x
		c.make_room_for_next_customer()
		assert(not c._celebrating and c._leave_phase == "turn_review_walk")
		c.make_room_for_next_customer()
		assert(is_equal_approx(c._leave_start_x, start_x + .6096))
		var walked := false
		for tick in 300:
			c._update_sidewalk_leave(.016)
			if c._leave_phase == "walk_to_review": walked = true
			if c._leave_phase == "review": break
		assert(walked and c._leave_phase == "review")
		assert(is_equal_approx(c.global_position.x, start_x + .6096))
		assert(c._departure_review_shown == (phase == "review"))
		for tick in 220: c._update_sidewalk_leave(.016)
		assert(c._departure_review_shown and c._leave_phase in ["turn_left2", "walk_off"])
	print("REVIEW_HANDOFF_OK: two-foot walk, dance cancellation, one review, departure")
	game.queue_free(); await process_frame; quit()
