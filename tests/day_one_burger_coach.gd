extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://scenes/main.tscn").instantiate();game.set_script(load("res://tests/main_ticket_harness.gd"));root.add_child(game);current_scene=game
 game.playing=true;game.day=1;game._kitchen_ready=true;game._boss_intro_running=false;game._bts_day_intro_active=false
 var coach=load("res://scripts/day_one_burger_coach.gd").new();game.add_child(coach);coach.set_process(false)
 var customer=load("res://scripts/customer.gd").new();customer.is_waiting=true;customer.order.assign(["bun_bottom","patty","lettuce","bun_top"]);game.customers.append(customer)
 game.grill_on=false
 assert(coach.choose_tip().id=="heat")
 game.grill_on=true
 assert(coach.choose_tip().id=="place")
 game.stations=[{"items":["bun_bottom","patty"]}]
 assert(coach.choose_tip().id=="add_lettuce")
 game.stations[0].items.append("lettuce")
 assert(coach.choose_tip().id=="bun")
 game.stations[0].items.append("bun_top")
 assert(coach.choose_tip().id=="serve")
 game.grill_on_fire=true
 assert(coach.choose_tip().id=="fire")
 game.grill_on_fire=false
 coach._process(8.5)
 assert(coach.built and coach.panel.visible)
 var animation_start=coach.player.current_animation_position
 for i in 60:coach._process(1.0/60.0);await process_frame
 assert(coach.player.current_animation_position!=animation_start,"Coach animation must advance")
 assert(coach.actor.rotation.y>0.3,"Coach turns toward the speech bubble")
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://output/burger_coach_preview.png")
 game.shift_paused=true;coach._process(.1);assert(not coach.panel.visible)
 game.shift_paused=false;game.day=2;coach._process(.1);assert(not coach.panel.visible)
 print("BURGER_COACH_OK");customer.free();quit()
