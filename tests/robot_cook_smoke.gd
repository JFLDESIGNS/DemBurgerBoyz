extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var g = load("res://scenes/main.tscn").instantiate()
	g.set_script(load("res://tests/robot_cook_fixture.gd"))
	root.add_child(g)
	current_scene = g
	g.playing = true
	g.grill_roomba_root = Node3D.new()
	g.add_child(g.grill_roomba_root)
	g.grill_roomba_root.position = Vector3(g.GRILL_CENTER_X, g.GRILL_SURFACE_Y + g.ROOMBA_SIT_Y, g.GRILL_SURFACE_Z)
	var customer = load("res://scripts/customer.gd").new()
	customer.set_script(load("res://scripts/customer.gd"))
	customer.order.assign(["bun_bottom", "patty", "tomato", "ketchup", "bun_top"])
	customer.is_waiting = true
	g.selected_customer = customer
	g.stations = [{"items": ["bun_bottom", "patty", "bun_top"], "patties": []}]
	g.supply_stock = {"tomato": 2, "ketchup": 2}
	var cook = load("res://scripts/robot_cook.gd").new()
	cook.game = g
	g.add_child(cook)
	assert(cook.next_ingredient(["bun_bottom", "patty", "pickle"], customer.order) == "")
	for i in 100: cook.update(0.1)
	assert(g.visual_count == 2)
	assert(g.supply_stock.tomato == 1 and g.supply_stock.ketchup == 1)
	assert(g.served_count == 1)
	# A player changing the board during a throw cancels the pending addition.
	customer.is_waiting = true
	g.stations[0].items = ["bun_bottom", "patty", "bun_top"]
	cook.cooldown = 0.0
	cook.update(0.1)
	g.stations[0].items = []
	for i in 20: cook.update(0.1)
	assert(g.supply_stock.tomato == 1)
	# Fast strokes crossing a thin pile must register even when both endpoints miss.
	g.grill_root = Node3D.new()
	g.add_child(g.grill_root)
	var at := Vector3(g.GRILL_CENTER_X, g.GRILL_SURFACE_Y, g.GRILL_SURFACE_Z)
	g._add_scraped_debris_pile(at, 0.2)
	for i in 30:
		if g.debris_piles.is_empty(): break
		var p: Vector3 = g.debris_piles[0].root.position
		g._nudge_debris_piles(p + Vector3(0, 0, 0.22), Vector2(0, 0.44), 0.44)
	assert(g.debris_piles.is_empty())
	for id in ["tomato", "ketchup"]:
		var fx = load("res://scripts/robot_cook.gd").new()
		fx.game = g
		g.add_child(fx)
		fx.visual(id, 0, Vector3.ZERO, Vector3(0, 1, 0))
		await create_timer(1.4).timeout
		assert(not is_instance_valid(fx))
	customer.free()
	print("ROBOT_COOK_OK: toppings, sauce, one serve, cancellation, swept debris removal")
	quit()

