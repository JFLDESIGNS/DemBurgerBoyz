extends SceneTree
var game
var folder: String
var role: int
var peers: int
var samples: Array = []
var phase_samples: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		quit(1)
func mark(name: String, content: String = "ok") -> void:
	var f := FileAccess.open(folder.path_join(name), FileAccess.WRITE)
	f.store_string(content)
func wait_file(name: String) -> void:
	var deadline := Time.get_ticks_msec() + 120000
	while not FileAccess.file_exists(folder.path_join(name)):
		check(Time.get_ticks_msec() < deadline, "Timed out: " + name)
		await process_frame
func run() -> void:
	folder = OS.get_environment("MP_TEST_DIR")
	role = int(OS.get_environment("MP_TEST_ROLE_INDEX"))
	peers = int(OS.get_environment("MP_TEST_PEERS"))
	var relay := OS.get_environment("MP_TEST_TRANSPORT") == "relay"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await game._start_game()
	game.spawn_timer = 999999.0
	game._reset_cut_collector_shift(false)
	game.truck_bought_out = true
	for c in game.customers.duplicate():
		game._remove_ticket(c)
		c.queue_free()
	game.customers.clear()
	var net = root.get_node("NetManager")
	net.chat_flash.connect(func(message: String, _color: Color): print("NETWORK ", message))
	net.relay_url = OS.get_environment("MP_RELAY_URL") if relay else ""
	if role == 0:
		check(net.host_room("Concurrent host", "Regression") == OK, "Host failed")
		while not net.is_online(): await process_frame
		mark("connection", net.room_code if relay else str(net.game_port))
	else:
		await wait_file("connection")
		var address := FileAccess.get_file_as_string(folder.path_join("connection"))
		if relay: check(net.join_by_code(address, "Cook%d" % role) == OK, "Join failed")
		else: check(net.join_room("127.0.0.1", int(address), "Cook%d" % role) == OK, "Join failed")
		while not net.is_online(): await process_frame
	game.mp_enabled = true
	game.playing = true
	await game._mp_prepare_remote_visuals()
	mark("ready%d" % role)
	for i in peers: await wait_file("ready%d" % i)
	if role == 0:
		for i in peers:
			var at: Vector3 = game.slot_positions[i]
			game.mp_spawn_patty.rpc(98000+i, i, at.x, at.z)
		game.fryer_ready_servings = 4
		game._refresh_ready_fries_visuals()
		game._mp_broadcast_economy()
		game._mp_broadcast_grill()
		mark("fixture")
	await wait_file("fixture")
	var deadline := Time.get_ticks_msec() + 15000
	while game._patty_by_net_id(98000+role) == null:
		check(Time.get_ticks_msec() < deadline, "Patty not replicated")
		await process_frame
	var claim_started := Time.get_ticks_msec()
	game.mp_claim_drag(98000+role)
	while int(game._mp_drag_claims.get(98000+role,0)) != net.my_id():
		check(Time.get_ticks_msec() < deadline, "Drag claim not granted")
		await process_frame
	var claim_latency := Time.get_ticks_msec() - claim_started
	var previous := Time.get_ticks_usec()
	var start := previous
	var requested_bootstrap := false
	game._phone_app_id = "shop"
	game._refresh_phone_ui()
	var shop_row_ids: Array = []
	for row in game.phone_inventory_box.get_children(): shop_row_ids.append(row.get_instance_id())
	while Time.get_ticks_usec() - start < 12000000:
		var t := (Time.get_ticks_usec()-start)/1000000.0
		if role == peers - 1 and t > 6.0 and not requested_bootstrap:
			requested_bootstrap = true
			game._mp_request_bootstrap_deferred()
		check(int(game._mp_drag_claims.get(98000+role,0)) == net.my_id(), "Different-object drag ownership changed")
		check(game.drag_owner_id == net.my_id(), "Another cook stopped local drag")
		var patty = game._patty_by_net_id(98000+role)
		check(patty != null, "Owned patty disappeared")
		game._mp_send_patty_pose(patty, false)
		if t >= 3.0 and t < 8.0:
			game._mp_queue_motion("mp_cup_pose", [true, 0.2+sin(t)*0.1, 1.1, 0.2, 0.0, 0.0, 0.0, "cola" if role%2==0 else "orange", 0.9, game.CUP_ICE_FULL, 0.2, true, false])
		elif t >= 8.0:
			game._mp_queue_motion("mp_cup_pose", [false, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, "", 0.0, 0.0, 0.0, false, false])
			game._mp_queue_motion("mp_icecream_pose", [true, sin(t)*0.1, 1.1, 0.1, 0.0, 0.0, 0.0, 1.0, false])
		await process_frame
		var now := Time.get_ticks_usec()
		var ms := (now-previous)/1000.0
		samples.append(ms)
		var phase := "drag" if t<3.0 else ("cup" if t<8.0 else "cone")
		if not phase_samples.has(phase): phase_samples[phase]=[]
		phase_samples[phase].append(ms)
		previous = now
	game._refresh_phone_ui()
	var retained_row_ids: Array = []
	for row in game.phone_inventory_box.get_children(): retained_row_ids.append(row.get_instance_id())
	check(shop_row_ids == retained_row_ids, "Unchanged shop rebuilt its rows")
	if requested_bootstrap:
		check(game._mp_bootstrap_ready, "Mid-action bootstrap never completed")
	game.mp_release_drag(98000+role)
	game.dragging_patty = null
	game.drag_owner_id = 0
	mark("activity%d" % role)
	for i in peers: await wait_file("activity%d" % i)
	# All cooks contend for one patty: host must choose one owner consistently.
	game.mp_claim_drag(98000)
	await create_timer(1.0).timeout
	mark("owner%d" % role, str(game._mp_drag_claims.get(98000,0)))
	for i in peers: await wait_file("owner%d" % i)
	var expected := FileAccess.get_file_as_string(folder.path_join("owner0"))
	for i in peers:
		check(FileAccess.get_file_as_string(folder.path_join("owner%d" % i)) == expected, "Contested ownership diverged")
	check(int(expected) > 0, "Contested patty has no owner")
	# Repeated release/re-grab must survive the previous release acknowledgement.
	game.set_process(false)
	if role == 1:
		var patty = game._patty_by_net_id(98001)
		for attempt in 4:
			game.mp_claim_drag(98001)
			await create_timer(.18).timeout
			patty.position.x = game.GRILL_CENTER_X + .02 * attempt
			patty._rest_x = patty.position.x
			game.dragging_patty = null
			game._mp_finish_local_slide(patty)
			game.mp_claim_drag(98001)
			await create_timer(.18).timeout
			check(game.dragging_patty == patty and game.drag_owner_id == net.my_id(), "Release acknowledgement cancelled a newer drag")
			patty.position.x = game.GRILL_CENTER_X + .12
			patty._rest_x = patty.position.x
			game.dragging_patty = null
			game._mp_finish_local_slide(patty)
			await create_timer(.18).timeout
		mark("quick_drag_done", str(patty.position.x))
	else:
		await wait_file("quick_drag_done")
		await create_timer(.25).timeout
		check(absf(game._patty_by_net_id(98001).position.x - float(FileAccess.get_file_as_string(folder.path_join("quick_drag_done")))) < .02, "Guest final slide did not reach host")
	if role == 0:
		game.mp_spawn_customer.rpc(99010,["bun_bottom","patty","bun_top"],1.0,1.0,1.0,9999.0,0,1,0,false,-1,false,{"name":"Woman4","customer_voice":"female","hair_style":10,"top_style":1})
		var customer = game._customer_by_net_id(99010)
		customer.set_process(false); customer.is_waiting = true; game._create_ticket(customer)
		customer._play_anim("grill_dance"); customer._anim_player.advance(.3)
		game._mp_emit_customers()
		mark("dance_fixture", str(customer._anim_player.current_animation))
		await wait_file("dance_repair_requested1")
		for peer_role in range(2,peers): await wait_file("dance_repair_requested%d" % peer_role)
		game._mp_emit_customers()
		await wait_file("dance_repaired1")
		for peer_role in range(2,peers): await wait_file("dance_repaired%d" % peer_role)
		game.mp_customer_leave.rpc(99010,false,true)
		await wait_file("dance_departure1")
		for peer_role in range(2,peers): await wait_file("dance_departure%d" % peer_role)
	else:
		await wait_file("dance_fixture")
		var target_clip := FileAccess.get_file_as_string(folder.path_join("dance_fixture"))
		await create_timer(.5).timeout
		var customer = game._customer_by_net_id(99010)
		check(is_instance_valid(customer), "Guest missing dancing customer")
		check(str(customer._anim_player.current_animation) == target_clip, "Guest dance clip differs from host")
		game._mp_force_remove_customer(customer)
		await process_frame
		mark("dance_repair_requested%d" % role)
		await create_timer(.5).timeout
		customer = game._customer_by_net_id(99010)
		check(is_instance_valid(customer) and str(customer._anim_player.current_animation) == target_clip, "Missing customer was not repaired from snapshot")
		mark("dance_repaired%d" % role)
		await create_timer(.5).timeout
		check(customer.is_leaving and customer._leave_do_dance, "Guest departure lost celebration")
		mark("dance_departure%d" % role)
	var result: Dictionary = game.get_performance_report()
	result["role"] = role
	result["claim_ack_ms"] = claim_latency
	result["phases"] = {}
	for phase in phase_samples:
		var values: Array = phase_samples[phase]
		values.sort()
		result["phases"][phase] = {"p50_ms": values[values.size()/2], "p99_ms": values[int(values.size()*0.99)], "max_ms": values.back()}
	mark("result%d.json" % role, JSON.stringify(result,"\t"))
	mark("finished%d" % role)
	for i in peers: await wait_file("finished%d" % i)
	game.mp_enabled = false
	net.leave(false)
	print("MULTIPLAYER_CONCURRENT_OK role=",role," peers=",peers," relay=",relay)
	for tween in get_processed_tweens(): tween.kill()
	await process_frame
	await process_frame
	quit()
