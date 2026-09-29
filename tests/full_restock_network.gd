extends SceneTree
var folder: String
func _initialize(): call_deferred("run")
func mark(key: String) -> void:
	var file = FileAccess.open(folder.path_join(key),FileAccess.WRITE); file.store_string("ok")
func wait_mark(key: String) -> void:
	while not FileAccess.file_exists(folder.path_join(key)): await process_frame
func run() -> void:
	create_timer(90).timeout.connect(func(): push_error("RESTOCK_NETWORK_TIMEOUT"); quit(1))
	folder = OS.get_environment("MP_TEST_DIR")
	var hosting = OS.get_environment("MP_TEST_ROLE") == "host"
	var g = load("res://scenes/main.tscn").instantiate()
	g.set_script(load("res://tests/full_restock_fixture.gd"))
	root.add_child(g); current_scene = g; g.playing = true
	var net = root.get_node("NetManager"); net.relay_url = ""
	if hosting:
		assert(net.host_room("Restock Host","Restock test") == OK)
		while not net.is_online(): await process_frame
		var connection = FileAccess.open(folder.path_join("connection"),FileAccess.WRITE)
		connection.store_string(str(net.game_port)); connection.close()
		await wait_mark("guest_ready")
	else:
		await wait_mark("connection")
		assert(net.join_room("127.0.0.1",int(FileAccess.get_file_as_string(folder.path_join("connection"))),"Restock Guest") == OK)
		while not net.is_online(): await process_frame
	g.mp_enabled = true; g._mp_ensure_service()
	if hosting:
		g.money = 100; g.supply_stock.lettuce = 3; mark("funded")
		while g.supply_orders.is_empty(): await process_frame
		await create_timer(.15).timeout
		assert(g.supply_orders.size() == 1 and g.supply_orders[0].pack == 13 and g.money == 87)
		g._mp_emit_economy(); await wait_mark("guest_full")
		g.supply_orders.clear(); g._credit_supply_delivery("lettuce",13,"stock")
		g.money = 5.5; g.supply_stock.bacon = 0; mark("partial_ready")
		while g.supply_orders.is_empty(): await process_frame
		assert(g.supply_orders[0].pack == 2 and g.money == 1.5 and g.supply_stock.lettuce == 16)
		g._mp_emit_economy(); await wait_mark("guest_partial"); mark("host_done")
		await create_timer(.3).timeout
	else:
		mark("guest_ready"); await wait_mark("funded")
		g.money = 0; g.supply_stock.lettuce = 0
		g._buy_supply("lettuce"); g._buy_supply("lettuce")
		while g.supply_orders.is_empty() or not is_equal_approx(g.money,87): await process_frame
		assert(g.supply_orders.size() == 1 and g.supply_orders[0].pack == 13)
		mark("guest_full"); await wait_mark("partial_ready")
		g.supply_orders.clear(); g.money = 999
		g._buy_supply("bacon")
		while g.supply_orders.is_empty() or not is_equal_approx(g.money,1.5): await process_frame
		assert(g.supply_orders[0].pack == 2 and g.supply_stock.lettuce == 16)
		mark("guest_partial"); await wait_mark("host_done")
	g.mp_enabled = false; net.leave(false); g.queue_free(); await process_frame
	print("FULL_RESTOCK_NETWORK_OK ", "host" if hosting else "guest")
	quit()
