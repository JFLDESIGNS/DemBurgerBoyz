extends SceneTree
var folder: String
func _initialize(): call_deferred("run")
func mark(key: String) -> void:
	var file = FileAccess.open(folder.path_join(key), FileAccess.WRITE); file.store_string("ok")
func wait_mark(key: String) -> void:
	while not FileAccess.file_exists(folder.path_join(key)): await process_frame
func run() -> void:
	create_timer(100).timeout.connect(func(): push_error("SHIFT_BOSS_NETWORK_TIMEOUT"); quit(1))
	folder = OS.get_environment("MP_TEST_DIR")
	var hosting = OS.get_environment("MP_TEST_ROLE") == "host"
	var g = load("res://scenes/main.tscn").instantiate()
	g.set_script(load("res://tests/hotdog_challenge_fixture.gd"))
	root.add_child(g); current_scene = g
	g.playing = true; g._kitchen_ready = true; g._bts_day1_performance_done = true
	g.day_time = 10; g.stations = [{"items":[], "patties":[]}]
	var boss = g._ensure_hotdog_challenge(); boss.set_process(false)
	var net = root.get_node("NetManager"); net.relay_url = ""
	if hosting:
		assert(net.host_room("Boss Host", "Boss closing test") == OK)
		while not net.is_online(): await process_frame
		var connection = FileAccess.open(folder.path_join("connection"), FileAccess.WRITE)
		connection.store_string(str(net.game_port)); connection.close()
		await wait_mark("guest_ready")
	else:
		await wait_mark("connection")
		assert(net.join_room("127.0.0.1", int(FileAccess.get_file_as_string(folder.path_join("connection"))), "Boss Guest") == OK)
		while not net.is_online(): await process_frame
	g.mp_enabled = true
	if not hosting:
		g._update_shift_clock(20)
		assert(not boss.active() and g.day_time == 10, "Guest cannot advance the shift or start its own boss")
		mark("guest_ready")
		while boss.phase != "rumble": await process_frame
		assert(g.customers.size() == 1 and g._hotdog_shift_triggered)
		g._end_day(); assert(g.playing and not is_instance_valid(g._shift_results))
		mark("guest_rumble")
		while boss.phase != "ready": await process_frame
		assert(boss.customer.order == boss.current_recipe() and g.tickets.has(boss.customer))
		mark("guest_ready_order")
		while boss.phase != "results": await process_frame
		assert(boss.perfect == 25 and is_instance_valid(boss.result_screen) and not boss.music.playing)
		boss.finish_results(); assert(boss.active(), "Only host dismisses shared completion")
		mark("guest_results")
		while boss.active(): await process_frame
		assert(g.customers.is_empty() and boss.result_screen == null)
		mark("guest_done"); await wait_mark("host_done")
	else:
		g._update_shift_clock(.1)
		assert(boss.phase == "rumble" and g.day_time == 10)
		var generation = boss.generation
		for i in 5: g._update_shift_clock(1)
		assert(boss.generation == generation)
		await wait_mark("guest_rumble")
		boss.advance_phase(); boss.advance_phase()
		await wait_mark("guest_ready_order")
		for i in 25:
			boss.resolve_result(true)
			if boss.phase == "slump": boss.advance_phase(); boss.advance_phase()
		assert(boss.phase == "victory")
		boss.advance_phase(); boss.advance_phase()
		await wait_mark("guest_results")
		boss.finish_results()
		g._update_shift_clock(10)
		assert(g.day_time == 0 and not boss.active() and not g._hotdog_shift_due())
		await wait_mark("guest_done"); mark("host_done")
		await create_timer(.3).timeout
	g.mp_enabled = false; net.leave(false)
	g.queue_free(); await process_frame
	print("HOTDOG_SHIFT_NETWORK_OK ", "host" if hosting else "guest")
	quit()
