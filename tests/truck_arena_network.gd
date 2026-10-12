extends SceneTree
var folder:String
func _initialize():call_deferred("run")
func mark(key:String):FileAccess.open(folder.path_join(key),FileAccess.WRITE).store_string("ok")
func wait_mark(key:String):
 while not FileAccess.file_exists(folder.path_join(key)):await process_frame
func run():
 create_timer(45).timeout.connect(func():push_error("PAL_NETWORK_TIMEOUT");quit(1))
 folder=OS.get_environment("MP_TEST_DIR");var hosting=OS.get_environment("MP_TEST_ROLE")=="host"
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/shared_interaction_fixture.gd"));root.add_child(g);current_scene=g
 g.playing=true;g._kitchen_ready=true
 var net=root.get_node("NetManager");net.relay_url=""
 if hosting:
  assert(net.host_room("Host","Ball test")==OK)
  while not net.is_online():await process_frame
  FileAccess.open(folder.path_join("port"),FileAccess.WRITE).store_string(str(net.game_port));await wait_mark("ready")
 else:
  await wait_mark("port");assert(net.join_room("127.0.0.1",int(FileAccess.get_file_as_string(folder.path_join("port"))),"Guest")==OK)
  while not net.is_online():await process_frame
 g.mp_enabled=true
 if hosting:
  g.day_time=g._shift_length()*.5
  assert(g._maybe_start_pal_ball_break(true,"truck_arena"))
  while g._pal_ball_break.simulation.phase!="playing":await process_frame
  await wait_mark("sent")
  var guest_id:int=net.connected_peer_ids().filter(func(id):return id!=1)[0]
  while g._pal_ball_break.simulation.players[guest_id].velocity.length()<.1:await process_frame
  assert(paused);mark("saw_input")
  var sim=g._pal_ball_break.simulation
  sim.players[1].ammo=3
  sim.players[1].burst=true
  await wait_mark("saw_shot")
  sim.players[guest_id].hp=1
  await wait_mark("saw_damage")
  sim.drop_peer(guest_id)
  await wait_mark("saw_result")
 else:
  mark("ready")
  while not is_instance_valid(g._pal_ball_break):await process_frame
  assert(paused)
  while g._pal_ball_break.view.phase!="playing":await process_frame
  g._pal_ball_break.set_process(false)
  mark("sent")
  while not FileAccess.file_exists(folder.path_join("saw_input")):
   g.mp_pal_ball_input.rpc_id(1,g._pal_ball_break.generation,Vector2(0,2),true)
   await create_timer(.04).timeout
  while g._pal_ball_break.view.players[net.my_id()].boost>=1:await process_frame
  g.mp_pal_ball_input.rpc_id(1,g._pal_ball_break.generation,Vector2.ZERO,false)
  var seen:=false
  while not seen:
   for event in g._pal_ball_break.view.events:
    if event.kind=="shot":seen=true
   await process_frame
  assert(g._pal_ball_break.view.players[1].ammo==2);mark("saw_shot")
  while g._pal_ball_break.view.players[net.my_id()].hp!=1:await process_frame
  mark("saw_damage")
  while g._pal_ball_break.view.phase!="results":await process_frame
  assert(g._pal_ball_break.view.winners==[1] and g._pal_ball_break.view.match_complete);mark("saw_result")
 while is_instance_valid(g._pal_ball_break):await process_frame
 assert(not paused)

 mark("finished_"+("host" if hosting else "guest"));await wait_mark("finished_"+("guest" if hosting else "host"))
 print("TRUCK_ARENA_NETWORK_OK ",hosting)
 g.mp_enabled=false;net.leave(false);g.queue_free();await process_frame;quit()
