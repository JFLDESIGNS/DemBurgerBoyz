extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://scenes/main.tscn").instantiate();game.set_script(load("res://tests/main_ticket_harness.gd"));root.add_child(game);current_scene=game
 game.playing=true;game.day=1;game._kitchen_ready=true;game._boss_intro_running=false;game._bts_day_intro_active=false
 var coach=load("res://scripts/day_one_burger_coach.gd").new();game.add_child(coach);coach.set_process(false)
 coach._process(8.5)
 assert(coach.built and coach.panel.visible)
 for i in 60:coach._process(1.0/60.0);await process_frame
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://output/burger_coach_preview.png")
 game.shift_paused=true;coach._process(.1);assert(not coach.panel.visible)
 game.shift_paused=false;game.day=2;coach._process(.1);assert(not coach.panel.visible)
 print("BURGER_COACH_OK");quit()
