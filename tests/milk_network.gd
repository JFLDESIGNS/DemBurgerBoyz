extends SceneTree
var folder: String
func mark(key: String): FileAccess.open(folder.path_join(key),FileAccess.WRITE).store_string("ok")
func wait_mark(key: String):
 while not FileAccess.file_exists(folder.path_join(key)): await process_frame
func _initialize(): call_deferred("run")
func run():
 create_timer(45).timeout.connect(func():push_error("MILK_NETWORK_TIMEOUT");quit(1))
 folder=OS.get_environment("MP_TEST_DIR");var host=OS.get_environment("MP_TEST_ROLE")=="host"
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/potato_network_fixture.gd"));root.add_child(g);current_scene=g;g.playing=true
 g.owned_machines[g.SHOP_ICECREAM_MACHINE]=true
 var milk=load("res://scripts/milk_refill.gd").new();milk.name="MilkRefill";milk.game=g;g.add_child(milk);milk.set_process(false)
 var net=root.get_node("NetManager");net.relay_url=""
 if host:
  assert(net.host_room("Host","Milk test")==OK)
  while not net.is_online():await process_frame
  FileAccess.open(folder.path_join("port"),FileAccess.WRITE).store_string(str(net.game_port));await wait_mark("ready")
 else:
  await wait_mark("port");assert(net.join_room("127.0.0.1",int(FileAccess.get_file_as_string(folder.path_join("port"))),"Guest")==OK)
  while not net.is_online():await process_frame
  mark("ready")
 g.mp_enabled=true;g._mp_ensure_service()
 if host:
  g.supply_stock.milk=2;g.icecream_mix_servings=0;mark("funded")
  await wait_mark("refilled")
  assert(g.supply_stock.milk==1 and g.icecream_mix_servings==6 and g.milk_carton_refills==3)
  mark("checked_refill")
  await wait_mark("reserved")
  assert(g.icecream_mix_servings==5)
  await wait_mark("full_rejected")
  assert(g.supply_stock.milk==1 and g.icecream_mix_servings==5)
  mark("done");await create_timer(.2).timeout
 else:
  await wait_mark("funded");milk.request("refill")
  while g.icecream_mix_servings!=6 or not milk.pending.is_empty():await process_frame
  milk.action.rpc_id(1,milk.serial,"refill") # Replayed request cannot consume a second carton.
  mark("refilled");await wait_mark("checked_refill")
  var cone=Node3D.new();g.add_child(cone)
  milk.reserve_cone(cone)
  while not cone.get_meta("milk_reserved",false):await process_frame
  assert(milk.reserve_cone(cone))
  while g.icecream_mix_servings!=5:await process_frame
  mark("reserved");g.feedback.clear();milk.request("refill")
  while not milk.pending.is_empty():await process_frame
  assert(g.feedback.back().contains("already"));mark("full_rejected");await wait_mark("done")
 g.mp_enabled=false;net.leave(false);g.queue_free();await process_frame
 print("MILK_NETWORK_OK ","host" if host else "guest");quit()
