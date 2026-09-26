extends SceneTree
var folder: String
func mark(key: String):FileAccess.open(folder.path_join(key),FileAccess.WRITE).store_string("ok")
func wait_mark(key: String):
 while not FileAccess.file_exists(folder.path_join(key)):await process_frame
func _initialize():call_deferred("run")
func run():
 create_timer(35).timeout.connect(func():quit(1))
 folder=OS.get_environment("MP_TEST_DIR")
 var host=OS.get_environment("MP_TEST_ROLE")=="host"
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/kitchen_network_fixture.gd"));root.add_child(g)
 g.grill_root=Node3D.new();g.add_child(g.grill_root)
 var net=root.get_node("NetManager");net.relay_url=""
 if host:
  assert(net.host_room("Host","Sauce regression")==OK)
  while not net.is_online():await process_frame
  FileAccess.open(folder.path_join("port"),FileAccess.WRITE).store_string(str(net.game_port))
  await wait_mark("ready")
 else:
  await wait_mark("port");assert(net.join_room("127.0.0.1",int(FileAccess.get_file_as_string(folder.path_join("port"))),"Guest")==OK)
  while not net.is_online():await process_frame
  mark("ready")
 g.mp_enabled=true
 g._spawn_condiment_spline_segments_local(PackedVector3Array([Vector3(-.5,0,0),Vector3(.5,0,0)]),.008,"ketchup")
 mark("seed_host" if host else "seed_guest")
 await wait_mark("seed_guest" if host else "seed_host")
 if host:
  assert(g._scrape_local_sauce(Vector3.ZERO,Vector2.RIGHT,.1))
  mark("scraped")
  await wait_mark("guest_scraped")
 else:
  await wait_mark("scraped")
  while g.soda_slicks.size()<2:await process_frame
  var smear=g.soda_slicks[1]
  assert(smear.smeared and smear.spline_segments.size()==2)
  assert(is_equal_approx(smear.spline_segments[0].x,-.1))
  assert(is_equal_approx(smear.spline_segments[1].x,.1))
  # Another distinct pass from the guest must reach the host as well.
  smear.local_latched=false
  assert(g._scrape_local_sauce(Vector3.ZERO,Vector2.LEFT,.1))
  mark("guest_scraped")
 if host:
  while g.soda_slicks.size()<2 or g.soda_slicks[1].scrape>.34:await process_frame
  assert(g.soda_slicks[0].spline_segments.size()==4)
  mark("matched")
 else:await wait_mark("matched")
 print("SAUCE_NETWORK_OK")
 g.mp_enabled=false;net.leave(false);quit()
