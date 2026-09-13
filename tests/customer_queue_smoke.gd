extends SceneTree
const Customer = preload("res://scripts/customer.gd")
var failures: Array[String] = []
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	create_timer(60).timeout.connect(func():push_error("CUSTOMER_QUEUE_TIMEOUT");quit(1))
	var game = load("res://scenes/main.tscn").instantiate()
	game.set_script(load(get_script().resource_path.get_base_dir().path_join("main_ticket_harness.gd")))
	root.add_child(game)
	current_scene = game
	game.set_process_input(false)
	for i in 3:
		game._spawn_customer_local(["bun_bottom","patty","bun_top"],Color.WHITE,45.0,i,-1,0,0,false,-1,false,{},true)
		var c = game.customers.back()
		c.set_process(false)
		c.global_position.x = c.target_x
		c.is_waiting = true
		game._create_ticket(c)
	var first = game.customers[0]
	var second = game.customers[1]
	var third = game.customers[2]
	game.selected_customer = first
	game._highlight_tickets()
	expect(is_equal_approx(first.target_x-second.target_x,0.95),"Customers need wider spacing")
	var second_slot: float = second.target_x
	var third_slot: float = third.target_x
	game._begin_customer_serve_handoff(first)
	expect(not second.queue_timer_active and not second._order_clock_on,"Next order must not start during the burger handoff")
	game.selected_customer = second
	game._highlight_tickets()
	var next_wrap: Control = game.tickets[second]
	if next_wrap.has_meta("ticket_motion"):
		expect(not next_wrap.get_meta("ticket_motion").active,"Next ticket must stay static while the counter is occupied")
	game.playing = true
	for tap in 3: game._register_grill_dance_tap()
	var dancers := 0
	for c in [second,third]:
		var life: Node = c.get_node_or_null("CustomerLife")
		if life != null and life.dance_left > 0.0: dancers += 1
	expect(dancers > 0,"Three grill taps should invite at least one waiting customer to dance")
	game.playing = false
	first._eating = true
	game._customer_leave_apply(first,false)
	game._update_customer_departure_holds()
	expect(is_equal_approx(second.target_x,second_slot),"Next customer must wait while previous customer eats")
	expect(not second.queue_timer_active,"A customer blocked by a departure must not lose patience")
	game._reposition_customers()
	expect(is_equal_approx(third.target_x,third_slot),"Repeated queue reflows must preserve the held line")
	game._spawn_customer_local(["bun_bottom","patty","bun_top"],Color.WHITE,45.0,2,-1,0,0,false,-1,false,{},true)
	var fourth = game.customers.back()
	fourth.set_process(false)
	expect(is_equal_approx(third_slot-fourth.target_x,0.95),"New arrivals must stand behind the held queue")
	first._begin_sidewalk_leave(false)
	first._update_sidewalk_leave(0.01)
	game._update_customer_departure_holds()
	expect(is_equal_approx(second.target_x,second_slot),"Turning in place must not release the queue")
	var start_x: float = first.global_position.x
	for frame in 600:
		first._update_sidewalk_leave(1.0/60.0)
		game._update_customer_departure_holds()
		if first.global_position.x < start_x+Customer.QUEUE_SPACING:
			expect(is_equal_approx(second.target_x,second_slot),"Queue moved before departing customer cleared the spot")
		else:
			break
	expect(first.global_position.x>=start_x+Customer.QUEUE_SPACING,"Departure must actually walk clear")
	expect(is_equal_approx(second.target_x,Customer.lane_x_for(0)),"Next customer must advance once the spot is clear")
	expect(is_equal_approx(third.target_x-fourth.target_x,0.95),"Advancing must preserve spacing")
	expect(second.queue_timer_active,"Front order clock must resume after departure")
	# A departing customer removed by scene/network cleanup must never deadlock the line.
	game._customer_leave_apply(second,false)
	second.free()
	game._update_customer_departure_holds()
	expect(is_equal_approx(third.target_x,Customer.lane_x_for(0)),"Freed departure must release its reserved spot")
	expect(Customer.lane_x_for(5)<Customer.lane_x_for(4),"Overflow arrivals must not share a clamped lane")
	print("CUSTOMER_QUEUE_OK" if failures.is_empty() else "CUSTOMER_QUEUE_FAILED: "+str(failures))
	game.queue_free()
	for frame in 3: await process_frame
	quit(0 if failures.is_empty() else 1)
