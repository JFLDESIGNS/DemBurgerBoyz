extends SceneTree
func _initialize():call_deferred("run")
func run():
 create_timer(30).timeout.connect(func():quit(1))
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/delivery_network_fixture.gd"));root.add_child(g);current_scene=g
 var diners=[]
 for i in 2:
  var c=load("res://scripts/customer.gd").new()
  var order: Array[String]=["bun_bottom","patty","bun_top"]
  c.setup(order,Color.WHITE,90,i)
  g.add_child(c);c.set_process(false);g.customers.append(c);diners.append(c)
  g._step_customer_aside_for_meal(c)
 assert(diners[0].get_meta("meal_queue_slot")==0)
 assert(diners[1].get_meta("meal_queue_slot")==1)
 assert(diners[1]._wait_z()>diners[0]._wait_z())
 await create_timer(1.5).timeout
 # The game removes served customers from its order list before their meal ends.
 g.customers.erase(diners[0]);diners[0]._eating=true;diners[0].is_leaving=true
 g._update_meal_queue()
 assert(diners[1].get_meta("meal_queue_slot")==1,"Eating customer must retain the spot after ticket removal")
 diners[0]._eating=false;g._update_meal_queue()
 assert(diners[1].get_meta("meal_queue_slot")==1,"Review/turn in place must retain the spot")
 diners[0].global_position.x+=3
 g._update_meal_queue()
 assert(diners[1].get_meta("meal_queue_slot")==0,"Advance only after predecessor has physically left")
 print("MEAL_QUEUE_RESERVATION_OK")
 quit()
