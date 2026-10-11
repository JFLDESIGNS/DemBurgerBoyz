extends SceneTree
func _initialize():call_deferred("run")
func run():
 create_timer(240).timeout.connect(func():push_error("PET_GAME_TIMEOUT");quit(1))
 root.size=Vector2i(1280,720)
 var g=load("res://scenes/main.tscn").instantiate();root.add_child(g);current_scene=g
 while not g.menu_ready:await process_frame
 await g._start_game()
 g._clear_bts_day_intro(false);g._bts_day1_performance_done=true;g._boss_intro_running=false;g.spawn_timer=99999
 g.owned_machines[g.SHOP_ICECREAM_MACHINE]=true;g.supply_stock.milk=1;g.supply_stock.potato=3;g._refresh_freezer_potatoes();g.pending_machine_deliveries.erase(g.SHOP_ICECREAM_MACHINE)
 g._apply_machine_unlock_visibility()
 g._phone_expanded=false;g.options_menu_open=false;g.shift_paused=false
 var milk=g._milk_refill
 assert(is_instance_valid(milk))
 g._toggle_patty_fridge()
 await create_timer(.6).timeout
 assert(milk.carton.visible)
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://output/milk_freezer_ingame.png")
 var screen=g.camera.unproject_position(milk.carton.global_position+Vector3(0,.1,0))
 var press=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.position=screen
 assert(milk.handle_input(press));press=press.duplicate();press.pressed=false;assert(milk.handle_input(press))
 assert(g.icecream_mix_servings==6 and g.milk_carton_refills==3 and g.supply_stock.milk==0)
 await create_timer(1.1).timeout
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://output/milk_refill_ingame.png")
 await create_timer(1.5).timeout
 g.icecream_mix_servings=0
 var phase:float=g.icecream_mascot_spin_phase;g._update_icecream_mascot_spin(.2);assert(g.icecream_mascot_spin_phase==phase)
 screen=g.camera.unproject_position(milk.carton.global_position+Vector3(0,.1,0));press.position=screen;press.pressed=true
 assert(milk.handle_input(press));milk.held=true
 press=press.duplicate();press.pressed=false;press.position=g.camera.unproject_position(g.icecream_root.global_position+Vector3(0,.42,0))
 assert(milk.handle_input(press));assert(g.icecream_mix_servings==6 and g.milk_carton_refills==2)
 g._update_icecream_mascot_spin(.2);assert(g.icecream_mascot_spin_phase!=phase)
 print("PET_GAME_OK: actual freezer carton, click flight, drag refill, four-charge accounting, empty topper pause")
 quit()
