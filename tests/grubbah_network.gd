extends SceneTree
var folder:String
func _initialize():call_deferred("run")
func mark(key:String):
 var f=FileAccess.open(folder.path_join(key),FileAccess.WRITE);f.store_string("ok")
func wait_mark(key:String):
 while not FileAccess.file_exists(folder.path_join(key)):await process_frame
func run():
 create_timer(40).timeout.connect(func():quit(1))
 folder=OS.get_environment("MP_TEST_DIR")
 var host=OS.get_environment("MP_TEST_ROLE")=="host"
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/grubbah_fixture.gd"));root.add_child(g);current_scene=g
 g.playing=true;g.ticket_box=HBoxContainer.new();g.get_node("UI/Root").add_child(g.ticket_box);g.stations=[{"items":[],"patties":[],"fresh_active":false}]
 var page=VBoxContainer.new();g.get_node("UI/Root").add_child(page)
 var m=load("res://scripts/grubbah.gd").new();m.name="Grubbah";g.add_child(m);m.setup(g,page);m.set_process(false);g._grubbah=m
 var net=root.get_node("NetManager");net.relay_url=""
 if host:
  assert(net.host_room("Grubbah host","Mobile regression")==OK)
  while not net.is_online():await process_frame
  var f=FileAccess.open(folder.path_join("port"),FileAccess.WRITE);f.store_string(str(net.game_port));f.close()
  await wait_mark("ready")
 else:
  await wait_mark("port")
  assert(net.join_room("127.0.0.1",int(FileAccess.get_file_as_string(folder.path_join("port"))),"Guest")==OK)
  while not net.is_online():await process_frame
  mark("ready")
 g.mp_enabled=true
 if host:
  g.money=100;g._buy_shop_item_local("chef_knife");assert(g.money==50);assert(g.owned_machines.chef_knife);g._mp_broadcast_economy()
  m.new_order();await wait_mark("cancelled");assert(m.state.is_empty());m.new_order();await wait_mark("accepted");m.auto_lay_paper()
  assert(m.state.phase in ["accepted","paper"])
  await wait_mark("paper");assert(m.state.phase=="paper")
  await wait_mark("knife");assert(m.knife_owner!=0)
  m.state.phase="bagging";m.state.items=["bun_bottom","patty","bun_top"];m.publish()
  await wait_mark("sealed");assert(m.state.phase=="sealed")
  mark("done")
 else:
  while m.state.is_empty():await process_frame
  assert(m.state.phase=="accepted");m.request("cancel");await create_timer(.25).timeout;assert(m.state.is_empty());mark("cancelled")
  while m.state.is_empty():await process_frame
  assert(m.state.phase=="accepted");assert(g.tickets.has(m.ticket_owner));mark("accepted")
  while m.state.phase!="paper":await process_frame
  assert(m.is_selected());assert(g._customer_by_net_id(1000000+int(m.state.number))==m.ticket_owner);mark("paper")
  assert(g.owned_machines.get("chef_knife",false));m.request("knife");await create_timer(.25).timeout;assert(m.knife_owner==net.my_id());mark("knife")
  while m.state.phase!="bagging":await process_frame
  m.request("seal");m.request("seal");await create_timer(.25).timeout;assert(m.state.phase=="sealed");mark("sealed")
  await wait_mark("done")
 print("GRUBBAH_NETWORK_OK")
 g.mp_enabled=false;net.leave(false);quit()
