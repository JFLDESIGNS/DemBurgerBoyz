extends SceneTree
var folder:String
func _initialize():call_deferred("run")
func mark(key:String):FileAccess.open(folder.path_join(key),FileAccess.WRITE).store_string("ok")
func wait_mark(key:String):
 while not FileAccess.file_exists(folder.path_join(key)):await process_frame
func run():
 create_timer(100).timeout.connect(func():quit(1))
 folder=OS.get_environment("MP_TEST_DIR");var host=OS.get_environment("MP_TEST_ROLE")=="host"
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load(get_script().resource_path.get_base_dir().path_join("mobile_packing_fixture.gd")));root.add_child(g);current_scene=g;g.playing=true
 for i in g.STATION_COUNT:g.stations.append({"items":[],"patties":[]})
 var page=VBoxContainer.new();g.get_node("UI/Root").add_child(page)
 var m=load("res://scripts/grubbah.gd").new();m.name="Grubbah";g.add_child(m);m.setup(g,page);m.set_process(false);g._grubbah=m
 var net=root.get_node("NetManager");net.relay_url=""
 if host:
  assert(net.host_room("Mobile host","Packing regression")==OK)
  while not net.is_online():await process_frame
  FileAccess.open(folder.path_join("port"),FileAccess.WRITE).store_string(str(net.game_port))
  await wait_mark("ready")
 else:
  await wait_mark("port")
  assert(net.join_room("127.0.0.1",int(FileAccess.get_file_as_string(folder.path_join("port"))),"Guest")==OK)
  while not net.is_online():await process_frame
  mark("ready")
 g.mp_enabled=true
 if host:
  var working=g._create_drink_cup_node();g.world.add_child(working);g.cup_root=working;g.cup_flavor="cola";g.cup_soda_fill=.4
  g.fryer_ready_servings=1
  m.state={"number":9,"items":["bun_bottom","patty","bun_top","fries","soda_cola"],"phase":"bagging","selected":true,"base":20};m.age=2;m.publish();m.pack_ready_sides()
  while not m.state.get("side_packs",{}).has("soda_cola"):await process_frame
  assert(g.cup_root==working and g.cup_soda_fill==.4,"Guest drink cannot consume host cup")
  assert(g.fryer_ready_servings==0 and not g._serve_fly_busy)
  assert(not m.ticket_owner.get_meta("side_food_active",false))
  await wait_mark("packed")
  m.advance_side_packs(1.0);assert(m.try_seal_bag());await wait_mark("sealed");mark("done")
 else:
  while m.state.get("phase","")!="bagging":await process_frame
  var cup=g._create_drink_cup_node();g.world.add_child(cup);g.cup_root=cup;g.cup_held=true;g.cup_flavor="cola";g.cup_soda_fill=1
  g._submit_drink_hand_request(m.ticket_owner,"cola")
  while g._mp_pending_cup_hand!=0 or not m.state.get("side_packs",{}).has("soda_cola"):await process_frame
  assert(not g.cup_held and g.cup_soda_fill==0)
  assert(g._customer_soda_handed(m.ticket_owner) and m.state.side_packs.has("fries"));mark("packed")
  while m.state.phase!="sealed":await process_frame
  mark("sealed");await wait_mark("done")
 print("MOBILE_PACKING_NETWORK_OK ","host" if host else "guest")
 g.mp_enabled=false;net.leave(false);quit()
