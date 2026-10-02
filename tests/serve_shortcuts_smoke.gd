extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	create_timer(20).timeout.connect(func(): quit(1))
	var g = load("res://scenes/main.tscn").instantiate()
	g.set_script(load("res://tests/serve_shortcuts_fixture.gd"))
	root.add_child(g); g.playing = true
	g.stations = [{"items":["bun_bottom","patty","cheese","bun_top"],"patties":[]}]
	g._add_ingredient("cheese")
	assert(g.served == 0, "First tap cannot unexpectedly serve")
	g._add_ingredient("cheese")
	assert(g.served == 1 and g.stations[0].items.count("cheese") == 1)
	assert(g._try_cutting_board_thud_click(Vector2.ZERO) and g.served == 2)
	g.ready_burger = false
	g._add_ingredient("cheese"); g._add_ingredient("cheese")
	assert(not g._try_cutting_board_thud_click(Vector2.ZERO) and g.served == 2)
	g.stations[0].items = []
	assert(g._try_cutting_board_thud_click(Vector2.ZERO) and g.served == 2)
	g.cheese_held = true
	assert(not g._try_cutting_board_thud_click(Vector2.ZERO))
	print("SERVE_SHORTCUTS_OK: repeat topping, ready board, incomplete burger, empty tap, held item")
	g.queue_free(); await process_frame; quit()
