extends SceneTree

class TicketCustomer extends Node3D:
	var order: Array[String] = ["bun_bottom", "patty", "patty", "tomato", "lettuce", "pickle", "ketchup", "bun_top"]
	var is_waiting := true
	var is_leaving := false
	var is_challenge_guest := false
	var order_elapsed_sec := 0.0
	var running := false
	func patience_ratio() -> float: return 0.82
	func stop_order_clock() -> void: running = false
	func start_order_clock(_reset: bool = false) -> void: running = true
	func set_queue_timer_active(_active: bool) -> void: pass

var failures: Array[String] = []
var visual := false
var output := ""

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _initialize() -> void: call_deferred("run")

func screenshot(name: String) -> void:
	if not visual: return
	for frame in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))

func run() -> void:
	create_timer(35.0).timeout.connect(func(): push_error("Ticket test timed out"); quit(1))
	visual = "--visual" in OS.get_cmdline_user_args()
	output = OS.get_environment("BURGER_PROBE_OUTPUT")
	if output.is_empty(): output = ProjectSettings.globalize_path("res://build/ticket_release")
	DirAccess.make_dir_recursive_absolute(output)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var game = load("res://scenes/main.tscn").instantiate()
	game.set_script(load(get_script().resource_path.get_base_dir().path_join("main_ticket_harness.gd")))
	root.add_child(game)
	current_scene = game
	game.set_process_input(false)
	for child in game.get_node("UI/Root").get_children():
		if child is CanvasItem: child.hide()
	game.get_node("UI/Root/WindowTicketRail").show()
	var first := TicketCustomer.new()
	var second := TicketCustomer.new()
	second.order = ["bun_bottom", "patty", "cheese", "bun_top"] as Array[String]
	game.add_child(first)
	game.add_child(second)
	game.customers.append(first)
	game.customers.append(second)
	game.selected_customer = first
	game._create_ticket(first)
	game._create_ticket(second)
	var main: Control = game.tickets[first]
	var queued: Control = game.tickets[second]
	var motion = main.get_meta("ticket_motion")
	motion.set_process(false)
	motion._player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for i in 8: await process_frame
	expect(motion.active and motion.state == &"fly", "Main ticket should begin with a rolled flight")
	expect(not motion._thumbtack.visible, "Pin must stay hidden during flight")
	expect(motion.position.length() > 100.0, "Ticket must start away from its final position")
	motion._advance_arrival(0.22)
	await screenshot("main_ticket_fly")
	motion._advance_arrival(0.4)
	expect(motion.state == &"unroll" and motion.position.is_zero_approx(), "Ticket must land before unrolling")
	expect(not motion._thumbtack.visible, "Pin must stay hidden while the ticket unrolls")
	expect(is_equal_approx(motion._player.speed_scale, 1.6), "Order must unroll in 0.75 seconds")
	expect(is_equal_approx(motion.PIN_SECONDS, 0.26), "Main tack placement must take 0.26 seconds")
	expect(not queued.has_meta("ticket_motion"), "Waiting paper must remain static")
	expect(queued.has_meta("queued_tack") and queued.get_meta("queued_tack").visible, "Every queued ticket needs its 3D thumbtack")
	var queued_note: Control = queued.get_meta("ticket_note")
	var queued_pin: Control = queued.get_meta("queued_tack")
	expect(is_equal_approx(queued_note.position.y, -15.0), "Queued paper must move up 15 pixels")
	expect(is_equal_approx(queued_pin.DURATION, 0.26), "Queued tack placement must take 0.26 seconds")
	expect(is_equal_approx(queued_pin.sound.volume_db, -6.0), "Queued tack sounds must be 10 dB louder")
	var fixed_pin_position := queued_pin.position
	queued_note.position.y = 0.0
	queued_pin.sync_layout()
	expect(queued_pin.position.is_equal_approx(fixed_pin_position), "Moving paper must leave its tack in place")
	queued_note.position.y = -15.0
	queued_pin.sync_layout()
	expect(motion._note.position.is_zero_approx(), "Main 3D ticket must retain its position")
	expect(not main.get_meta("queued_tack").visible, "Selected ticket must not show two thumbtacks")
	expect(main.get_meta("ticket_note").get_parent() == motion._source, "Original live labels must render onto the mesh")
	expect(queued.get_meta("ticket_note").get_parent() == queued, "Waiting ticket remains ordinary static UI")
	motion._player.seek(0.48, true)
	motion._update_roll_view()
	await screenshot("main_ticket_unroll")
	motion._player.advance(1.3)
	expect(motion.state == &"pin" and motion._thumbtack.visible, "Unroll must finish before the red thumbtack is placed")
	motion._advance_arrival(0.19)
	await screenshot("main_ticket_pinning")
	motion._advance_arrival(0.8)
	expect(motion.state == &"static", "Placed ticket must settle at rest")
	expect(is_zero_approx(float(motion._paper_material.get_shader_parameter("curl_lighting"))), "Open paper must have even color without corner lighting")
	expect(motion._thumbtack.position.is_equal_approx(motion._pin_target), "Thumbtack must seat in the paper")
	expect(is_equal_approx(motion._audio.volume_db, -1.0), "Main tack impact must be 10 dB louder")
	var seated_pin: Transform3D = motion._thumbtack.transform
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	main.gui_input.emit(click)
	expect(motion.state == &"tap", "Clicking the selected ticket should play tap")
	expect(is_equal_approx(motion._audio.volume_db, -3.0), "Paper taps must play 10 dB louder")
	expect(game.selected_customer == first, "A tap must not change the selected order")
	motion._player.advance(0.8)
	expect(motion.state == &"static", "Tap should return to rest")
	expect(motion._thumbtack.transform.is_equal_approx(seated_pin), "Thumbtack must stay seated during taps")
	motion._wind_left = 0.01
	motion._process(0.02)
	expect(motion.state == &"wave", "Idle main ticket should occasionally breeze")
	motion._player.seek(0.7, true)
	var paper_skeleton := motion._find_type(motion._model, "Skeleton3D") as Skeleton3D
	var anchor := paper_skeleton.find_bone("anchor")
	var rest_clip: Animation = motion._player.get_animation(motion._clips["static"])
	var anchor_rest := Quaternion.IDENTITY
	for track in rest_clip.get_track_count():
		if rest_clip.track_get_type(track) == Animation.TYPE_ROTATION_3D and String(rest_clip.track_get_path(track)).ends_with(":anchor"):
			anchor_rest = rest_clip.track_get_key_value(track, 0)
	expect(paper_skeleton.get_bone_pose_rotation(anchor).angle_to(anchor_rest) < 0.001, "Timed breeze must preserve the pinned anchor, not flip the paper out of view")
	await screenshot("main_ticket_breeze")
	motion._player.advance(3.0)
	expect(motion.state == &"static" and motion._wind_left >= 9.0, "Breeze must finish and leave a quiet interval")
	motion._player.advance(2.0)
	var wait_before: float = motion._wind_left
	motion._process(1.0)
	expect(is_equal_approx(motion._wind_left, wait_before - 1.0), "Static clip completion must not continually reset wind timer")
	# Run three minutes of actual idle/breeze animation, not just state timers.
	var breeze_count := 0
	var last_state: StringName = motion.state
	var max_anchor_error := 0.0
	var unexpected_state := false
	for frame in 5400:
		motion._process(1.0 / 30.0)
		motion._player.advance(1.0 / 30.0)
		max_anchor_error = maxf(max_anchor_error, paper_skeleton.get_bone_pose_rotation(anchor).angle_to(anchor_rest))
		unexpected_state = unexpected_state or motion.state not in [&"static", &"wave"]
		if motion.state == &"wave" and last_state != &"wave": breeze_count += 1
		last_state = motion.state
		if frame % 150 == 0: game._highlight_tickets()
	expect(breeze_count >= 5, "Idle regression must exercise multiple timed breezes")
	expect(not unexpected_state, "Elapsed time and UI refreshes must never restart or retract the order")
	expect(max_anchor_error < 0.001, "Active ticket must stay pinned and upright throughout every idle breeze")
	print("TICKET_IDLE_STABILITY breezes=", breeze_count, " max_anchor_error=", max_anchor_error)
	motion._play(&"static", 0.0)
	motion._player.advance(0.0)
	first.order_elapsed_sec = 12.4
	game._refresh_ticket_patience_bars()
	expect(main.get_meta("timer_label").text == "12.4s", "Live timer must keep updating inside the texture")
	expect(is_equal_approx(main.get_meta("patience_bar").value, 0.82), "Live patience meter must remain connected")
	game.stations.clear()
	for station in game.STATION_COUNT:
		game.stations.append({"items": ["bun_bottom", "patty", "patty", "tomato"]})
	game._refresh_ticket_checkmarks()
	var rows: Control = main.get_meta("lines_box")
	expect(rows.get_child(0).get_node("Check").text == String.chr(0x2713), "Ingredient checkmarks must update on the animated paper")
	if visual:
		var actual_click := InputEventMouseButton.new()
		actual_click.position = main.global_position + Vector2(80, 95)
		actual_click.global_position = actual_click.position
		actual_click.button_index = MOUSE_BUTTON_LEFT
		actual_click.pressed = true
		Input.parse_input_event(actual_click)
		for i in 2: await process_frame
		expect(motion.state == &"tap", "Viewport mouse picking must reach the animated main ticket")
		actual_click = actual_click.duplicate()
		actual_click.pressed = false
		Input.parse_input_event(actual_click)
		motion._player.advance(0.8)
	var prior_height: float = motion._logical_size.y
	var quantity: Label = main.get_meta("qty_label")
	quantity.text = "3 LEFT"
	quantity.show()
	for i in 4: await process_frame
	expect(motion._logical_size.y > prior_height, "Live quantity rows must resize the paper viewport")
	quantity.hide()
	for i in 4: await process_frame
	var old_title: Label = main.get_meta("title_label")
	game._highlight_tickets()
	expect(motion.state == &"static", "Repeated highlights must not restart the entrance")
	expect(old_title == main.get_meta("title_label"), "Rendering must retain original live control identities")
	expect(is_equal_approx(motion.PIN_SCALE, 3.6), "Thumbtack must be twice its previous scale")
	expect(motion._header_clearance.custom_minimum_size.y == 8.0, "Main ticket top clearance must be reduced")
	expect(motion._tap_sound != null and motion._tap_sound.get_length() > 0.1, "Paper tap sound must be packaged")
	expect(motion._rustle_sound != null, "Paper pull/roll sound must be packaged")
	await screenshot("main_ticket_idle")
	# Corner pulls select the authored shake and capture release outside the ticket.
	var corner := InputEventMouseButton.new()
	corner.button_index = MOUSE_BUTTON_LEFT
	corner.pressed = true
	corner.position = motion.get_transform() * Vector2(8.0, motion._logical_size.y - 8.0)
	main.gui_input.emit(corner)
	expect(motion._grabbed, "Pressing a bottom corner must grab the paper")
	var drag := InputEventMouseMotion.new()
	drag.position = motion._press_screen + Vector2(-65.0, 38.0)
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion._input(drag)
	expect(motion.state == &"shake" and motion._drag_started, "Pulling a corner must play the shake clip")
	motion._player.seek(0.2, true)
	await screenshot("main_ticket_corner_pull")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	motion._input(release)
	expect(not motion._grabbed and not motion.is_processing_input(), "Release outside the ticket must clear the grab")
	motion._player.advance(0.9)
	if visual:
		var real_corner := InputEventMouseButton.new()
		real_corner.button_index = MOUSE_BUTTON_LEFT
		real_corner.pressed = true
		real_corner.position = motion.get_global_transform_with_canvas() * Vector2(10.0, motion._logical_size.y - 10.0)
		real_corner.global_position = real_corner.position
		Input.parse_input_event(real_corner)
		for i in 2: await process_frame
		expect(motion._grabbed, "Real viewport input must grab the paper corner")
		var real_drag := InputEventMouseMotion.new()
		real_drag.position = real_corner.position + Vector2(-65.0, 45.0)
		real_drag.relative = Vector2(-65.0, 45.0)
		real_drag.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(real_drag)
		for i in 2: await process_frame
		expect(motion.state == &"shake", "Real corner drag outside the ticket must shake it")
		expect(motion._audio.stream == motion._rustle_sound, "Corner pull must use paper rustle audio")
		var real_release := InputEventMouseButton.new()
		real_release.button_index = MOUSE_BUTTON_LEFT
		real_release.pressed = false
		real_release.position = real_drag.position
		Input.parse_input_event(real_release)
		for i in 2: await process_frame
		expect(not motion._grabbed, "Real release outside the ticket must end the pull")
		motion._player.advance(0.9)
	# Only an intentional double-click rolls the ticket; it holds indefinitely.
	var twice := InputEventMouseButton.new()
	twice.button_index = MOUSE_BUTTON_LEFT
	twice.pressed = true
	twice.double_click = true
	twice.position = Vector2(80.0, 90.0)
	main.gui_input.emit(twice)
	expect(motion.state == &"roll", "Double-click should roll the main ticket")
	motion._player.advance(1.3)
	expect(motion.state == &"rolled", "Roll must hold the curled state")
	expect(is_equal_approx(float(motion._paper_material.get_shader_parameter("curl_lighting")), 1.0), "Rolled paper must retain its shading")
	motion._player.advance(120.0)
	motion._process(120.0)
	expect(motion.state == &"rolled", "Elapsed time must not undo the player's fold")
	await screenshot("main_ticket_rolled_shading")
	main.gui_input.emit(click)
	expect(motion.state == &"unroll", "Clicking a rolled order must reopen it")
	motion._player.advance(1.3)
	expect(motion.state == &"static" and motion._thumbtack.visible, "Manual reopening must keep the seated pin")
	motion._wind_left = 1000.0
	motion._process(180.0)
	expect(motion.state == &"static", "An open order must never auto-retract")

	queued.gui_input.emit(click)
	var next = queued.get_meta("ticket_motion")
	next.set_process(false)
	next._player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for i in 4: await process_frame
	expect(not motion.active and next.active and next.state == &"fly", "Promoting a ticket should fly it in and deactivate the previous one")
	expect(is_equal_approx(main.get_meta("ticket_note").position.y, -15.0), "Demoted paper must use the new queued offset")
	expect(next._note.position.is_zero_approx(), "Promoted paper must not inherit the queued offset")
	expect(main.get_meta("ticket_note").get_parent() == main, "Demoted ticket must restore its static Control")
	expect(motion._view.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Queued ticket viewport must not render")
	expect(not motion.is_processing() and not motion._player.active, "Queued animation must not consume process updates")
	expect(main.custom_minimum_size.x < queued.custom_minimum_size.x, "Waiting ticket must retain its smaller layout")
	expect(not first.running and second.running, "Visual changes must preserve the main-order clock selection")
	next.tap()
	expect(next._pending_tap, "Tap during arrival must be remembered")
	expect(not motion._thumbtack.visible, "A demoted ticket must hide its 3D pin")
	next._advance_arrival(0.6)
	next._player.advance(1.3)
	expect(next.state == &"pin", "Queued tap must not skip the pin placement")
	next._advance_arrival(0.9)
	expect(next.state == &"tap", "Arrival tap must play after the pin is seated")
	next._player.advance(0.8)
	await screenshot("main_ticket_promoted")
	game._remove_ticket(second)
	for i in 3: await process_frame
	expect(not is_instance_valid(next), "Removing the order must free its renderer")
	game.selected_customer = first
	game._highlight_tickets()
	expect(motion.active and motion.state == &"fly", "Returning to a waiting order should replay the arrival")
	print("MAIN_TICKET_ANIMATION_OK" if failures.is_empty() else "MAIN_TICKET_ANIMATION_FAILED: " + str(failures))
	game.queue_free()
	for i in 3: await process_frame
	quit(0 if failures.is_empty() else 1)
