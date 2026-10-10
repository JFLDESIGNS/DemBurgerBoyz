extends SceneTree
var folder: String
func mark(key: String): FileAccess.open(folder.path_join(key), FileAccess.WRITE).store_string("ok")
func wait_mark(key: String):
	while not FileAccess.file_exists(folder.path_join(key)): await process_frame
func _initialize(): call_deferred("run")
func run():
	create_timer(55).timeout.connect(func(): quit(1))
	folder = OS.get_environment("MP_TEST_DIR")
	var host = OS.get_environment("MP_TEST_ROLE") == "host"
	var g = load("res://scenes/main.tscn").instantiate()
	g.set_script(load("res://tests/coop_kitchen_repair_fixture.gd"))
	root.add_child(g); current_scene = g; g.playing = true
	g._setup_stations_data(); g.grill.resize(g.GRILL_SLOTS); g.slot_positions.resize(g.GRILL_SLOTS)
	g.supply_stock["bun_bottom"] = 10; g.supply_stock["bun_top"] = 10
	g.fryer_ready_servings = 1
	g.shaker_root = Node3D.new(); g.world.add_child(g.shaker_root)
	g.oil_root = Node3D.new(); g.world.add_child(g.oil_root)
	var c = load("res://scripts/mobile_ticket_owner.gd").new(); g.add_child(c)
	c.order.assign(["bun_bottom", "patty", "bun_top", "toasted_bun"]); c.is_waiting = true
	c.set_meta("mp_net_id", 9801); g.customers.append(c); g._create_ticket(c); g.selected_customer = c
	var net = root.get_node("NetManager"); net.relay_url = ""
	if host:
		assert(net.host_room("Host", "Kitchen repair") == OK)
		while not net.is_online(): await process_frame
		FileAccess.open(folder.path_join("port"), FileAccess.WRITE).store_string(str(net.game_port))
		await wait_mark("ready")
	else:
		await wait_mark("port")
		assert(net.join_room("127.0.0.1", int(FileAccess.get_file_as_string(folder.path_join("port"))), "Guest") == OK)
		while not net.is_online(): await process_frame
		mark("ready")
	g.mp_enabled = true
	if host:
		mark("host_ready")
		await wait_mark("placed")
		while g.grill[0] == null: await process_frame
		var bun = g.grill[0]; assert(g._is_bun_toast(bun)); bun.set_process(false); bun.cook_time = 10
		var p = bun.position
		g.mp_sync_grill.rpc([bun.net_id], [0], [p.x], [p.y], [p.z], [10.0], [true], [0.0], [0.0], [true], [1.0], [0.0], [false], [0.0], [0.0], [false], [false], [3])
		mark("toasted")
		await wait_mark("built")
		while not g._station_has_toasted_buns(0): await process_frame
		assert(g.stations[0].items == ["bun_bottom", "bun_top"])
		assert(g.supply_stock.bun_bottom == 9 and g.supply_stock.bun_top == 9)
		mark("build_checked")
		await wait_mark("fries")
		assert(g.fryer_ready_servings == 0 and g._mp_reserved_fries.size() == 1)
		mark("fries_checked")
		await wait_mark("returned")
		while g.fryer_ready_servings != 1: await process_frame
		assert(g._mp_reserved_fries.is_empty()); mark("return_checked")
		await wait_mark("shaker")
		while g.shaker_root.visible: await process_frame
		mark("shaker_checked")
		await wait_mark("oil")
		while g.oil_root.visible or not g.shaker_root.visible: await process_frame
		mark("oil_checked")
		await wait_mark("tools_returned")
		while not g.oil_root.visible: await process_frame
		mark("done")
	else:
		await wait_mark("host_ready")
		g._request_bun_pickup(-1)
		while g.spatula_patty == null: await process_frame
		var bun = g.spatula_patty; bun.set_process(false)
		assert(bun.net_id >= 0)
		g.mp_place_spatula.rpc(bun.net_id, 0, g.GRILL_CENTER_X, g.GRILL_SURFACE_Z)
		assert(g.grill[0] == bun and g.spatula_patty == null); mark("placed")
		await wait_mark("toasted")
		while bun.cook_time < 10: await process_frame
		g._begin_patty_drag(bun)
		while g.dragging_patty != bun: await process_frame
		g._move_grill_patty_slide(bun, Vector2(bun.position.x + .1, bun.position.z), Vector2(bun.position.x, bun.position.z), true)
		g.dragging_patty = null; g._commit_bun_to_build(bun); mark("built")
		await wait_mark("build_checked")
		while not g._station_has_toasted_buns(0): await process_frame
		g._refresh_ticket_checkmarks()
		var lines = g.tickets[c].get_meta("lines_box")
		var checked = false
		for row in lines.get_children():
			if row.get_meta("line_id", "") == "toasted_bun": checked = row.get_node("Item").get("completed")
		assert(checked, "Guest sees toasted-bun check mark")
		assert(g._begin_fries_pack_hold(0))
		while not g.fries_pack_held: await process_frame
		assert(g.fryer_ready_servings == 0); mark("fries")
		await wait_mark("fries_checked")
		g.mp_return_fries.rpc_id(1, true); g.fries_pack_held = false; mark("returned")
		await wait_mark("return_checked")
		g.mp_shared_tool_presence.rpc(4); mark("shaker"); await wait_mark("shaker_checked")
		g.mp_shared_tool_presence.rpc(2); mark("oil"); await wait_mark("oil_checked")
		g.mp_shared_tool_presence.rpc(-1); mark("tools_returned"); await wait_mark("done")
	print("COOP_KITCHEN_REPAIR_OK ", "host" if host else "guest")
	g.mp_enabled = false; net.leave(false); quit()
