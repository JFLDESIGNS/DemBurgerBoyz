extends SceneTree
var folder: String
func _initialize():call_deferred("run")
func mark(key:String):FileAccess.open(folder.path_join(key),FileAccess.WRITE).store_string("ok")
func wait_mark(key:String):
 while not FileAccess.file_exists(folder.path_join(key)):await process_frame
func run():
 create_timer(65).timeout.connect(func():push_error("GUEST_PRESENTATION_TIMEOUT");quit(1))
 folder=OS.get_environment("MP_TEST_DIR")
 var host:=OS.get_environment("MP_TEST_ROLE")=="host"
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/delivery_network_fixture.gd"));root.add_child(g);current_scene=g;g.playing=true
 var outside=Node3D.new();g.add_child(outside);g._build_background_people(outside)
 g.soda_root=Node3D.new();g.world.add_child(g.soda_root)
 var net=root.get_node("NetManager");net.relay_url=""
 if host:
  assert(net.host_room("Host","Guest visual regression")==OK)
  while not net.is_online():await process_frame
  FileAccess.open(folder.path_join("port"),FileAccess.WRITE).store_string(str(net.game_port));await wait_mark("ready")
 else:
  await wait_mark("port");assert(net.join_room("127.0.0.1",int(FileAccess.get_file_as_string(folder.path_join("port"))),"Guest")==OK)
  while not net.is_online():await process_frame
  mark("ready")
 g.mp_enabled=true
 if host:
  g._start_background_person(0)
  await wait_mark("started")
  var walker=g.bg_people[0]
  walker.position=Vector3(-1,.25,8.7);walker.scale=Vector3.ONE*.8;walker.set_meta("building_trip",true)
  g._mp_send_background_people_snapshot()
  g._break_machine("soda")
  await wait_mark("settled")
  walker.position.x=0;g._mp_send_background_people_snapshot()
  await wait_mark("smooth")
  g._machine_broken.soda=false;g.mp_machine_damage.rpc(g._machine_broken,g._machine_use_count)
  await wait_mark("repaired")
 else:
  while not g.bg_people_active[0]:await process_frame
  mark("started")
  var walker=g.bg_people[0]
  while not walker.has_meta("mp_walk_target") or not g._machine_is_broken("soda"):await process_frame
  while not bool(walker.get_meta("building_trip",false)):await process_frame
  for i in 60:g._update_background_people(1.0/60.0)
  assert(walker.position.distance_to(Vector3(-1,.25,8.7))<.001,"Guest local walk fought doorway pose")
  assert(absf(walker.scale.y-.8)<.001)
  assert(g._machine_wrench.has("soda"),"Guest must see broken machine wrench")
  mark("settled")
  while walker.get_meta("mp_walk_target").x<-.5:await process_frame
  assert(walker.position.x<-.9,"Snapshot should set a target, not jump the walker")
  await create_timer(.28).timeout
  g._update_background_people(1.0/60.0)
  assert(walker.position.x>-.9 and walker.position.x<-.5,"Walker must interpolate between packets")
  mark("smooth")
  while g._machine_is_broken("soda"):await process_frame
  assert(not g._machine_wrench.has("soda"))
  mark("repaired")
 print("GUEST_PRESENTATION_NETWORK_OK ",host)
 g.mp_enabled=false;net.leave(false);quit()
