extends SceneTree
var folder:String
func _initialize():call_deferred("run")
func mark(key:String):
 var f=FileAccess.open(folder.path_join(key),FileAccess.WRITE);f.store_string("ok")
func wait_mark(key:String):
 while not FileAccess.file_exists(folder.path_join(key)):await process_frame
func run():
 create_timer(100).timeout.connect(func():push_error("HOTDOG_DRAG_TIMEOUT");quit(1))
 folder=OS.get_environment("MP_TEST_DIR")
 var hosting=OS.get_environment("MP_TEST_ROLE")=="host"
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/hotdog_challenge_fixture.gd"))
 root.add_child(g);current_scene=g
 g.playing=true;g._kitchen_ready=true;g.stations=[{"items":[],"patties":[]}]
 var boss=g._ensure_hotdog_challenge();boss.set_process(false);boss.projectiles.set_process(false)
 var net=root.get_node("NetManager");net.relay_url=""
 if hosting:
  assert(net.host_room("Trash Host","Trash Test")==OK)
  while not net.is_online():await process_frame
  var f=FileAccess.open(folder.path_join("port"),FileAccess.WRITE);f.store_string(str(net.game_port));f.close()
  await wait_mark("guest_ready")
 else:
  await wait_mark("port")
  assert(net.join_room("127.0.0.1",int(FileAccess.get_file_as_string(folder.path_join("port"))),"Trash Guest")==OK)
  while not net.is_online():await process_frame
 g.mp_enabled=true
 var h=boss.projectiles
 var pos=Vector3(0,g.GRILL_SURFACE_Y+.03,g.GRILL_SURFACE_Z)
 if hosting:
  assert(boss.start())
  for i in 5:boss.advance_phase()
  var before=g.garbage_fill
  h.spawn_local({"id":501,"age":2.0,"heat":.2,"start":pos,"target":pos,"round":boss.generation});h.broadcast()
  while h.hazards.has(501):await process_frame
  assert(g.garbage_fill==before+1)
  mark("host_discarded");await wait_mark("guest_done")
  mark("host_done")
 else:
  mark("guest_ready")
  while not h.hazards.has(501):await process_frame
  h.held_id=501;h.send_command("grab",501,pos)
  while h.hazards.has(501) and int(h.hazards[501].holder)!=net.my_id():await process_frame
  assert(h.hazards.has(501))
  var carry=pos+Vector3(.5,.3,0)
  h.hazards[501].carry=carry;h.send_command("move",501,carry)
  h.update_visual(h.hazards[501]);h.held_id=-1;h.pending_release_id=501
  h.send_command("trash",501,carry)
  while h.hazards.has(501):await process_frame
  assert(h.pending_release_id==-1)
  await wait_mark("host_discarded");mark("guest_done");await wait_mark("host_done")
 print("HOTDOG_DRAG_NETWORK_OK")
 quit()
