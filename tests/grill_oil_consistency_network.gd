extends SceneTree
var folder:String
var g
func _initialize():call_deferred("run")
func mark(key:String,value:String="ok"):FileAccess.open(folder.path_join(key),FileAccess.WRITE).store_string(value)
func wait_mark(key:String):
 while not FileAccess.file_exists(folder.path_join(key)):await process_frame
func signature()->String:
 var rows:Array=[]
 for item in g.oil_slicks:rows.append([item.oil_id,item.radius,item.life,item.crust_roll,bool(item.get("crust",false))])
 return JSON.stringify(rows)
func run():
 create_timer(70).timeout.connect(func():push_error("OIL_CONSISTENCY_TIMEOUT");quit(1))
 folder=OS.get_environment("MP_TEST_DIR")
 var host:=OS.get_environment("MP_TEST_ROLE")=="host"
 var relay:=OS.get_environment("MP_TEST_TRANSPORT")=="relay"
 g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/patty_pool_fixture.gd"));root.add_child(g);current_scene=g
 g.grill_root=Node3D.new();g.world.add_child(g.grill_root);g.grill.resize(g.GRILL_SLOTS);g.grill_on=false;g.playing=true
 var net=root.get_node("NetManager");net.relay_url="ws://127.0.0.1:18769" if relay else ""
 if host:
  assert(net.host_room("Oil Host","Oil audit")==OK)
  while not net.is_online():await process_frame
  mark("connection",net.room_code if relay else str(net.game_port));await wait_mark("connected")
 else:
  await wait_mark("connection")
  var address:=FileAccess.get_file_as_string(folder.path_join("connection"))
  assert((net.join_by_code(address,"Oil Guest") if relay else net.join_room("127.0.0.1",int(address),"Oil Guest"))==OK)
  while not net.is_online():await process_frame
  mark("connected")
 g.mp_enabled=true
 var at:Vector3=Vector3(g.GRILL_CENTER_X,g.GRILL_SURFACE_Y,g.GRILL_SURFACE_Z)
 if host:
  g._mp_publish_oil_slick(at.x,at.z,.01);g._mp_publish_oil_slick(at.x+.12,at.z,.01)
  await wait_mark("seed_signature")
  assert(signature()==FileAccess.get_file_as_string(folder.path_join("seed_signature")),"Oil radius, lifetime, residue roll and IDs match")
  mark("seed_checked")
  await wait_mark("predicted")
  while g.oil_slicks.size()!=1:await process_frame
  mark("host_cleaned");await wait_mark("guest_cleaned")
  for i in 48:g._mp_publish_oil_slick(at.x+float(i%8)*.02,at.z+float(i/8)*.02,.01)
  await wait_mark("all_seeded")
 else:
  while g.oil_slicks.size()!=2:await process_frame
  mark("seed_signature",signature());await wait_mark("seed_checked")
  assert(g._scrape_slick_array(g.oil_slicks,at,Vector2.RIGHT,.3,.001,"oil"))
  assert(g.oil_slicks.size()==1);mark("predicted");await wait_mark("host_cleaned")
  await create_timer(.25).timeout
  assert(g.oil_slicks.size()==1,"Host acknowledgement must leave neighbor intact")
  mark("guest_cleaned")
  while g.oil_slicks.size()!=49:await process_frame
  mark("all_seeded")
 # Advance each replica with different unrelated RNG histories.
 seed(42 if host else 98765)
 for item in g.oil_slicks:item.age=item.life-.01
 g._update_oil_slicks(.1)
 mark("aged_host" if host else "aged_guest",signature())
 await wait_mark("aged_guest" if host else "aged_host")
 assert(signature()==FileAccess.get_file_as_string(folder.path_join("aged_guest" if host else "aged_host")),"Cook-off must leave the same crust on both peers")
 mark("done_host" if host else "done_guest");await wait_mark("done_guest" if host else "done_host")
 print("GRILL_OIL_CONSISTENCY_NETWORK_OK ","host" if host else "guest")
 g.mp_enabled=false;net.leave(false);quit()
