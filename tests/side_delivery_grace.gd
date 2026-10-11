extends SceneTree
class Customer extends Node3D:
 var order: Array = ["bun_bottom","patty","bun_top","soda_cola","fries"]
func _initialize():call_deferred("run")
func run():
 create_timer(15).timeout.connect(func():quit(1))
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/main_ticket_harness.gd"));root.add_child(g);g.playing=true
 var c=Customer.new();g.add_child(c)
 var start=Time.get_ticks_msec()
 create_timer(.3).timeout.connect(func():assert(not g._serve_fly_busy,"Late sides must not be blocked by the burger flight lock");g._mark_customer_soda_handed(c,true);g._mark_customer_fries_handed(c,true))
 await g._wait_for_side_delivery(c)
 print("EARLY_GRACE_MS ",Time.get_ticks_msec()-start," missing=",g._missing_delivered_sides(c))
 assert(Time.get_ticks_msec()-start<1000)
 assert(g._missing_delivered_sides(c).is_empty())
 g._mark_customer_fries_handed(c,false)
 c.set_meta("burger_in_flight",true);c.set_meta("burger_arrival_deadline",Time.get_ticks_msec()+2000)
 create_timer(.25).timeout.connect(func():c.set_meta("burger_received_ms",Time.get_ticks_msec()))
 start=Time.get_ticks_msec()
 await g._wait_for_side_delivery(c)
 assert(Time.get_ticks_msec()-int(c.get_meta("burger_received_ms"))>=5000 and Time.get_ticks_msec()-start<6000)
 assert(g._missing_delivered_sides(c)==["fries"])
 print("SIDE_DELIVERY_GRACE_OK: accepts late sides and waits five seconds before a missing-side result")
 g.queue_free();await process_frame;quit()
