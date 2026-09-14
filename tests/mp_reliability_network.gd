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

	game.mp_enabled=true;game._mp_ensure_service();game._mp_load_epoch=777
	game.grill_roomba_root=Node3D.new();game.world.add_child(game.grill_roomba_root)
	game.owned_machines[game.SHOP_FRYER_MACHINE]=true;game._build_fryer_machine()
	if host:
		start_barrier()
		await create_timer(0.3).timeout
		assert(not game._mp_load_released,"Host waits for slow-loading guest")
		mark("host_waiting")
	else:
		await wait_mark("host_waiting");await create_timer(0.4).timeout
		start_barrier()
	while not game.get_meta("barrier_done",false):await process_frame
	assert(game._mp_load_released)
	p.cook_time=0.0;p.flipped_once=false
	p.play_frozen_drop_appear()
	if host:
		await wait_mark("guest_ball")
		p.apply_mp_shape(0);p.cook_time=18.0;p.flipped_once=true;p.first_side_time=15.0
		game._mp_emit_grill();mark("host_state")
		await wait_mark("guest_dragging")
		p.cook_time=21.0;game._mp_emit_grill()
		await wait_mark("guest_redragged")
		game._begin_patty_drag(p)
		assert(game.dragging_patty==p and game.drag_owner_id==net.my_id(),"Host reclaims partner slide")
		mark("host_claimed");await wait_mark("guest_released")
		game.mp_release_drag(97001);game.dragging_patty=null;p.is_slide_drag=false
		mark("robot_begin")
		await wait_mark("robot_released");await create_timer(0.3).timeout
		assert(not game.grill_roomba_held and game.grill_roomba_remote_holder_id==0,"Robot stays released after stale pose")
		await wait_mark("fryer_released");await create_timer(0.3).timeout
		assert(int(game.fryer_baskets[0].get("remote_peer",0))==0,"Old basket pose cannot re-lock released basket")
		assert(game._begin_fryer_basket_hold(0),"Host grabs guest-used basket")
		game._release_fryer_basket();mark("host_done")
		await wait_mark("guest_done")
	else:
		mark("guest_ball");await wait_mark("host_state")
		while p.cook_time<18.0:await process_frame
		assert(not p.place_ball_waiting and not p.place_morphing,"Missed smash repaired from snapshot")
		game._begin_patty_drag(p);mark("guest_dragging")
		while p.cook_time<21.0:await process_frame
		assert(not p.is_held and p.is_slide_drag,"Cooking repair does not turn slide into scoop")
		game.mp_release_drag(97001);game.dragging_patty=null;p.is_slide_drag=false
		await create_timer(0.15).timeout
		game._begin_patty_drag(p);assert(game.dragging_patty==p,"Done burger remains slideable")
		mark("guest_redragged");await wait_mark("host_claimed")
		while game.dragging_patty!=null:await process_frame
		mark("guest_released");await wait_mark("robot_begin")
		game.grill_roomba_held=true
		game.mp_roomba_hold.rpc(true,0.0,1.5,0.0,0.0)
		await create_timer(0.15).timeout
		game._release_grill_roomba()
		game.mp_roomba_pose.rpc(0.0,1.5,0.0,0.0,0.0,"",INF,true,-1,-1,net.my_id())
		await create_timer(0.2).timeout
		assert(not game.grill_roomba_held,"Guest robot releases")
		mark("robot_released")
		assert(game._begin_fryer_basket_hold(0));await create_timer(0.15).timeout
		var old_epoch=int(game.fryer_baskets[0].pose_epoch)
		game._release_fryer_basket()
		game.mp_fryer_basket_pose.rpc(0,true,1,0.0,0.0,0.0,1.4,0.0,0.0,0.0,0.0,old_epoch)
		mark("fryer_released");await wait_mark("host_done")
		mark("guest_done")
	game.mp_enabled=false;net.leave(false)
	print("RELIABILITY_NETWORK_OK ","host" if host else "guest")
	game.queue_free()
	for i in 8:await process_frame
	quit()
func start_barrier()->void:
	assert(await game._mp_wait_for_cooks())
	game.set_meta("barrier_done",true)
