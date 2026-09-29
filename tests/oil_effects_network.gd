extends SceneTree
var folder: String
func mark(key: String): FileAccess.open(folder.path_join(key),FileAccess.WRITE).store_string("ok")
func wait_mark(key: String):
	while not FileAccess.file_exists(folder.path_join(key)): await process_frame
func _initialize(): call_deferred("run")
func run():
	create_timer(45).timeout.connect(func(): quit(1))
	folder=OS.get_environment("MP_TEST_DIR")
	var host:=OS.get_environment("MP_TEST_ROLE")=="host"
	var g=load("res://scenes/main.tscn").instantiate()
	g.set_script(load("res://tests/patty_pool_fixture.gd"));root.add_child(g);current_scene=g
	g.playing=true;g.grill_on=false;g.grill_root=Node3D.new();g.world.add_child(g.grill_root)
	g._ensure_oil_effect_pool()
	var net=root.get_node("NetManager");net.relay_url=""
	if host:
		assert(net.host_room("Host","Oil effects regression")==OK)
		while not net.is_online(): await process_frame
		FileAccess.open(folder.path_join("port"),FileAccess.WRITE).store_string(str(net.game_port))
		await wait_mark("ready")
	else:
		await wait_mark("port")
		assert(net.join_room("127.0.0.1",int(FileAccess.get_file_as_string(folder.path_join("port"))),"Guest")==OK)
		while not net.is_online(): await process_frame
		mark("ready")
	g.mp_enabled=true
	var bounds: Rect2=g._grill_place_bounds()
	if host:
		for i in 48:
			g.mp_oil_slick.rpc(lerpf(bounds.position.x,bounds.end.x,float(i%8)/8),lerpf(bounds.position.y,bounds.end.y,float(i/8)/6),.04)
		await wait_mark("received")
		while g.oil_slicks.size()!=49: await process_frame
		mark("guest_oil_accepted")
		while g.oil_slicks.size()!=48: await process_frame
		await wait_mark("scraped")
	else:
		while g.oil_slicks.size()!=48: await process_frame
		assert(g._oil_effect_pool.marks.size()==520 and g._oil_effect_pool.emitters.size()==16)
		mark("received")
		g.mp_request_oil_slick.rpc_id(1,bounds.get_center().x,bounds.get_center().y,.04)
		await wait_mark("guest_oil_accepted")
		while g.oil_slicks.size()!=49: await process_frame
		g.mp_request_oil_slick_scrape.rpc_id(1,bounds.position.x,bounds.position.y,.08,true)
		while g.oil_slicks.size()!=48: await process_frame
		assert(g._oil_effect_pool.marks.size()==520)
		mark("scraped")
	g._clear_oil_slicks()
	assert(g._oil_effect_pool.marks.size()==568)
	print("OIL_EFFECTS_HOST_GUEST_DRAW_SCRAPE_POOL_OK ","host" if host else "guest")
	g.mp_enabled=false;net.leave(false);quit()
