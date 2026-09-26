extends SceneTree
var folder:String
func mark(key:String):FileAccess.open(folder.path_join(key),FileAccess.WRITE).store_string("ok")
func wait_mark(key:String):
 while not FileAccess.file_exists(folder.path_join(key)):await process_frame
func _initialize():call_deferred("run")
func run():
 create_timer(75).timeout.connect(func():quit(1))
 folder=OS.get_environment("MP_TEST_DIR")
 var host=OS.get_environment("MP_TEST_ROLE")=="host"
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/challenge_repair_fixture.gd"));root.add_child(g);current_scene=g;g.playing=true
 g._setup_stations_data();g.stations[0].items=["bun_bottom","bun_top"]
 g.grill.resize(g.GRILL_SLOTS);g.slot_positions.resize(g.GRILL_SLOTS)
 var p=load("res://scripts/patty.gd").new();p.net_id=98101;p.slot_index=0;p.base_y=g.GRILL_SURFACE_Y+g.PATTY_SIT_Y
 p.position=Vector3(g.GRILL_CENTER_X,p.base_y,g.GRILL_SURFACE_Z);p._rest_x=p.position.x;p._rest_z=p.position.z
 g.patties_root.add_child(p);g.grill[0]=p;p.set_process(false);p.cook_time=18;p.first_side_time=15;p.flipped_once=true
 var net=root.get_node("NetManager");net.relay_url=""
 if host:
  assert(net.host_room("Host","Challenge repair")==OK)
  while not net.is_online():await process_frame
  FileAccess.open(folder.path_join("port"),FileAccess.WRITE).store_string(str(net.game_port))
  await wait_mark("ready")
 else:
  await wait_mark("port");assert(net.join_room("127.0.0.1",int(FileAccess.get_file_as_string(folder.path_join("port"))),"Guest")==OK)
  while not net.is_online():await process_frame
  mark("ready")
 g.mp_enabled=true;g._mp_ensure_service()
 var target=g.GRILL_CENTER_X+.18
 if host:
  await wait_mark("moved");await create_timer(.15).timeout
  assert(absf(p.position.x-target)<.02,"Guest slide reaches host")
  g._mp_emit_grill();mark("old_snapshot")
  await wait_mark("released");await create_timer(.2).timeout
  assert(absf(p.position.x-(target+.1))<.02,"Reliable final slide position reaches host")
  mark("final_received")
  await wait_mark("build");await create_timer(.2).timeout
  assert(g.stations[0].items.has("patty"));assert(g.stations[0].patties.has(p));assert(not g.grill.has(p))
  g._challenge_offer_id=41;g._challenge_phase="offer";g._mp_send_challenge_state();mark("offer_sent")
  await wait_mark("skipped");assert(g._challenge_phase=="")
  g._challenge_offer_id=42;g._challenge_phase="offer";g._mp_send_challenge_state();mark("offer2")
  await wait_mark("stale");assert(g._challenge_phase=="offer");mark("stale_checked")
  await wait_mark("accepted");assert(g._challenge_phase=="active");g._decline_challenge();assert(g._challenge_phase=="active")
  mark("done")
 else:
  g._begin_patty_drag(p)
  while int(g._mp_drag_claims.get(p.net_id,0))!=net.my_id():await process_frame
  p.position.x=target;p._rest_x=target;g._mp_send_patty_pose(p);await create_timer(.15).timeout;mark("moved")
  g.dragging_patty=null;g.slide_inertia_patty=p;p.position.x=target+.1;p._rest_x=p.position.x
  await wait_mark("old_snapshot");await create_timer(.2).timeout
  assert(absf(p.position.x-(target+.1))<.01,"Old snapshot cannot rubber-band local inertia")
  g._stop_patty_slide_inertia();await process_frame;await create_timer(.2).timeout;mark("released");await wait_mark("final_received")
  g._try_drag_patty_to_station(p,0);await create_timer(.3).timeout
  assert(g.stations[0].items.has("patty"));assert(g.stations[0].patties.has(p));mark("build")
  await wait_mark("offer_sent")
  while g._challenge_phase!="offer":await process_frame
  g.mp_request_challenge_decision.rpc_id(1,false,41);g.mp_request_challenge_decision.rpc_id(1,true,41)
  await create_timer(.25).timeout;assert(g._challenge_phase=="");mark("skipped")
  await wait_mark("offer2")
  while g._challenge_offer_id!=42:await process_frame
  g.mp_request_challenge_decision.rpc_id(1,true,41);await create_timer(.2).timeout;mark("stale");await wait_mark("stale_checked")
  g._accept_challenge();g._decline_challenge();await create_timer(.3).timeout;assert(g._challenge_phase=="active");mark("accepted");await wait_mark("done")
 print("CHALLENGE_SLIDE_REPAIR_OK ","host" if host else "guest")
 g.mp_enabled=false;net.leave(false);quit()
