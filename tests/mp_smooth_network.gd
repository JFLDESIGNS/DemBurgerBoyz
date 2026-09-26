extends SceneTree
class Guest extends Node3D:
 var is_waiting := true
 var is_leaving := false
 var is_cut_collector := false
 var is_challenge_guest := true
 var order: Array[String] = ["bun_bottom","patty","bun_top"]
var folder: String
func mark(key: String):FileAccess.open(folder.path_join(key),FileAccess.WRITE).store_string("ok")
func wait_mark(key: String):
 while not FileAccess.file_exists(folder.path_join(key)):await process_frame
func _initialize():call_deferred("run")
func run():
 create_timer(45).timeout.connect(func():quit(1))
 folder=OS.get_environment("MP_TEST_DIR")
 var host=OS.get_environment("MP_TEST_ROLE")=="host"
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/mp_smooth_fixture.gd"));root.add_child(g)
 g.playing=true;g._setup_stations_data();g._build_challenge_ui()
 var customer=Guest.new();customer.set_meta("mp_net_id",77);g.add_child(customer);g.customers.append(customer);g.tickets[customer]=Control.new();g.add_child(g.tickets[customer]);g._challenge_customer=customer
 var net=root.get_node("NetManager");net.relay_url=""
 if host:
  assert(net.host_room("Host","Smooth regression")==OK)
  while not net.is_online():await process_frame
  FileAccess.open(folder.path_join("port"),FileAccess.WRITE).store_string(str(net.game_port))
  await wait_mark("ready")
 else:
  await wait_mark("port");assert(net.join_room("127.0.0.1",int(FileAccess.get_file_as_string(folder.path_join("port"))),"Guest")==OK)
  while not net.is_online():await process_frame
  mark("ready")
 g.mp_enabled=true
 if host:
  g.mp_challenge_state.rpc("offer",10,10,180,180,50)
  await wait_mark("offer")
  g.mp_challenge_state.rpc("active",10,10,180,180,50)
  for i in 120:
   g.mp_sync_station.rpc(0,["bun_bottom","bun_top"],[],true,120-float(i)*.1,false)
   g.mp_order_selected.rpc(77,1)
   g.mp_sync_economy.rpc(100.0,0,float(i),1,0,0,0.0,0,["bun_bottom"],[12],[120.0-float(i)])
  await wait_mark("checked")
  g.stations[0].items.clear();g.supply_stock["bun_bottom"]=12;g.supply_stock["bun_top"]=12
  mark("request_buns")
  await wait_mark("buns")
  assert(g.stations[0].items==["bun_bottom","bun_top"])
  mark("done")
 else:
  while g._challenge_phase!="offer":await process_frame
  assert(g.challenge_overlay.visible);mark("offer")
  while g._challenge_phase!="active" or g.stations[0].freshness>108.2:await process_frame
  await process_frame
  assert(not g.challenge_overlay.visible);assert(g.parades==1)
  while float(g.supply_fresh.get("bun_bottom",999))>1.0:await process_frame
  assert(g.rebuilds==1);assert(g.selections==1)
  assert(g.phone_refreshes==1);assert(g.stock_refreshes<=1)
  print("120 FRESHNESS SNAPSHOTS: PHONE=",g.phone_refreshes," STOCK=",g.stock_refreshes)
  assert(g._order_can_receive_burger(customer))
  g._queue_station_review_thumbnail(0);assert(g.stations[0].get("review_thumb_pending_signature","")=="")
  print("120 SNAPSHOTS: REBUILDS=",g.rebuilds," SELECTIONS=",g.selections)
  mark("checked");await wait_mark("request_buns")
  g.stations[0].items.clear();g._add_ingredient_to_station(0,"bun_bottom")
  while g.stations[0].items.is_empty():await process_frame
  mark("buns");await wait_mark("done")
 print("MP_CHALLENGE_SMOOTH_OK")
 g.mp_enabled=false;net.leave(false);quit()
