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
	game.set_script(load(get_script().resource_path.get_base_dir().path_join("cook_controls_fixture.gd")))
	root.add_child(game);current_scene=game;game.playing=true
	game.grill.resize(game.GRILL_SLOTS);game.slot_positions.resize(game.GRILL_SLOTS)
	game.stations=[{"items":["bun_bottom"],"patties":[]}]
	var p=load("res://scripts/patty.gd").new()
	p.slot_index=0;p.net_id=97001;p.base_y=game.GRILL_SURFACE_Y+game.PATTY_SIT_Y
	p.position=Vector3(game.GRILL_CENTER_X,p.base_y,game.GRILL_SURFACE_Z)
	p._rest_x=p.position.x;p._rest_z=p.position.z
	game.patties_root.add_child(p);game.grill[0]=p;p.set_process(false)
	p.cook_time=20.0;p.first_side_time=20.0;p.flipped_once=true
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
	game.mp_enabled=true;game._mp_ensure_service();game._layout_top_bar_hud()
	p.set_meta("chef_done_at",Time.get_ticks_msec())

	if host:
		mark("host_ready")
		while not p.is_held:await process_frame
		assert(game.chef_points==20,"Guest scoop awards host-authoritative points")
		game._chef_award_once(p,"flip",10,"Perfect flip")
		game._chef_award_once(p,"fresh",15,"Fresh serve")
		game._chef_award_once(p,"review",25,"Five-star review")
		game._chef_award_once(p,"review",25,"Five-star review")
		assert(game.chef_points==70)
		mark("saw_guest_scoop")
		await wait_mark("guest_placed")
		await create_timer(0.5).timeout
		assert(not p.is_held and game._mp_peer_holding_net(97001)==0,"Guest placement releases ownership")
		game._begin_patty_drag(p)
		assert(game.dragging_patty==p and game.drag_owner_id==net.my_id(),"Host can move guest-handled burger")
		game.mp_release_drag(97001);game.dragging_patty=null;p.is_slide_drag=false
		game._quick_transfer_patty(p)
		await create_timer(0.6).timeout
		assert(game.stations[0].patties.has(p),"Animated Build transfer on host")
		game.mp_set_service_closed.rpc(true)
		mark("host_done");await wait_mark("guest_done")
	else:
		await wait_mark("host_ready")
		game._on_patty_clicked(p)
		await wait_mark("saw_guest_scoop")
		var hold=game._warmer_place_bounds().get_center()
		game.mp_place_warmer.rpc(97001,0,hold.x,hold.y)
		# Simulate an unreliable carry update arriving after reliable placement.
		game.mp_patty_pose.rpc(97001,0.0,3.0,0.0,true)
		mark("guest_placed");await wait_mark("host_done")
		while not game.service_window_closed:await process_frame
		assert(game.stations[0].patties.has(p),"Animated Build transfer replicated to guest")
		while game.chef_points!=70:await process_frame
		game._chef_award_once(p,"forged",500,"Guest cannot award")
		assert(game.chef_points==70 and game.chef_points_hud.points==70)
		mark("guest_done")
	game.mp_enabled=false;net.leave(false)
	print("CHEF_NETWORK_OK ","host" if host else "guest")
	game.queue_free()
	for i in 8:await process_frame
	quit()
