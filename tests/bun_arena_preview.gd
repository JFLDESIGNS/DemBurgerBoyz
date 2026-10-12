extends SceneTree
func _initialize():call_deferred("run")
func run():
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/shared_interaction_fixture.gd"));root.add_child(g);current_scene=g
 g.playing=true;g._kitchen_ready=true;g.mp_enabled=false;g.day=1;g.day_time=g._shift_length()*.5
 assert(g._maybe_start_pal_ball_break())
 await create_timer(2).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://output/bun_arena.png")
 g._pal_ball_break.finish();await process_frame
 g.day=2;assert(g._maybe_start_pal_ball_break())
 assert(g._pal_ball_break.get_script()==load("res://scripts/truck_arena.gd"))
 g._pal_ball_break.finish();await process_frame
 print("BUN_AND_MIDDAY_ROTATION_OK");quit()
