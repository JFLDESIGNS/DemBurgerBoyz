extends SceneTree
func _initialize():call_deferred("run")
func run():
 create_timer(25).timeout.connect(func():quit(1))
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/shared_interaction_fixture.gd"));root.add_child(g);current_scene=g
 g.playing=true;g._kitchen_ready=true;g.mp_enabled=false;g.day_time=g._shift_length()*.5
 assert(g._maybe_start_pal_ball_break());assert(paused)
 var match_node=g._pal_ball_break
 assert(match_node.simulation.players.has(-1))
 while match_node.simulation.phase!="playing":await process_frame
 var initial:Vector2=match_node.simulation.players[-1].position
 await create_timer(.5).timeout
 assert(match_node.simulation.players[-1].position.distance_to(initial)>.1)
 match_node.simulation.players[-1].position=Vector2(20,0)
 while match_node.simulation.phase!="results":await process_frame
 assert(match_node.simulation.scores[1]==1 and not match_node.simulation.match_complete)
 while match_node.simulation.phase!="playing":await process_frame
 assert(match_node.simulation.round_number==2)
 match_node.simulation.players[-1].position=Vector2(20,0)
 while is_instance_valid(g._pal_ball_break):await process_frame
 assert(not paused);assert(not g._maybe_start_pal_ball_break())
 g._set_phone_app("rolly");assert(is_instance_valid(g._pal_ball_break) and paused)
 g._pal_ball_break.finish();await process_frame
 assert(not paused)
 print("PAL_BALL_SOLO_OK: bot moves, match resolves, kitchen resumes");quit()
