extends SceneTree
func _initialize():call_deferred("run")
func run():
 create_timer(30).timeout.connect(func():push_error("TRUCK_SOLO_TIMEOUT");quit(1))
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/shared_interaction_fixture.gd"));root.add_child(g);current_scene=g
 g.playing=true;g._kitchen_ready=true;g.mp_enabled=false
 g._set_phone_app("truck_arena");assert(paused and is_instance_valid(g._pal_ball_break))
 var arena=g._pal_ball_break
 assert(arena.actors[1].ammo.size()==3 and arena.actors[-1].ammo.size()==3)
 assert(arena.get_script().resource_path.ends_with("truck_arena.gd"))
 while arena.simulation.phase!="playing":await process_frame
 var shoot:=InputEventKey.new();shoot.pressed=true;shoot.physical_keycode=KEY_E
 arena._input(shoot);assert(arena.burst_queued)
 arena.burst_queued=false
 var jump:=InputEventKey.new();jump.pressed=true;jump.physical_keycode=KEY_SPACE
 arena._input(jump);assert(arena.simulation.players[1].jump_queued and not arena.burst_queued)
 var initial:Vector3=arena.simulation.players[-1].position
 await create_timer(1).timeout
 assert(arena.simulation.players[-1].position.distance_to(initial)>.1)
 arena.simulation.drop_peer(-1)
 while is_instance_valid(g._pal_ball_break):await process_frame
 assert(not paused)
 print("TRUCK_ARENA_SOLO_OK: phone app, bot driving, kitchen resumes");quit()
