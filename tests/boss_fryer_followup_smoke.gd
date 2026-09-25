extends SceneTree
func _initialize(): call_deferred("run")
func run():
 var game=load("res://scenes/main.tscn").instantiate()
 game.set_script(load("res://tests/main_ticket_harness.gd"))
 root.add_child(game)
 current_scene=game
 game.playing=true
 game._record_boss_served_customer()
 game._record_boss_served_customer()
 assert(not game._boss_fryer_pending)
 game._record_boss_served_customer()
 assert(game._boss_fryer_pending and game._boss_pep_pending)
 game._boss_fryer_pending=false
 game._boss_pep_pending=false
 game._record_boss_served_customer()
 assert(not game._boss_fryer_pending)
 game.tutorial_mode=true
 var before=game._boss_fryer_served
 game._record_boss_served_customer()
 assert(game._boss_fryer_served==before)
 assert(game.BOSS_MORNING_PEPS.size()==3)
 assert(game.BOSS_MORNING_PEPS[0]!=game.BOSS_MORNING_PEPS[1])
 assert(game.BOSS_MORNING_PEPS[1]!=game.BOSS_MORNING_PEPS[2])
 assert(game.BOSS_FRYER_ADVICE.split("\n").size()==2)
 game.flash_label.text=game.BOSS_FRYER_ADVICE
 game._layout_flash_label()
 await process_frame
 assert(game.flash_label.size.x<=root.get_visible_rect().size.x)
 print("BOSS_THIRD_CUSTOMER_FOLLOWUP_OK")
 quit()
