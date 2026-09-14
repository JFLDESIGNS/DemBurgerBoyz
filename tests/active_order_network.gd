extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 create_timer(25).timeout.connect(func():quit(1))
 var game=load("res://scenes/main.tscn").instantiate()
 game.set_script(load(get_script().resource_path.get_base_dir().path_join("active_order_fixture.gd")))
 root.add_child(game);current_scene=game;game.playing=true
 for i in 2:
  var c=load("res://scripts/customer.gd").new()
  c.set_meta("mp_net_id",800+i)
  c.is_waiting=true;c.order.assign(["bun_bottom","patty","bun_top"])
  game.customers.append(c)
  var ticket=Control.new();root.add_child(ticket);game.tickets[c]=ticket
 var folder=OS.get_environment("MP_TEST_DIR")
 var host=OS.get_environment("MP_TEST_ROLE")=="host"
 var net=root.get_node("NetManager");net.relay_url=""
 if host:
  assert(net.host_room("Order host","Order test")==OK)
  while not net.is_online():await process_frame
  var f=FileAccess.open(folder.path_join("port"),FileAccess.WRITE);f.store_string(str(net.game_port));f.close()
 else:
  while not FileAccess.file_exists(folder.path_join("port")):await process_frame
  assert(net.join_room("127.0.0.1",int(FileAccess.get_file_as_string(folder.path_join("port"))),"Order guest")==OK)
  while not net.is_online():await process_frame
 game.mp_enabled=true
 await create_timer(0.6).timeout
 if not host:game._select_ticket(game.customers[1])
 var deadline=Time.get_ticks_msec()+10000
 while game.selected_customer!=game.customers[1]:
  assert(Time.get_ticks_msec()<deadline,"Both peers receive selected order")
  await process_frame
 assert(game._mp_order_revision==1)
 await create_timer(0.2).timeout
 if host:
  assert(game.served_ids==[801],"Host serves guest-selected order exactly once")
 else:
  game._try_auto_serve();assert(game.served_ids.is_empty(),"Guest never duplicates auto-serve")
 await create_timer(0.3).timeout
 game.mp_order_selected(800,0);assert(game.selected_customer==game.customers[1])
 game.mp_enabled=false;net.leave(false)
 for c in game.customers:c.free()
 print("ACTIVE_NETWORK_OK")
 game.queue_free();await process_frame;quit()
