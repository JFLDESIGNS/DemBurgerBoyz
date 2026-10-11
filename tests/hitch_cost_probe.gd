extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var game=load("res://scenes/main.tscn").instantiate()
	game.set_script(load("res://tests/main_ticket_harness.gd"))
	root.add_child(game);current_scene=game
	for i in 3:
		var began=Time.get_ticks_usec()
		var cup=game._create_drink_cup_node()
		game.add_child(cup)
		print("PROFILE cup_",i,"_ms=",(Time.get_ticks_usec()-began)/1000.0)
		cup.queue_free();await process_frame
	var preset=game.CustomerScript.take_next_saved_character_preset()
	for i in 3:
		var customer=load("res://tests/hitch_character_profile.gd").new()
		var order: Array[String]=["bun_bottom","patty","bun_top"]
		customer.setup(order,Color.WHITE,45,0,-1,0,-1,preset,true)
		var began=Time.get_ticks_usec()
		game.add_child(customer)
		print("PROFILE customer_",i,"_ms=",(Time.get_ticks_usec()-began)/1000.0)
		print("PROFILE stages=",customer.construction_costs)
		if i==2:
			var source=game._create_drink_cup_node();game.add_child(source)
			game._start_side_food_3d(customer,"drink",Vector3.ZERO,func():pass,"cola",0.0,false,source)
		customer.queue_free();await process_frame
	print("HITCH_COST_PROBE_OK")
	game.queue_free();await process_frame;quit()
