extends SceneTree
var folder: String
func mark(key:String):FileAccess.open(folder.path_join(key),FileAccess.WRITE).store_string("ok")
func wait_mark(key:String):
 while not FileAccess.file_exists(folder.path_join(key)):await process_frame
func _initialize():call_deferred("run")
func run():
 create_timer(45).timeout.connect(func():push_error("INGREDIENT_NETWORK_TIMEOUT");quit(1))
 folder=OS.get_environment("MP_TEST_DIR");var host=OS.get_environment("MP_TEST_ROLE")=="host"
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/queue_snack_network_fixture.gd"));root.add_child(g);current_scene=g;g.playing=true
 var audio=load("res://scripts/game_audio.gd").new();g.add_child(audio);g.game_audio=audio
 var c=load("res://scripts/mobile_ticket_owner.gd").new();g.customers_root.add_child(c);c.set_process(false);c.set_meta("mp_net_id",99123);g.customers.append(c)
 var net=root.get_node("NetManager");net.relay_url="ws://127.0.0.1:18769" if OS.get_environment("MP_TEST_TRANSPORT")=="relay" else ""
 if host:
  assert(net.host_room("Host","Ingredient effects")==OK)
  while not net.is_online():await process_frame
  FileAccess.open(folder.path_join("port"),FileAccess.WRITE).store_string((net.room_code if OS.get_environment("MP_TEST_TRANSPORT")=="relay" else str(net.game_port)));await wait_mark("ready")
 else:
  await wait_mark("port");assert((net.join_by_code(FileAccess.get_file_as_string(folder.path_join("port")),"Guest") if OS.get_environment("MP_TEST_TRANSPORT")=="relay" else net.join_room("127.0.0.1",int(FileAccess.get_file_as_string(folder.path_join("port"))),"Guest"))==OK)
  while not net.is_online():await process_frame
  mark("ready")
 g.mp_enabled=true;g._mp_ensure_service()
 var sling=g._ensure_ingredient_slingshot()
 if host:
  g.mp_ingredient_pull.rpc("tomato",Vector2(.4,.6),Vector2(.4,.8),true)
  await wait_mark("saw_stretch")
  g.mp_ingredient_pull.rpc("tomato",Vector2.ZERO,Vector2.ZERO,false)
  g.mp_customer_flung_food_reaction.rpc(99123,"tomato",Vector3(0,1,0),"face",false)
  await wait_mark("saw_hit")
  assert(c.get_node("HitWa").stream.get_length()<.34)
  g.supply_stock["onion"]=2
  mark("fire_now")
  while not g.world.has_node("ReplicatedIngredientFlight"):await process_frame
  assert(g.supply_stock["onion"]==1)
  mark("host_saw_flight")
  await wait_mark("guest_saw_flight")
  mark("done");await create_timer(.2).timeout
 else:
  while not sling.remote_pulls.has(1):await process_frame
  assert(sling.remote_pulls[1].sound.playing);mark("saw_stretch")
  while not c.has_node("HitWa"):await process_frame
  assert(c.get_node("HitWa").stream.get_length()<.34)
  assert(sling.remote_pulls.is_empty());mark("saw_hit")
  await wait_mark("fire_now")
  g.mp_ingredient_slingshot.rpc_id(1,"onion",Vector2(.4,.8),Vector2(.4,.1))
  while not g.world.has_node("ReplicatedIngredientFlight"):await process_frame
  mark("guest_saw_flight");await wait_mark("host_saw_flight");await wait_mark("done")
 g.mp_enabled=false;net.leave(false);g.queue_free();await process_frame
 print("INGREDIENT_EFFECT_NETWORK_OK ","host" if host else "guest");quit()
