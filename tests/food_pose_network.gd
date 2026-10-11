extends SceneTree
class Customer extends Node3D:
 var order:Array[String]=[]
 var is_waiting:=true
 var is_leaving:=false
 var is_challenge_guest:=false
 var taps:=0
 func _begin_order_announce():taps+=1
var folder:String
func mark(key:String):FileAccess.open(folder.path_join(key),FileAccess.WRITE).store_string("ok")
func wait_mark(key:String):
 while not FileAccess.file_exists(folder.path_join(key)):await process_frame
func _initialize():call_deferred("run")
func run():
 create_timer(45).timeout.connect(func():push_error("FOOD_POSE_TIMEOUT");quit(1))
 folder=OS.get_environment("MP_TEST_DIR");var host=OS.get_environment("MP_TEST_ROLE")=="host"
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/food_pose_fixture.gd"));root.add_child(g);current_scene=g;g.playing=true
 var c=Customer.new();c.order.assign(["icecream"]);c.set_meta("mp_net_id",9930);g.add_child(c);g.customers.append(c)
 var net=root.get_node("NetManager");net.relay_url=""
 if host:
  assert(net.host_room("Host","Food poses")==OK)
  while not net.is_online():await process_frame
  FileAccess.open(folder.path_join("port"),FileAccess.WRITE).store_string(str(net.game_port));await wait_mark("ready")
 else:
  await wait_mark("port");assert(net.join_room("127.0.0.1",int(FileAccess.get_file_as_string(folder.path_join("port"))),"Guest")==OK)
  while not net.is_online():await process_frame
  mark("ready")
 g.mp_enabled=true;g._mp_ensure_service()
 g.patties_root=Node3D.new();g.add_child(g.patties_root)
 var patty=load("res://scripts/patty.gd").new();g.patties_root.add_child(patty);patty.net_id=9915;patty.set_process(false)
 if host:
  for kind in ["drink","fries","icecream"]:
   await wait_mark(kind)
   var dict:Dictionary=g._mp_remote_cups if kind=="drink" else (g._mp_remote_fries if kind=="fries" else g._mp_remote_icecreams)
   while dict.is_empty():await process_frame
   var food:Node3D=dict.values()[0]
   while not food.visible:await process_frame
   await create_timer(.15).timeout
   assert(food.global_position.distance_to(Vector3(.25,.5,.75))<.02,"Replicated position")
   mark(kind+"_seen");await wait_mark(kind+"_released")
   while food.visible:await process_frame
   mark(kind+"_hidden")
  await wait_mark("seasoned")
  while patty.seasoning<.24:await process_frame
  assert(patty._season_fleck_count>0);g.mp_season_patty.rpc(9915,.25);mark("season_seen")
  g._serve_fly_busy=true;mark("busy");await wait_mark("queued")
  while g._mp_side_requests.is_empty():await process_frame
  g._serve_fly_busy=false;g._mp_process_food_requests()
  while g.served.is_empty():await process_frame
  assert(g.served==[["icecream",9930]]);mark("accepted")
  await wait_mark("done")
 else:
  for kind in ["drink","fries","icecream"]:
   var method="mp_cup_pose" if kind=="drink" else ("mp_tool_pose" if kind=="fries" else "mp_icecream_pose")
   var args:Array=[true,.25,.5,.75,0.0,0.0,0.0,"cola",1.0,.2,.1,false,false] if kind=="drink" else ([9,true,.25,.5,.75,false,0.0,0.0,0.0] if kind=="fries" else [true,.25,.5,.75,0.0,0.0,0.0,1.0,false])
   g._mp_queue_motion(method,args);mark(kind);await wait_mark(kind+"_seen")
   args[1 if kind=="fries" else 0]=false;g._mp_queue_motion(method,args);mark(kind+"_released");await wait_mark(kind+"_hidden")
  g.mp_season_patty.rpc(9915,.25);mark("seasoned");await wait_mark("season_seen")
  while patty.seasoning<.49:await process_frame
  assert(patty._season_fleck_count>0)
  await wait_mark("busy")
  g.icecream_cone_root=Node3D.new();g.add_child(g.icecream_cone_root);g.icecream_cone_held=true;g.icecream_cone_fill=1.0
  g._submit_icecream_hand_request(c);await create_timer(.1).timeout
  assert(g.icecream_cone_held);mark("queued");await wait_mark("accepted")
  while g._mp_pending_icecream_hand!=0:await process_frame
  assert(not g.icecream_cone_held and g.icecream_cone_root==null)
  g.icecream_cone_root=Node3D.new();g.add_child(g.icecream_cone_root);g.icecream_cone_held=true
  g._submit_icecream_hand_request(c)
  while g._mp_pending_icecream_hand!=0:await process_frame
  assert(g.icecream_cone_held,"Rejected duplicate keeps cone");assert(g.side_visuals==["icecream"])
  mark("done")
 print("FOOD_POSE_NETWORK_OK ","host" if host else "guest");g.mp_enabled=false;net.leave(false);quit()
