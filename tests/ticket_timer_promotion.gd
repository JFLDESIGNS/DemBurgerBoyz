extends SceneTree
class Customer extends Node3D:
 var order:Array[String]=["bun_bottom","patty","bun_top"]
 var is_waiting=true
 var is_leaving=false
 var is_challenge_guest=false
 var order_elapsed_sec=0.0
 var running=false
 func patience_ratio():return 1.0
 func stop_order_clock():running=false
 func start_order_clock(_reset=false):running=true
 func set_queue_timer_active(_active):pass
func _initialize():call_deferred("run")
func run():
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/main_ticket_harness.gd"));root.add_child(g);current_scene=g
 var first=Customer.new();var next=Customer.new();g.add_child(first);g.add_child(next);g.customers.assign([first,next])
 g._create_ticket(first);g._create_ticket(next);g.selected_customer=first;g._highlight_tickets()
 assert(next.running==false)
 first.is_waiting=false;g._remove_ticket(first);g._refresh_customer_queue_timers()
 assert(g.selected_customer==next and next.running,"Timer activation must promote selection immediately")
 var wrap=g.tickets[next]
 assert(g.ticket_box.get_child(0)==wrap,"Active ticket must move to the main position")
 assert(is_equal_approx(wrap.get_meta("ticket_motion").display_scale,.8),"Active ticket must use full size")
 print("TICKET_TIMER_PROMOTION_OK")
 quit()
