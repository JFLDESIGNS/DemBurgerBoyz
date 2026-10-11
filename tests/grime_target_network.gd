extends SceneTree
var folder:String
func _initialize():call_deferred("run")
func mark(key:String,value:String="ok"):FileAccess.open(folder.path_join(key),FileAccess.WRITE).store_string(value)
func wait_mark(key:String):
 while not FileAccess.file_exists(folder.path_join(key)):await process_frame
func run():
 create_timer(45).timeout.connect(func():quit(1))
 folder=OS.get_environment("MP_TEST_DIR");var host:=OS.get_environment("MP_TEST_ROLE")=="host"
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/patty_pool_fixture.gd"));root.add_child(g);current_scene=g
 g.grill_residue.resize(g.GRILL_SLOTS);g.grill_residue_centers.resize(g.GRILL_SLOTS);g.grill_residue_chunks.resize(g.GRILL_SLOTS);g.grill_residue_kind.resize(g.GRILL_SLOTS)
 for i in g.GRILL_SLOTS:
  g.grill_residue[i]=0.0;g.grill_residue_centers[i]=Vector3.ZERO;g.grill_residue_chunks[i]=[]
 var a:=0 if host else 2;var b:=1;var c:=2 if host else 0
 g.grill_residue_centers[a]=Vector3(1,0,2);g.grill_residue_centers[b]=Vector3(1.12,0,2);g.grill_residue_centers[c]=Vector3(1.24,0,2)
 for i in [a,b,c]:g.grill_residue[i]=1.0
 var net=root.get_node("NetManager");net.relay_url=""
 if host:
  assert(net.host_room("Host","Grime targeting")==OK)
  while not net.is_online():await process_frame
  mark("port",str(net.game_port));await wait_mark("ready")
 else:
  await wait_mark("port");assert(net.join_room("127.0.0.1",int(FileAccess.get_file_as_string(folder.path_join("port"))),"Guest")==OK)
  while not net.is_online():await process_frame
  mark("ready")
 g.mp_enabled=true
 if host:
  g.grill_residue[a]=.5;g.mp_residue_amt.rpc(a,.5,1.0,2.0)
  await wait_mark("guest_cleaned")
  while g.grill_residue[a]!=0:await process_frame
  assert(g.grill_residue[b]==1 and g.grill_residue[c]==1)
  g.mp_residue_clean.rpc(a,1.0,2.0);g.mp_residue_chip.rpc(a,1.0,0.0,1.0,2.0,false)
  mark("duplicate_sent");await wait_mark("guest_checked")
  while not is_equal_approx(g.grill_residue[b],.4):await process_frame
  g._scrape_finish_clean(b);mark("host_cleaned")
  await wait_mark("finished")
 else:
  while not is_equal_approx(g.grill_residue[a],.5):await process_frame
  assert(g.grill_residue[b]==1 and g.grill_residue[c]==1)
  g._scrape_finish_clean(a);mark("guest_cleaned")
  await wait_mark("duplicate_sent");await create_timer(.15).timeout
  assert(g.grill_residue[b]==1 and g.grill_residue[c]==1,"Duplicate cleanup cannot erase either neighbor")
  g.grill_residue[b]=.4;g.mp_residue_amt.rpc(b,.4,1.12,2.0);mark("guest_checked")
  await wait_mark("host_cleaned")
  while g.grill_residue[b]!=0:await process_frame
  assert(g.grill_residue[c]==1);mark("finished")
 assert(g.grill_residue[c]==1)
 print("GRIME_TARGET_NETWORK_OK ","host" if host else "guest")
 g.mp_enabled=false;net.leave(false);quit()
