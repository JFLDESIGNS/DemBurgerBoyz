extends SceneTree
class GripProbe extends Node3D:
 func burger_grip_edges() -> Array[Vector3]:return [global_position-global_basis.x*.15,global_position+global_basis.x*.15]
class Eater extends Node3D:
 var order: Array[String] = ["bun_bottom","patty","bun_top","soda_cola"]
 var is_waiting := true
 var is_leaving := false
 var is_challenge_guest := false
 func mouth_global() -> Vector3: return global_position+Vector3(0,1.4,0)
 func begin_side_food(): pass
 func pose_side_food(_lift: float,_drink: bool): pass
 func finish_catch_burger(): pass
func _initialize():call_deferred("run")
func run():
 create_timer(45).timeout.connect(func():push_error("MP_VISUAL_OWNERSHIP_TIMEOUT");quit(1))
 var g=load("res://scenes/main.tscn").instantiate()
 g.set_script(load("res://tests/main_ticket_harness.gd"));root.add_child(g);current_scene=g
 # Recap transport must fit even after a day of large burger photographs.
 var photo:=PackedByteArray();photo.resize(3000000);photo.fill(127)
 g.order_history=[{"number":1,"photo":photo,"profit":25}]
 var closed:Dictionary=g._mp_closed_shift_state()
 assert(not closed.orders[0].has("photo"))
 assert(var_to_bytes(closed).size()<60000)
 assert(g.order_history[0].photo.size()==3000000,"Keep local review photos")
 # Network packets cannot rewind a locally owned eating clip.
 var c=load("res://scripts/customer.gd").new();g.add_child(c);c.set_process(false)
 var ap=AnimationPlayer.new();c.add_child(ap);c._anim_player=ap
 var lib=AnimationLibrary.new();var clip=Animation.new();clip.length=3.0;lib.add_animation("eat",clip);ap.add_animation_library("probe",lib)
 ap.play("probe/eat");ap.seek(1.7,true);c._eating=true
 c.apply_presentation_snapshot({"clip":"probe/eat","position":.1,"speed":1.0})
 assert(is_equal_approx(ap.current_animation_position,1.7),"Eating rewound by host snapshot")
 c._eating=false;c._burger_eat_phase="";c._cat_pet_left=0
 c.apply_presentation_snapshot({"clip":"probe/eat","position":.1,"speed":1.0})
 assert(is_equal_approx(ap.current_animation_position,1.7),"Repeated clip snapshots must not rewind")
 # Billboard burgers retain their size when the customer turns sideways.
 var grip=GripProbe.new();g.add_child(grip);grip.position=Vector3(0,1.4,0)
 g.camera.position=Vector3(0,1.4,-3);g.camera.look_at(grip.global_position)
 var facing:float=g._customer_burger_hand_scale(grip,200)
 grip.rotation.y=PI*.5
 assert(is_equal_approx(facing,g._customer_burger_hand_scale(grip,200)),"Customer turn squashed the burger")
 # Buffered truck and camera heading interpolate through wrapped yaw.
 var arena=load("res://scripts/truck_arena.gd").new();arena.set_process(false)
 var state={"phase":"playing","players":{1:{"position":Vector3.ZERO,"angle":3.1,"travel":0.0,"alive":true}},"shots":[{"id":1,"position":Vector3.ZERO}]}
 var next=state.duplicate(true);next.players[1].position=Vector3(2,0,0);next.players[1].angle=-3.1;next.players[1].travel=2.0;next.shots[0].position=Vector3(4,0,0)
 arena.remote_frames=[{"time":1000,"state":state},{"time":1100,"state":next}]
 var sampled:Dictionary=arena._sample_remote_view(1150)
 assert(sampled.players[1].position.is_equal_approx(Vector3(1,0,0)))
 assert(absf(float(sampled.players[1].angle))>3.0)
 assert(sampled.shots[0].position.is_equal_approx(Vector3(2,0,0)))
 arena.free()
 # Early drink stays interruptible while consuming exactly its own cup.
 var eater=Eater.new();g.add_child(eater)
 var cup=g._create_drink_cup_node();g.world.add_child(cup);cup.set_meta("flavor","cola")
 var callbacks=[0]
 g._play_cup_fly_to_mouth(eater,func():callbacks[0]+=1;g._consume_cup_for_serve(eater),false,cup)
 assert(not g._serve_fly_busy,"Drinking must not lock burger serving")
 await process_frame
 eater.set_meta("burger_in_flight",true)
 g._serve_fly_busy=true
 var original=cup
 var unrelated=g._create_drink_cup_node();g.world.add_child(unrelated);g._serve_cup_node=unrelated
 for side in get_nodes_in_group("side_food_presentations"):
  if side.customer==eater:side.finish(true)
 assert(callbacks[0]==1 and g._serve_fly_busy,"Drink completion must not unlock an active burger")
 assert(original.is_queued_for_deletion() and not unrelated.is_queued_for_deletion(),"Concurrent drink consumed the wrong cup")
 print("MP_VISUAL_OWNERSHIP_OK: recap size, animation continuity, arena buffer, early drink interruption and ownership")
 quit()
