extends SceneTree
var folder:String
func _initialize():call_deferred("run")
func mark(key:String):FileAccess.open(folder.path_join(key),FileAccess.WRITE).store_string("ok")
func wait_mark(key:String):
 while not FileAccess.file_exists(folder.path_join(key)):await process_frame
func run():
 create_timer(50).timeout.connect(func():quit(1))
 folder=OS.get_environment("MP_TEST_DIR");var host=OS.get_environment("MP_TEST_ROLE")=="host"
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/shared_interaction_fixture.gd"));root.add_child(g);current_scene=g;g.playing=true
 var net=root.get_node("NetManager");net.relay_url=""
 if host:
  assert(net.host_room("Host","Conversation test")==OK)
  while not net.is_online():await process_frame
  FileAccess.open(folder.path_join("port"),FileAccess.WRITE).store_string(str(net.game_port))
 else:
  await wait_mark("port");assert(net.join_room("127.0.0.1",int(FileAccess.get_file_as_string(folder.path_join("port"))),"Guest")==OK)
  while not net.is_online():await process_frame
 g.mp_enabled=true
 var c=load("res://scripts/customer.gd").new();c.setup(["bun_bottom","patty","bun_top"] as Array[String],Color.WHITE,90,0,0,0,-1,{},true);g.customers_root.add_child(c);c.set_process(false);c.is_waiting=host;c.set_meta("mp_net_id",77);g.customers.append(c)
 var social=load("res://scripts/customer_social.gd").new();social.game=g;g.add_child(social)
 var lines=social.REFERRAL_CONVERSATIONS[0]
 if host:
  await wait_mark("ready")
  for i in 2:
   social.speak_line(c,lines[i]);await wait_mark("line"+str(i))
 else:
  mark("ready")
  for i in 2:
   var found=false
   while not found:
    await process_frame
    for bubble in g.get_node("UI/Root").get_children():
     if bubble is PanelContainer and bubble.get_child_count()>0 and bubble.get_child(0) is Label and bubble.get_child(0).text==lines[i]:found=true
   await process_frame
   mark("line"+str(i))
 print("CONVERSATION_NETWORK_OK ","host" if host else "guest");quit()
