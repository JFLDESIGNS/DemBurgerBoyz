extends SceneTree
func _initialize(): call_deferred("run")
func run():
	create_timer(25).timeout.connect(func(): quit(1))
	var g = load("res://scenes/main.tscn").instantiate()
	g.set_script(load("res://tests/main_ticket_harness.gd"))
	root.add_child(g); current_scene = g; g.playing = true
	for child in g.get_node("UI/Root").get_children():
		if child is CanvasItem: child.hide()
	g.get_node("UI/Root/WindowTicketRail").show()
	var a = load("res://scripts/mobile_ticket_owner.gd").new()
	g.add_child(a); a.order.assign(["bun_bottom", "patty", "bun_top"])
	g.selected_customer = a; g._create_ticket(a)
	var b = load("res://scripts/mobile_ticket_owner.gd").new()
	g.add_child(b); b.order.assign(["bun_bottom", "patty", "cheese", "bun_top"])
	b.set_meta("mobile_order", true); g._create_ticket(b)
	var mobile = load("res://scripts/grubbah.gd").new()
	g.add_child(mobile); mobile.game = g; mobile.set_process(false)
	mobile.announce_arrival(b)
	await create_timer(1.0).timeout
	var wrap = g.tickets[b]
	var note = wrap.get_meta("ticket_note")
	print("HELD ARRIVAL ", wrap.visible, " alpha=", wrap.modulate.a, " note=", note.visible, " parent=", note.get_parent().name)
	assert(wrap.visible and wrap.modulate.a > .9 and note.get_parent() == wrap)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/customer_polish_qa/mobile_ticket_hold.png")
	g.selected_customer = b; g._highlight_tickets()
	await process_frame
	g.selected_customer = a; g._highlight_tickets()
	await process_frame
	print("HELD AFTER ACTIVE ", wrap.visible, " alpha=", wrap.modulate.a, " note=", note.visible, " parent=", note.get_parent().name)
	assert(wrap.visible and wrap.modulate.a > .9 and note.get_parent() == wrap)
	print("MOBILE_TICKET_HOLD_OK")
	mobile.ticket_owner = b
	mobile.state = {"phase":"sealed", "number":1, "items":b.order.duplicate()}
	mobile.flying_ticket = Sprite3D.new(); mobile.add_child(mobile.flying_ticket)
	mobile.sync_ticket()
	assert(not g.tickets.has(b), "Completed HUD ticket must be removed immediately")
	assert(is_instance_valid(mobile.ticket_view), "Capture the ticket before removing it")
	assert(mobile.ticket_view.get_child(0).find_child("TicketSeconds", true, false) != null, "Bag must retain the actual printed order, not fallback text")
	await process_frame
	assert(mobile.ticket_view.get_child(0).is_visible_in_tree())
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var captured = mobile.ticket_view.get_texture().get_image()
		captured.save_png("res://build/customer_polish_qa/mobile_bag_ticket.png")
		assert(captured.get_pixel(captured.get_width()/2, captured.get_height()/2).a > .5, "Bag ticket texture must contain visible paper")
	print("MOBILE_BAG_TICKET_OK")
	quit()
