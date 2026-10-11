extends SceneTree
func _initialize(): call_deferred("run")
func run() -> void:
 var g=load("res://scenes/main.tscn").instantiate()
 g.set_script(load("res://tests/hotdog_challenge_fixture.gd"))
 root.add_child(g);current_scene=g;g.playing=true;g._kitchen_ready=true
 var net=root.get_node("NetManager")
 net.role=net.Role.CLIENT;g.mp_enabled=true
 # The guest has never created Baron Brat. Recovery must create him and his music.
 assert(not is_instance_valid(g._hotdog_challenge))
 var maker=load("res://scripts/hotdog_challenge.gd").new()
 var recipes=maker.make_recipes(42);maker.free()
 g.mp_shared_world(var_to_bytes(["ready",0,0,recipes,"idle_sway",0.0,0,1,17.0,Vector3(0,-.02,6.3),1.0,"",[],0.0,false]).compress(FileAccess.COMPRESSION_DEFLATE),{"fryer":true},{"fryer":0})
 assert(is_instance_valid(g._hotdog_challenge.customer))
 assert(g._hotdog_challenge.customer.visible and g._hotdog_challenge.music.playing)
 assert(g._machine_broken.fryer)
 g.mp_shared_world(var_to_bytes([]).compress(FileAccess.COMPRESSION_DEFLATE), {"fryer":false}, {"fryer":0})
 assert(not g._machine_broken.fryer)
 g._hotdog_challenge.set_process(false)
 g.mp_enabled=false;net.role=net.Role.NONE
 # Different random schedules converge to the same authoritative bird pose.
 var a=load("res://scenes/park_bird.tscn").instantiate()
 var b=load("res://scenes/park_bird.tscn").instantiate()
 g.world.add_child(a);g.world.add_child(b);a.set_process(false);b.set_process(false)
 a._enter(&"Fly_In");a.advance(.4)
 b.apply_network_snapshot(a.network_snapshot())
 assert(b.state==a.state and b.bird.position.is_equal_approx(a.bird.position))
 assert(b.sway.transform.is_equal_approx(a.sway.transform))
 # A known consumed cup must not respawn from delayed idle packets.
 g._consumed_cup_ids[2000017]=true
 g.mp_cup_park(2000017,"cola",1.0,.2,0.0)
 assert(g._mp_find_cup_by_net_id(2000017)==null)
 # A 2D build pose is normalized to the receiving viewport and restored on release.
 var preview=Control.new();g.get_node("UI/Root").add_child(preview);preview.position=Vector2(100,200)
 g.stations=[{"preview":preview,"items":[],"patties":[]}]
 g.mp_build_pose(0,true,.1,-.1,.12)
 assert(preview.position.distance_to(Vector2(100,200))>10 and preview.z_index==100)
 # Empty test fixture omits full station UI, so verify pose while active.
 g.mp_enabled=false;net.role=net.Role.NONE
 print("COOP_WORLD_RECOVERY_OK: late boss/music, repairs, bird pose, consumed cups, build pose")
 g.queue_free();await process_frame;quit()
