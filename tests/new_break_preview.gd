extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1280,720)
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/shared_interaction_fixture.gd"));root.add_child(g);current_scene=g
 g._build_challenge_ui();g.challenge_overlay.show()
 await create_timer(1.0).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://output/challenge_new.png")
 g.challenge_overlay.hide()
 var arena=load("res://scripts/pal_ball_break.gd").new();g.add_child(arena);arena.game=g;arena.roster=[{"id":1,"name":"Joe","skin":0},{"id":2,"name":"Pal","skin":1},{"id":3,"name":"Chef","skin":2}];arena.simulation.setup(arena.roster);arena.view=arena.simulation.snapshot();arena._build_view();arena.set_process(false);arena._render(1.0,Vector2.ZERO)
 await create_timer(1.0).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://output/pal_ball_new.png")
 arena.view["phase"]="playing"
 arena.view["players"][1]["jump"]=.3
 arena._render(1.0,Vector2.ZERO)
 await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://output/pal_ball_jump.png")
 arena.finished=true;print("NEW_PREVIEW_OK");quit()
