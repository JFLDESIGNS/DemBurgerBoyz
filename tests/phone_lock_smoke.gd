extends SceneTree
func _initialize(): call_deferred("run")
func run():
 var game=load("res://scenes/main.tscn").instantiate()
 game.set_script(load("res://tests/main_ticket_harness.gd"))
 root.add_child(game)
 current_scene=game
 game._build_phone_ui()
 game._build_hud_chrome_toggle()
 game._set_phone_in_truck(true)
 game._layout_phone_ui_overlay()
 await process_frame
 assert(game._phone_lock_screen.visible)
 assert(is_equal_approx(game.phone_column.scale.x,game.PHONE_UI_SCALE*.5))
 game._phone_lock_screen.pressed.emit()
 await create_timer(.35).timeout
 assert(not game._phone_lock_screen.visible)
 assert(is_equal_approx(game.phone_column.scale.x,game.PHONE_UI_SCALE))
 game._toggle_hud_chrome_collapsed()
 await create_timer(.35).timeout
 assert(game._phone_lock_screen.visible)
 assert(game.phone_column.visible)
 assert(is_equal_approx(game.phone_column.scale.x,game.PHONE_UI_SCALE*.5))
 print("PHONE_LOCK_EXPAND_RELOCK_OK")
 quit()
