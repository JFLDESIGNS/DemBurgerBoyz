extends SceneTree
var folder: String
func _initialize():call_deferred("run")
func mark(key:String):
	var f=FileAccess.open(folder.path_join(key),FileAccess.WRITE);f.store_string("ok")
func wait_mark(key:String):
	var until=Time.get_ticks_msec()+45000
	while not FileAccess.file_exists(folder.path_join(key)):
		assert(Time.get_ticks_msec()<until,key);await process_frame
func run():
	create_timer(90).timeout.connect(func():quit(1))
	folder=OS.get_environment("MP_TEST_DIR")
	var host=OS.get_environment("MP_TEST_ROLE")=="host"
	var relay=OS.get_environment("MP_TEST_TRANSPORT")=="relay"
	var g=load("res://scenes/main.tscn").instantiate()
	g.set_script(load("res://tests/queue_snack_network_fixture.gd"))
	root.add_child(g);current_scene=g;g.playing=true
	var owners=[]
	for i in 3:
		var c=load("res://scripts/mobile_ticket_owner.gd").new()
		g.customers_root.add_child(c);c.is_waiting=true;c.set_process(false)
		c.order.assign(["bun_bottom","patty","bun_top"])
		c.patience_max=100;c.patience=50;c.mp_host_driven=not host
		c.set_meta("mp_net_id",98001+i)
		if i==1:c.set_meta("mobile_order",true)
		g.customers.append(c)
		if i==0:g.selected_customer=c
		g._create_ticket(c);owners.append(c)
	var net=root.get_node("NetManager")
	net.relay_url="ws://127.0.0.1:18769" if relay else ""
	if host:
		assert(net.host_room("Queue Host","Queue and bacon regression")==OK)
		while not net.is_online():await process_frame
		var f=FileAccess.open(folder.path_join("connection"),FileAccess.WRITE)
		f.store_string(net.room_code if relay else str(net.game_port));f.close()
		await wait_mark("connected")
	else:
		await wait_mark("connection")
		var address=FileAccess.get_file_as_string(folder.path_join("connection"))
		assert((net.join_by_code(address,"Queue Guest") if relay else net.join_room("127.0.0.1",int(address),"Queue Guest"))==OK)
		while not net.is_online():await process_frame
		mark("connected")
	g.mp_enabled=true;g._mp_ensure_service()
	var wrap=g.tickets[owners[1]]
	if host:
		await wait_mark("ready")
		g.mp_select_customer(98002,false)
		assert(wrap.get_index()==1)
		mark("auto_selected")
		await wait_mark("clicked")
		while wrap.get_index()!=0:await process_frame
		assert(g.selected_customer==owners[1])
		g.mp_customer_flung_food_reaction.rpc(98001,"bacon",Vector3(0,1,0),"face",true)
		assert(is_equal_approx(owners[0].patience,60.0))
		g._mp_emit_customers()
		mark("bacon_sent");await wait_mark("guest_done")
	else:
		mark("ready");await wait_mark("auto_selected")
		while g.selected_customer!=owners[1]:await process_frame
		assert(wrap.get_index()==1,"Automatic host selection retains mobile queue slot on guest")
		g._select_ticket(owners[1]);mark("clicked")
		while wrap.get_index()!=0:await process_frame
		await wait_mark("bacon_sent")
		while not is_equal_approx(owners[0].patience,60.0):await process_frame
		g._apply_customer_ingredient_hit(owners[0],"bacon",Vector3(0,1,0),"face",1)
		assert(is_equal_approx(owners[0].patience,60.0),"Guest presentation cannot add extra patience")
		mark("guest_done")
	g.mp_enabled=false;net.leave(false)
	print("QUEUE_SNACK_NETWORK_OK ","host" if host else "guest")
	g.queue_free();await process_frame;quit()
