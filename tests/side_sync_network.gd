extends SceneTree
class Customer extends Node3D:
 var order:Array[String]=[]
 var is_waiting:=true
 var is_leaving:=false
 var taps:=0
 func _begin_order_announce():taps+=1
var folder:String
func mark(key:String):FileAccess.open(folder.path_join(key),FileAccess.WRITE).store_string("ok")
func wait_mark(key:String):
 while not FileAccess.file_exists(folder.path_join(key)):await process_frame
func _initialize():call_deferred("run")
func run():
 create_timer(45).timeout.connect(func():quit(1))
 folder=OS.get_environment("MP_TEST_DIR");var host=OS.get_environment("MP_TEST_ROLE")=="host"
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/side_sync_fixture.gd"));root.add_child(g);current_scene=g;g.playing=true
 var c=Customer.new();c.order.assign(["soda_cola"]);c.set_meta("mp_net_id",9901);g.add_child(c);g.customers.append(c)
 var fries=Customer.new();fries.order.assign(["bun_bottom","patty","bun_top","fries"]);fries.set_meta("mp_net_id",9902);g.add_child(fries);g.customers.append(fries)
 g.fryer_ready_servings=1
 var net=root.get_node("NetManager");net.relay_url=""
 if host:
  assert(net.host_room("Host","Side order sync")==OK)
  while not net.is_online():await process_frame
  FileAccess.open(folder.path_join("port"),FileAccess.WRITE).store_string(str(net.game_port));await wait_mark("ready")
 else:
  await wait_mark("port");assert(net.join_room("127.0.0.1",int(FileAccess.get_file_as_string(folder.path_join("port"))),"Guest")==OK)
  while not net.is_online():await process_frame
  mark("ready")
 g.mp_enabled=true
 if host:
  g._serve_fly_busy=true;mark("busy")
  await wait_mark("queued")
  while g._mp_side_requests.is_empty():await process_frame
  assert(g.served.is_empty());g._serve_fly_busy=false;g._mp_process_food_requests()
  assert(g.served.size()==1 and g.served[0][1]==9901);mark("accepted")
  await wait_mark("fries_sent")
  while not g._customer_fries_handed(fries):await process_frame
  assert(g.fryer_ready_servings==0);assert(g.side_visuals==["fries"])
  g.mp_customer_order_tap.rpc(9902);mark("tap_sent")
  await wait_mark("checked")
  fries.order.assign(["fries"]);fries.remove_meta("fries_handed");fries.remove_meta("fries_visual_started")
  g._mark_customer_fries_handed(fries,false);g.fryer_ready_servings=1
  g.mp_fries_hand(9902)
  assert(g.served.back()==["fries_only",9902],"Finish fries ticket after handoff releases queue slot")
  assert(g.fryer_ready_servings==0);mark("done")
 else:
  await wait_mark("busy")
  g.cup_root=Node3D.new();g.add_child(g.cup_root);g.cup_held=true;g.cup_flavor="cola";g.cup_soda_fill=1
  g._submit_serve_request(c,-2);await create_timer(.15).timeout
  assert(g.cup_held and is_instance_valid(g.cup_root),"Keep drink while host queues request");mark("queued");await wait_mark("accepted")
  while g._mp_pending_cup_hand!=0:await process_frame
  assert(not g.cup_held and g.cup_root==null)
  g.cup_root=Node3D.new();g.add_child(g.cup_root);g.cup_held=true;g.cup_flavor="cola";g.cup_soda_fill=1
  g._submit_serve_request(c,-2)
  while g._mp_pending_cup_hand!=0:await process_frame
  assert(g.cup_held and is_instance_valid(g.cup_root),"Rejected duplicate keeps guest drink")
  g.fries_pack_held=true;g.fries_pack_root=Node3D.new();g.add_child(g.fries_pack_root)
  g._serve_held_fries_pack(fries);mark("fries_sent")
  while g._mp_pending_fries_hand:await process_frame
  assert(not g.fries_pack_held)
  await wait_mark("tap_sent");await create_timer(.15).timeout
  assert(fries.taps==1);assert(g.side_visuals==["fries"]);mark("checked");await wait_mark("done")
 print("SIDE_SYNC_NETWORK_OK ","host" if host else "guest");g.mp_enabled=false;net.leave(false);quit()
