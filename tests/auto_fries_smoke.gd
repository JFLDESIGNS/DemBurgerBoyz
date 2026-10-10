extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/auto_fries_fixture.gd"));root.add_child(g);current_scene=g;g.playing=true
	var orders=[["bun_bottom","patty","bun_top","fries"],["fries"],["bun_bottom","patty","bun_top","fries"]]
	for i in orders.size():
		var c=load("res://scripts/mobile_ticket_owner.gd").new();g.add_child(c);c.order.assign(orders[i]);c.is_waiting=true;c.set_meta("mp_net_id",9100+i);g.customers.append(c)
	g.selected_customer=g.customers[2]
	g.fryer_ready_servings=2;g._auto_serve_ready_fries()
	assert(g._customer_fries_handed(g.customers[2]) and g._customer_fries_handed(g.customers[0]))
	assert(not g._customer_fries_handed(g.customers[1]) and g.fryer_ready_servings==0)
	assert(g.side_visuals==["fries","fries"])
	g._auto_serve_ready_fries();assert(g.side_visuals.size()==2,"No duplicate flights")
	g._add_ready_fries_local(2);await process_frame
	assert(g._serve_fly_busy and g.fryer_ready_servings==1 and g.served.is_empty(),"Reserve before fries flight finishes")
	g._serve_fly_busy=false;g.pending_completion.call()
	assert(g.served==[["fries_only",9101]] and g.fryer_ready_servings==1,"Serve fries-only ticket; keep surplus")
	g.customers[0].remove_meta("fries_handed");g._mark_customer_fries_handed(g.customers[0],false)
	g.mp_enabled=true;g._auto_serve_ready_fries();assert(g.fryer_ready_servings==1,"Guests do not auto-consume shared fries")
	g.mp_enabled=false
	print("AUTO_FRIES_OK: selected order, queue, fries-only, surplus, no duplicates, guest authority");quit()
