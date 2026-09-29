extends SceneTree
func _initialize(): call_deferred("run")
func run() -> void:
	create_timer(60).timeout.connect(func(): push_error("RESTOCK_TIMEOUT"); quit(1))
	var g = load("res://scenes/main.tscn").instantiate()
	g.set_script(load("res://tests/full_restock_fixture.gd"))
	root.add_child(g); current_scene = g; g.playing = true
	g.money = 100; g.supply_stock.lettuce = 3
	g._buy_supply_local("lettuce")
	assert(g.supply_orders[0].pack == 13 and g.money == 87)
	g._buy_supply_local("lettuce"); assert(g.supply_orders.size() == 1 and g.money == 87)
	g.supply_orders.clear(); g._credit_supply_delivery("lettuce",13,"stock")
	assert(g.supply_stock.lettuce == 16)
	g._buy_supply_local("lettuce"); assert(g.supply_orders.is_empty() and g.money == 87)
	g.money = 5.5; g.supply_stock.bacon = 0
	g._buy_supply_local("bacon")
	assert(g.supply_orders[0].pack == 2 and g.money == 1.5)
	g.supply_orders.clear(); g.money = .19; g.supply_stock.bun_bottom = 0
	g._buy_supply_local("bun_bottom"); assert(g.supply_orders.is_empty() and is_equal_approx(g.money,.19))
	g.money = 4.2; g.supply_stock.bun_bottom = 0
	g._buy_supply_local("bun_bottom")
	assert(g.supply_orders[0].pack == 21 and absf(g.money) < .00001)
	g.supply_orders.clear(); g.money = 100; g.supply_stock.tomato = 0
	g.supply_delivery_fx = [{"id":"tomato", "pack":16}]
	g._buy_supply_local("tomato"); assert(g.supply_orders.is_empty() and g.money == 100)
	g.supply_delivery_fx.clear()
	g.owned_machines[g.SHOP_FRIDGE_UPGRADE] = true; g.supply_stock.cheese = 10
	g._buy_supply_local("cheese")
	assert(g.supply_orders[0].pack == 22 and g.money == 78, "Full restocks include upgraded capacity")
	# Icons retain their original height; full well planes sit 0.9 inches lower.
	var btn = Button.new(); g.get_node("UI/Root").add_child(btn); btn.size = Vector2(100,100)
	var stack = VBoxContainer.new(); stack.name = "Stack"; btn.add_child(stack)
	var margin = MarginContainer.new(); margin.name = "IconMargin"; stack.add_child(margin)
	var icon = TextureRect.new(); icon.name = "StripIcon"; margin.add_child(icon); icon.rotation = .3
	g.ingredient_buttons = {"tomato":btn}
	g._apply_ingredient_bin_strip_layout()
	assert(icon.rotation == 0)
	assert(margin.get_theme_constant("margin_top") == int(round(g._strip_gfx_icon_offset().y)))
	var tub = Node3D.new(); g.world.add_child(tub); tub.scale = Vector3.ONE*.2
	var fill = MeshInstance3D.new(); fill.name = "Fill"; tub.add_child(fill)
	g.ingredient_bin_nodes = {"tomato":tub}; g.supply_stock.tomato = g._ingredient_stock_cap("tomato")
	g._update_bin_fills_3d("tomato")
	assert(is_equal_approx(fill.global_position.y, -.05*.2 - .02286))
	assert(is_equal_approx(fill.rotation_degrees.x, -90))
	assert(g._bin_fill_default_entry("tomato").tilt == -90)
	g.queue_free(); await process_frame
	print("FULL_RESTOCK_OK: capacity, affordable partial, duplicate delivery, exact pricing, original icons and well planes lowered 0.9 inches")
	quit()
