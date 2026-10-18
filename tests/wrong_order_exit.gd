extends SceneTree
func _initialize():call_deferred("run")
func run():
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/main_ticket_harness.gd"));root.add_child(g);current_scene=g
 var c=load("res://scripts/customer.gd").new()
 var order:Array[String]=["bun_bottom","patty","bun_top"]
 var line=Node3D.new();g.add_child(line)
 c.setup(order,Color.WHITE,90,0);line.add_child(c);c.set_process(false)
 c.set_meta("wrong_order_exit",true)
 g._request_truck_smack(c)
 assert(not c.get_meta("truck_smack_busy",false) and not c.has_meta("truck_smack_cooldown"))
 c.react_wrong()
 assert(c.is_leaving and c._angry_departure)
 c._leave_phase="walk_off"
 var x=c.global_position.x
 for i in 30:c._update_sidewalk_leave(1.0/60.0)
 assert(c.global_position.x>x,"Positive world X is camera-left")
 assert(not c._say_departure_thanks())
 assert(is_equal_approx(g._roomba_home_target().y,g.roomba_home_pos.y-.0254))
 assert(is_equal_approx(g.ROOMBA_SIT_Y,.0456))
 print("WRONG_ORDER_LEFT_EXIT_AND_ROBOT_HEIGHT_OK")
 quit()
