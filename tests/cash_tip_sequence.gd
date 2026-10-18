extends SceneTree
func _initialize():call_deferred("run")
func run():
 create_timer(20).timeout.connect(func():quit(1))
 var game=load("res://scenes/main.tscn").instantiate();game.set_script(load("res://tests/delivery_network_fixture.gd"));root.add_child(game);current_scene=game
 game._build_tip_jar(game.world)
 var actor=load("res://scripts/customer.gd").new()
 var recipe:Array[String]=["bun_bottom","patty","bun_top"]
 actor.setup(recipe,Color.WHITE,90,0);game.add_child(actor);actor.set_process(false)
 actor.set_meta("cash_payment_amount",24);actor.set_meta("cash_tip_amount",8)
 preload("res://scripts/customer_cash_sequence.gd").play(game,actor,false)
 await create_timer(.8).timeout
 assert(actor.get_meta("cash_released",false))
 assert(game._payment_bill_active.is_empty(),"Tip must wait for the second throw")
 await create_timer(.65).timeout
 assert(actor.get_meta("cash_sequence_playing",false),"Second payment gesture must still be playing")
 assert(actor._burger_props.visible,"Second throw visibly holds bills before release")
 await create_timer(.5).timeout
 assert(game._payment_bill_active.size()==2,"Eight dollar tip releases two 3D bills")
 for i in 90:game._update_payment_bills(1.0/60.0)
 assert(game._tip_jar_bill_count==2,"Tip bills remain inside the jar")
 await create_timer(.5).timeout
 assert(not actor.get_meta("cash_sequence_playing",false))
 print("CASH_TWO_THROWS_AND_3D_TIPS_OK")
 quit()
