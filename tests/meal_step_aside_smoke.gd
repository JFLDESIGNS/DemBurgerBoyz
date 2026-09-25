extends SceneTree
func _initialize():call_deferred("run")
func run():
 create_timer(20).timeout.connect(func():quit(1))
 var game=load("res://scenes/main.tscn").instantiate()
 game.set_script(load("res://tests/main_ticket_harness.gd"))
 root.add_child(game);current_scene=game
 var Customer=load("res://scripts/customer.gd")
 var first=Customer.new()
 var next=Customer.new()
 var order:Array[String]=["bun_bottom","patty","bun_top"]
 for c in [first,next]:
  c.setup(order,Color.WHITE,45.,0,0,0,-1,{},true)
  game.add_child(c)
  c.set_process(false)
  c.is_waiting=true
  game.customers.append(c)
  game._create_ticket(c)
 first.global_position.x=Customer.lane_x_for(0)
 next.global_position.x=Customer.lane_x_for(1)
 game.selected_customer=first
 game._begin_customer_serve_handoff(first)
 assert(not game.tickets.has(first) and game.tickets.has(next))
 assert(game.selected_customer==next,"Next ticket must become active immediately")
 assert(is_equal_approx(next.target_x,Customer.lane_x_for(0)),"Next guest must advance before eating finishes")
 assert(game._customer_departure_holds.is_empty())
 assert(first.get_meta("meal_stepping_aside"))
 await create_timer(.75).timeout
 assert(not first.get_meta("meal_stepping_aside"))
 assert(first.global_position.x>Customer.lane_x_for(0)+Customer.QUEUE_SPACING)
 game._hold_customer_departure(first)
 assert(game._customer_departure_holds.is_empty(),"Eating guest must not hold the line on departure")
 print("MEAL_STEP_ASIDE_QUEUE_OK")
 quit()
