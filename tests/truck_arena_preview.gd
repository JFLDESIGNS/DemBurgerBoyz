extends SceneTree
func _initialize():call_deferred("run")
func run():
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/shared_interaction_fixture.gd"));root.add_child(g);current_scene=g
 g.playing=true;g._kitchen_ready=true;g.mp_enabled=false
 g._set_phone_app("truck_arena")
 var arena=g._pal_ball_break;arena.set_process(false);arena.simulation.phase="playing"
 arena.simulation.players[1].position=Vector3(-2,0,-8);arena.simulation.players[1].angle=0;arena.simulation.players[1].ammo=3
 arena.view=arena.simulation.snapshot();arena._render(1,Vector2.ZERO)
 for i in 10:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://output/truck_arena_preview.png")
 arena.finish();print("TRUCK_PREVIEW_OK");quit()
