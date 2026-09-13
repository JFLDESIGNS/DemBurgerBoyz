extends SceneTree
var folder:String
var game
func _initialize()->void:call_deferred("run")
func mark(key:String)->void:
	var file:=FileAccess.open(folder.path_join(key),FileAccess.WRITE);file.store_string("ok")
func wait_mark(key:String)->void:
	var until:=Time.get_ticks_msec()+45000
	while not FileAccess.file_exists(folder.path_join(key)):
		assert(Time.get_ticks_msec()<until,key);await process_frame
func run()->void:
	create_timer(100).timeout.connect(func():quit(1))
	folder=OS.get_environment("MP_TEST_DIR")
	var host:=OS.get_environment("MP_TEST_ROLE")=="host"
	var relay:=OS.get_environment("MP_TEST_TRANSPORT")=="relay"
	game=load("res://scenes/main.tscn").instantiate()
	game.set_script(load(get_script().resource_path.get_base_dir().path_join("delivery_network_fixture.gd")))
	root.add_child(game);current_scene=game;game.playing=true
	game.window_cat=load("res://scripts/window_cat.gd").new();game.world.add_child(game.window_cat);game.window_cat.show();game.window_cat.set_process(false)
	game.game_audio=Node.new();game.add_child(game.game_audio)
	for id in [game.SHOP_FRYER_MACHINE,game.SHOP_SODA_MACHINE]:
		var target:=Node3D.new();game.world.add_child(target);target.position=Vector3(-1,0.7,-0.2)
		var mesh:=MeshInstance3D.new();mesh.mesh=BoxMesh.new();target.add_child(mesh)
		if id==game.SHOP_FRYER_MACHINE:game.fryer_root=target
		else:game.soda_root=target
		game.owned_machines[id]=false
	var net=root.get_node("NetManager")
	net.relay_url="ws://127.0.0.1:18769" if relay else ""
	if host:
		assert(net.host_room("Delivery Host","Delivery regression")==OK)
		while not net.is_online():await process_frame
		var file:=FileAccess.open(folder.path_join("connection"),FileAccess.WRITE)
		file.store_string(net.room_code if relay else str(net.game_port));file.close()
		await wait_mark("connected")
	else:
		await wait_mark("connection")
		var address:=FileAccess.get_file_as_string(folder.path_join("connection"))
		assert((net.join_by_code(address,"Delivery Guest") if relay else net.join_room("127.0.0.1",int(address),"Delivery Guest"))==OK)
		while not net.is_online():await process_frame
		mark("connected")
	game.mp_enabled=true;game._mp_ensure_service()
	if host:
		game.money=10000;game.window_cat._fat=0.8;game.window_cat._giant=0.25
		game._mp_emit_economy();game._mp_send_cat_sync();mark("funded")
		await wait_mark("ordered")
		while game.pending_machine_deliveries.size()!=2:await process_frame
		assert(is_equal_approx(game.money,9600),"Only one payment per machine")
		game._mp_emit_economy();game._mp_send_cat_sync()
		await wait_mark("guest_pending")
		game.advance_delivery=true;mark("advance")
	else:
		await wait_mark("funded")
		while not is_equal_approx(game.money,10000):await process_frame
		for id in [game.SHOP_FRYER_MACHINE,game.SHOP_SODA_MACHINE]:
			game._buy_shop_item(id);game._buy_shop_item(id)
		mark("ordered")
		while game.pending_machine_deliveries.size()!=2:await process_frame
		while not is_equal_approx(game.window_cat._fat,0.8):await process_frame
		game.mail_delivery_truck._sync_courier_shape()
		assert(game.mail_delivery_truck.courier_base_scale.is_equal_approx(game.window_cat.delivery_visual_scale()))
		assert(not game.fryer_root.visible and not game.soda_root.visible)
		mark("guest_pending");await wait_mark("advance");game.advance_delivery=true
		game.mp_spatula_tap_fx.rpc(0.2,0.2,1.0,0.0)
	while is_instance_valid(game.mail_delivery_truck):await process_frame
	assert(game.saw_flight and game.highest_meows==3)
	assert(game.pending_machine_deliveries.is_empty() and game.fryer_root.visible and game.soda_root.visible)
	assert(game.window_cat.visible and game.street_car_wait>=3.0)
	if host:
		assert(game.taps_received>0,"Remote taps must reach the dance reaction")
		game._mp_emit_economy();mark("host_done");await wait_mark("guest_done")
	else:
		await wait_mark("host_done");await create_timer(0.3).timeout
		assert(is_equal_approx(game.money,9600))
		assert(game.owned_machines[game.SHOP_FRYER_MACHINE] and game.owned_machines[game.SHOP_SODA_MACHINE])
		mark("guest_done")
	game.mp_enabled=false;net.leave(false)
	print("DELIVERY_NETWORK_OK ","host" if host else "guest"," ","relay" if relay else "lan")
	game.queue_free()
	for i in 8:await process_frame
	quit()
