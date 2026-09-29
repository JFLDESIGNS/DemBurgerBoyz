extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var g = load("res://scenes/main.tscn").instantiate()
	g.set_script(load("res://tests/instant_sauce_fixture.gd"))
	root.add_child(g)
	g.playing = true
	g.stations = [{"items": ["bun_bottom", "patty"], "patties": []}]
	g.supply_stock["ketchup"] = 4
	g.supply_stock["mustard"] = 4
	var customer = Node3D.new(); g.add_child(customer)
	var ticket = Control.new(); g.add_child(ticket)
	var lines = VBoxContainer.new(); ticket.add_child(lines)
	ticket.set_meta("lines_box", lines); g.tickets[customer] = ticket
	var labels = {}
	for sauce in ["ketchup", "mustard"]:
		var row = Control.new(); lines.add_child(row); row.set_meta("line_id", sauce)
		var label = load("res://scripts/ticket_ingredient_label.gd").new()
		label.name = "Item"; row.add_child(label); labels[sauce] = label
		g._request_condiment_add(sauce, 0)
		assert(label.completed, "Ticket must cross off sauce before any animation frame")
		assert(g.stations[0].items.has(sauce) and g.supply_stock[sauce] == 3)
		g._request_condiment_add(sauce, 0)
		assert(g.supply_stock[sauce] == 3, "Duplicate click must not spend stock twice")
	assert(g.pours.size() == 2)
	var previous_pour = g.pours[0]
	g.stations[0].items = ["bun_bottom", "patty"]
	g._refresh_ticket_checkmarks()
	g._deposit_condiment_entry(previous_pour)
	assert(not labels.ketchup.completed and not g.stations[0].items.has("ketchup"), "Old animation must not add sauce to the next burger")
	g._request_condiment_add("ketchup", 0)
	assert(labels.ketchup.completed and g.supply_stock.ketchup == 2, "Returning bottle must not delay the next accepted click")
	g.stations[0].items = []; g._refresh_ticket_checkmarks()
	g._request_condiment_add("mustard", 0)
	assert(not labels.mustard.completed and g.supply_stock.mustard == 3, "No patty must reject sauce")
	g.stations[0].items = ["patty"]; g.supply_stock.mustard = 0
	g._request_condiment_add("mustard", 0)
	assert(not labels.mustard.completed and not g.stations[0].items.has("mustard"), "Out-of-stock sauce must not cross off")
	g.queue_free(); await process_frame
	print("INSTANT_SAUCE_OK: immediate checkmarks, independent bottles, stock, duplicates, next burger, rejected clicks")
	quit()
