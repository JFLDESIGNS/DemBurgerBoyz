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
 create_timer(70).timeout.connect(func():push_error("END_DAY_NETWORK_TIMEOUT");quit(1))
 folder=OS.get_environment("MP_TEST_DIR")
 var host:=OS.get_environment("MP_TEST_ROLE")=="host"
 var relay:=OS.get_environment("MP_TEST_TRANSPORT")=="relay"
 g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/audit_economy_fixture.gd"));root.add_child(g);current_scene=g
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
 g.game_over_location_btn=Button.new();g.get_node("UI/Root").add_child(g.game_over_location_btn)
 g.mp_enabled=true
 if host:
  g.money=400;g.shift_food_sales=200;g.shift_tips=30;g.shift_ingredient_cost=25;g.shift_restock_spend=14
  g.bank_savings=100;g.bank_savings_rate_pct=5;g.bank_loan=0;g.truck_bought_out=false;g.tutorial_mode=false;g._cut_collector_cut_done=false
  g._record_order_history(20,5,4,null)
  var large_photo:=Crypto.new().generate_random_bytes(180000)
  g.order_history.back()["photo"]=large_photo
  g._mp_queue_order_history()
  assert(var_to_bytes(g._mp_closed_shift_state()).size()<60000,"Closing recap must fit relay packet limit")
  g._end_day(true)
  assert(g.money==300 and g.bank_savings==105 and g.last_day_cut==100)
  assert(g._format_day_cut_recap().contains("Net food profit: $105.00"))
  mark("closed",JSON.stringify(g._mp_closed_shift_state()))
  await wait_mark("checked")
 else:
  await wait_mark("closed")
  while g.playing or not is_instance_valid(g._shift_results):await process_frame
  var state:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("closed")))
  for field in g.CLOSED_SHIFT_FIELDS:
   var actual=g.get(field)
   assert(str(actual)==str(state[field]) or (typeof(actual) in [TYPE_INT,TYPE_FLOAT] and is_equal_approx(float(actual),float(state[field]))),"Closing mismatch: "+field)
  assert(g.order_history.back().profit==21)
  g.mp_shift_closed(state,0.0)
  assert(g.bank_savings==105 and g.money==300,"Repeated closing must not reapply interest or cut")
  g.mp_sync_economy(1.0,0,0.0,1,0,0,0.0,0,[],[],[])
  assert(g.money==300,"Stale economy must not overwrite final totals")
  while not g.order_history.back().has("photo") or g.order_history.back().photo.size()!=180000:await process_frame
  mark("checked")
 print("END_DAY_NETWORK_AUDIT_OK ","host" if host else "guest")
 g.mp_enabled=false;net.leave(false);quit()
