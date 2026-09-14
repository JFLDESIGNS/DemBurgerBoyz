extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var game=load("res://scenes/main.tscn").instantiate()
 game.set_script(load(get_script().resource_path.get_base_dir().path_join("active_order_fixture.gd")))
 root.add_child(game);current_scene=game;game.playing=true
 for i in 2:
  var c=load("res://scripts/customer.gd").new()
  c.set_meta("mp_net_id",800+i)
  c.is_waiting=true;c.order.assign(["bun_bottom","patty","bun_top"])
  game.customers.append(c)
  var ticket=Control.new();root.add_child(ticket);game.tickets[c]=ticket
 game.selected_customer=game.customers[0]
 game._try_auto_serve()
 assert(game.served_ids==[800],"Identical orders serve current customer only")
 game.served_ids.clear();game.customers[0].set_meta("blocked",true)
 game._try_auto_serve();assert(game.served_ids.is_empty(),"No stealing another customer's burger when current side not ready")
 game._select_ticket_local(game.customers[1]);game._try_auto_serve()
 assert(game.served_ids==[801],"Clicked order takes priority")
 game.mp_order_selected(800,12);game.mp_order_selected(801,11)
 assert(game.selected_customer==game.customers[0],"Stale selection cannot override newer one")
 game.mp_order_selected(801,13);assert(game.selected_customer==game.customers[1])
 for c in game.customers:c.free()
 print("ACTIVE_ORDER_OK")
 game.queue_free();await process_frame;quit()
