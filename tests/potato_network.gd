extends SceneTree
var folder: String
func mark(key: String): FileAccess.open(folder.path_join(key),FileAccess.WRITE).store_string("ok")
func wait_mark(key: String):
 while not FileAccess.file_exists(folder.path_join(key)): await process_frame
func _initialize(): call_deferred("run")
func run():
 create_timer(60).timeout.connect(func():push_error("POTATO_NETWORK_TIMEOUT");quit(1))
 folder=OS.get_environment("MP_TEST_DIR");var host=OS.get_environment("MP_TEST_ROLE")=="host"
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/potato_network_fixture.gd"));root.add_child(g);current_scene=g;g.playing=true
 var basket=Node3D.new();g.add_child(basket);g.fryer_baskets=[{"root":basket,"state":"empty","remote_peer":0,"remote_epoch":12,"pose_epoch":3}]
 var net=root.get_node("NetManager");net.relay_url=""
 if host:
  assert(net.host_room("Host","Potato test")==OK)
  while not net.is_online():await process_frame
  FileAccess.open(folder.path_join("port"),FileAccess.WRITE).store_string(str(net.game_port));await wait_mark("ready")
 else:
  await wait_mark("port");assert(net.join_room("127.0.0.1",int(FileAccess.get_file_as_string(folder.path_join("port"))),"Guest")==OK)
  while not net.is_online():await process_frame
  mark("ready")
 g.mp_enabled=true;g._mp_ensure_service()
 if host:
  g.money=100;g.economy_soda_price=4;g.economy_fries_price=6;g.economy_icecream_price=7;g.supply_stock.potato=0;mark("funded")
  while g.supply_orders.is_empty():await process_frame
  assert(g.supply_orders[0].id=="potato" and g.supply_orders[0].pack==16)
  assert(is_equal_approx(g.money,96.8))
  await wait_mark("order_seen")
  g.supply_orders.clear();g._credit_supply_delivery("potato",16,"stock");mark("delivered")
  await wait_mark("loaded")
  assert(g.supply_stock.potato==15 and g.fryer_baskets[0].state=="raw","Duplicate load must not consume twice")
  g.supply_stock.potato=0;g.fryer_baskets[0].state="empty";mark("empty")
  await wait_mark("rejected")
  assert(g.fryer_baskets[0].state=="empty" and g.supply_stock.potato==0)
  mark("done");await create_timer(.3).timeout
 else:
  await wait_mark("funded");g._buy_supply("potato")
  while g.supply_orders.is_empty():await process_frame
  mark("order_seen");await wait_mark("delivered")
  g.mp_request_fryer_load.rpc_id(1,0);g.mp_request_fryer_load.rpc_id(1,0)
  while g.supply_stock.get("potato",0)!=15 or g.fryer_baskets[0].state!="raw":await process_frame
  await create_timer(.15).timeout;assert(g.economy_soda_price==4 and g.economy_fries_price==6 and g.economy_icecream_price==7);mark("loaded");await wait_mark("empty")
  g.feedback.clear();g.mp_request_fryer_load.rpc_id(1,0)
  while g.feedback.is_empty():await process_frame
  assert(g.feedback.back().contains("Out of potatoes"));mark("rejected");await wait_mark("done")
 g.mp_enabled=false;net.leave(false);g.queue_free();await process_frame
 print("POTATO_NETWORK_OK ","host" if host else "guest");quit()
