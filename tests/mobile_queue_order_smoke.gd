extends SceneTree
func _initialize():call_deferred("run")
func run():
	var g=load("res://scenes/main.tscn").instantiate()
	g.set_script(load("res://tests/mobile_queue_fixture.gd"))
	root.add_child(g);current_scene=g;g.playing=true
	var owners=[]
	for i in 3:
		var c=load("res://scripts/mobile_ticket_owner.gd").new()
		g.add_child(c);c.is_waiting=true;c.order.assign(["bun_bottom","patty","bun_top"])
		if i==1:c.set_meta("mobile_order",true)
		else:g.customers.append(c)
		if i==0:g.selected_customer=c
		g._create_ticket(c);owners.append(c)
	var mobile=owners[1]
	var wrap=g.tickets[mobile]
	var original_index=wrap.get_index()
	assert(original_index>0)
	g._select_ticket_local(mobile,false)
	for i in 3:g._highlight_tickets()
	assert(wrap.get_index()==original_index,"Automatic mobile activation must not jump older orders")
	g._select_ticket_local(mobile,true)
	assert(wrap.get_index()==0,"Explicit click may promote the mobile order")
	g._select_ticket_local(owners[0]);g._highlight_tickets()
	assert(wrap.get_index()==1,"Selecting another order does not keep forcing mobile to the front")
	print("MOBILE_QUEUE_ORDER_OK")
	g.queue_free();await process_frame;quit()
