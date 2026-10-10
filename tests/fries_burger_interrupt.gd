extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var game = load("res://scenes/main.tscn").instantiate()
	game.set_script(load("res://tests/main_ticket_harness.gd"))
	root.add_child(game); current_scene = game
	var c = load("res://scripts/customer.gd").new()
	c.setup([] as Array[String],Color.WHITE,90.0,0,0,0,-1,{},true)
	game.customers_root.add_child(c); c.set_process(false); c.is_waiting = true
	var food = Node3D.new(); game.add_child(food)
	var side = load("res://scripts/side_food_serve.gd").new(); game.add_child(side); side.set_process(false)
	var calls = []
	side.setup(game,c,food,"fries",func():calls.append(true))
	side._process(.6)
	assert(side.started and c._side_food_pose)
	c.set_meta("burger_in_flight",true)
	side.finish(true)
	c.begin_catch_burger(true)
	assert(not c._side_food_pose and c._burger_eat_phase == "grab" and c._eating)
	side._process(.2); side.finish()
	assert(c._burger_eat_phase == "grab" and c._eating)
	assert(calls.size() == 1 and c.get_meta("side_food_pending") == 0 and not c.get_meta("side_food_active"))
	print("FRIES_BURGER_INTERRUPT_OK: one callback, side pose stopped, burger grab preserved")
	game.queue_free(); await process_frame; quit()
