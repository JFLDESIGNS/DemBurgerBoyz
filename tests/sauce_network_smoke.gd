extends SceneTree
var folder:String
func _initialize():call_deferred("run")
func mark(key:String):
 var f:=FileAccess.open(folder.path_join(key),FileAccess.WRITE);f.store_string("ok")
func wait_mark(key:String):
 var end:=Time.get_ticks_msec()+30000
 while not FileAccess.file_exists(folder.path_join(key)):
  assert(Time.get_ticks_msec()<end,key)
  await process_frame
func run():
 create_timer(50).timeout.connect(func():quit(1))
 folder=OS.get_environment("MP_TEST_DIR")
 var host:=OS.get_environment("MP_TEST_ROLE")=="host"
 var g=load("res://scenes/main.tscn").instantiate()
 g.set_script(load("res://tests/delivery_network_fixture.gd"));root.add_child(g);current_scene=g
 g.playing=true;g.grill_root=Node3D.new();g.world.add_child(g.grill_root)
 var net=root.get_node("NetManager")
 net.relay_url=""
 if host:
  assert(net.host_room("Sauce host","Sauce regression")==OK)
  while not net.is_online():await process_frame
  var f:=FileAccess.open(folder.path_join("port"),FileAccess.WRITE);f.store_string(str(net.game_port));f.close()
  await wait_mark("ready")
 else:
  await wait_mark("port")
  assert(net.join_room("127.0.0.1",int(FileAccess.get_file_as_string(folder.path_join("port"))),"Guest")==OK)
  while not net.is_online():await process_frame
  mark("ready")
 g.mp_enabled=true
 var p:=Vector3(g.GRILL_CENTER_X,g.GRILL_SURFACE_Y,g.GRILL_SURFACE_Z)
 if host:
  g._spawn_condiment_spline_segment(p-Vector3(.12,0,0),p+Vector3(.12,0,0),.015,"mustard")
  await wait_mark("spawned")
  for i in 3:
   g._scrape_slick_array(g.soda_slicks,p,Vector2(.04,0),.04,.2,"soda")
   g._scrape_slick_array(g.soda_slicks,p+Vector3(2,0,0),Vector2(.04,0),.04,.2,"soda")
   mark("pass"+str(i));await wait_mark("seen"+str(i))
 else:
  while g.soda_slicks.is_empty():await process_frame
  mark("spawned")
  for i in 3:
   await wait_mark("pass"+str(i));await create_timer(.15).timeout
   if i<2:
    assert(g.soda_slicks.size()==1 and g.soda_slicks[0].smeared)
    assert(is_equal_approx(g.soda_slicks[0].scrape,1.0-float(i+1)/3.0))
   else:assert(g.soda_slicks.is_empty())
   assert(g.condiment_smear_items.is_empty())
   mark("seen"+str(i))
 g.mp_enabled=false;net.leave(false)
 print("SAUCE_NETWORK_OK")
 g.queue_free()
 for i in 5:await process_frame
 quit()
