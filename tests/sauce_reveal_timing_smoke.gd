extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	create_timer(20.0).timeout.connect(func(): quit(1))
	var g = load("res://scenes/main.tscn").instantiate()
	g.set_script(load("res://tests/instant_sauce_fixture.gd"))
	root.add_child(g)
	g.playing = true
	g.animate_pours = true
	g.stations = [{"items": ["bun_bottom", "patty"], "patties": []}]
	g.supply_stock.ketchup = 4
	var bottle := Node3D.new()
	g.add_child(bottle)
	g.condiment_bottle_roots.ketchup = bottle
	g._request_condiment_add("ketchup", 0)
	var state: Dictionary = g.stations[0].sauce_reveal.ketchup
	var tween: Tween = g._condiment_auto_tweens.ketchup
	tween.pause()
	tween.custom_step(g.CONDIMENT_BOTTLE_TRAVEL_SEC + g.CONDIMENT_BOTTLE_TILT_SEC)
	assert(state.progress == 0.0, "Bottle travel and tilt must not expose sauce")
	tween.custom_step(g.CONDIMENT_BOTTLE_POUR_SEC * 0.1)
	assert(state.progress == 0.0, "Stream must reach burger before sauce appears")
	tween.custom_step(g.CONDIMENT_BOTTLE_POUR_SEC * 0.46)
	assert(absf(state.progress - 0.5) < 0.02, "Sauce should reveal half its width halfway through the sweep")
	tween.custom_step(g.CONDIMENT_BOTTLE_POUR_SEC * 0.45)
	assert(is_equal_approx(state.progress, 1.0), "Finished pour must expose all sauce")
	g.queue_free()
	await process_frame
	print("SAUCE_REVEAL_TIMING_OK: hidden during travel, delayed contact, progressive sweep, full finish")
	quit()
