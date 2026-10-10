extends SceneTree

func _initialize(): call_deferred("run")

func run():
	var g = load("res://scenes/main.tscn").instantiate()
	g.set_script(load("res://tests/side_sync_fixture.gd"))
	root.add_child(g)
	current_scene = g
	g.playing = true
	var c = load("res://scripts/mobile_ticket_owner.gd").new()
	g.add_child(c)
	c.order.assign(["bun_bottom", "patty", "bun_top", "soda_cola"])
	c.is_waiting = true
	c.set_meta("mp_net_id", 9201)
	g.customers.append(c)
	g.selected_customer = c
	g.cup_root = Node3D.new()
	g.add_child(g.cup_root)
	g.cup_flavor = "cola"
	g.cup_soda_fill = 1.0
	g._stop_completed_soda_fill()
	g._serve_fly_busy = true
	g._try_auto_hand_finished_soda()
	assert(g.served.is_empty(), "Wait while another food is flying")
	g._serve_fly_busy = false
	g._mp_pending_cup_hand = 123
	g._try_auto_hand_finished_soda()
	assert(g.served.is_empty(), "Do not resubmit a guest handoff awaiting acknowledgment")
	g._mp_pending_cup_hand = 0
	c.set_meta("serve_in_progress", true)
	g._try_auto_hand_finished_soda()
	assert(g.served.is_empty(), "Skip an order already being served")
	c.set_meta("serve_in_progress", false)
	c.is_waiting = false
	g._try_auto_hand_finished_soda()
	assert(g.served.is_empty(), "Keep the drink until a customer is ready")
	c.is_waiting = true
	g._try_auto_hand_finished_soda()
	assert(g.served == [["cola", 9201]], "Retry delivers after the pour has stopped")
	g._try_auto_hand_finished_soda()
	assert(g.served.size() == 1, "Never send a second drink to the same order")
	print("AUTO_SODA_OK: busy retry, stopped nozzle, arriving customer, in-progress order, pending guest, no duplicates")
	quit()
