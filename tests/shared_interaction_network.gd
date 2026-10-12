extends SceneTree
var folder: String
func _initialize():call_deferred("run")
func mark(key:String):FileAccess.open(folder.path_join(key),FileAccess.WRITE).store_string("ok")
func wait_mark(key:String):
 while not FileAccess.file_exists(folder.path_join(key)):await process_frame
func run():
 create_timer(50).timeout.connect(func():quit(1))
 folder=OS.get_environment("MP_TEST_DIR");var hosting=OS.get_environment("MP_TEST_ROLE")=="host"
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/shared_interaction_fixture.gd"));root.add_child(g);current_scene=g
 g.playing=true;g._kitchen_ready=true
 var preview=Control.new();g.get_node("UI/Root").add_child(preview);preview.position=Vector2(100,200)
 g.stations=[{"preview":preview,"items":[],"patties":[]}]
 g.park_bird_house=load("res://scenes/park_bird.tscn").instantiate();g.world.add_child(g.park_bird_house);g.park_bird_house.set_process(false)
 var net=root.get_node("NetManager");net.relay_url=""
 if hosting:
  assert(net.host_room("Host","Shared interactions")==OK)
  while not net.is_online():await process_frame
  FileAccess.open(folder.path_join("port"),FileAccess.WRITE).store_string(str(net.game_port));await wait_mark("ready")
 else:
  await wait_mark("port");assert(net.join_room("127.0.0.1",int(FileAccess.get_file_as_string(folder.path_join("port"))),"Guest")==OK)
  while not net.is_online():await process_frame
 g.mp_enabled=true;g._mp_ensure_service()
 if hosting:
  for id in g._machine_ids(): g._break_machine(id)
  g._shared_world_send_at=0;g._mp_recover_shared_world()
  await wait_mark("repaired")
  for id in g._machine_ids(): assert(not g._machine_broken[id])
  await wait_mark("dragged")
  while preview.position.distance_to(Vector2(100,200))<10:await process_frame
  mark("saw_drag");await wait_mark("released")
  while preview.position.distance_to(Vector2(100,200))>.01:await process_frame
  g.park_bird_house._enter(&"Fly_In");g.park_bird_house.advance(.4)
  g.mp_bird_snapshot.rpc(g.park_bird_house.network_snapshot());await wait_mark("bird")
  mark("done");await create_timer(.3).timeout
 else:
  mark("ready")
  for id in g._machine_ids():
   while not g._machine_broken.get(id,false):await process_frame
  for id in g._machine_ids(): g._repair_machine(id)
  for id in g._machine_ids():
   while g._machine_broken[id]:await process_frame
  mark("repaired")
  g._mp_queue_motion("mp_build_pose",[0,true,.12,-.08,.1]);mark("dragged");await wait_mark("saw_drag")
  g._mp_queue_motion("mp_build_pose",[0,false,0.0,0.0,0.0]);mark("released")
  while g.park_bird_house.state!=&"Fly_In":await process_frame
  assert(is_equal_approx(g.park_bird_house.state_time,.4));mark("bird");await wait_mark("done")
 print("SHARED_INTERACTION_NETWORK_OK ","host" if hosting else "guest")
 g.mp_enabled=false;net.leave(false);g.queue_free();await process_frame;quit()
