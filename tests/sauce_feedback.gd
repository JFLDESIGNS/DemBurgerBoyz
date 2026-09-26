extends SceneTree
func _initialize():call_deferred("run")
func run():
 var c=load("res://scripts/customer.gd").new()
 c.setup(["bun_bottom","patty","bun_top"] as Array[String],Color("E8AC6F"),9999,0,2)
 root.add_child(c);c.set_process(false);c.set_physics_process(false)
 c.receive_sauce("ketchup",preload("res://scripts/food_impact.gd").sauce_drip_texture(),Color("BF261B"),"body")
 assert(c._stuck_food_items.size()==4)
 var drip=c._stuck_food_items[1]
 var before=drip.global_position.y
 await create_timer(3.1).timeout
 assert(drip.size.z>.18)
 assert(drip.global_position.y<before)
 print("SAUCE_DECAL_DRIPS_OK")
 quit()
