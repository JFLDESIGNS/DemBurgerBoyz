extends SceneTree

class SizzleProbe extends Node:
	var active := false
	var gain := 0.0
	func set_sizzle_active(on: bool, _heat: float, volume: float):
		active = on
		gain = volume

func _initialize() -> void: call_deferred("run")

func run() -> void:
	create_timer(35).timeout.connect(func(): quit(1))
	var game = load("res://scenes/main.tscn").instantiate()
	game.set_script(load("res://tests/social_shift_fixture.gd"))
	root.add_child(game); current_scene = game
	game.playing = true
	game._setup_stations_data()
	game.grill.resize(game.GRILL_SLOTS)
	game.slot_positions.resize(game.GRILL_SLOTS)
	var bun = game._make_held_bun()
	bun.set_process(false)
	assert(bun.get_node_or_null("Top") != null and bun.get_node_or_null("Bottom") != null)
	game.spatula_patty = bun
	game._place_spatula_on_grill_local(0, Vector3(game.GRILL_CENTER_X, game.GRILL_SURFACE_Y, game.GRILL_SURFACE_Z))
	assert(game.spatula_patty == null and game.grill[0] == bun and not bun.is_held)
	bun.heating = true; bun.heat_mul = 1
	var audio_before = game.game_audio
	var probe := SizzleProbe.new()
	game.game_audio = probe
	game._update_kitchen_sizzle()
	assert(probe.active and probe.gain >= .85, "Toasting buns must have an audible cooking bed")
	game.game_audio = audio_before
	probe.free()
	bun._process(3.9); assert(not bun.is_ready() and bun._halo.visible)
	bun._process(.1); assert(bun.is_ready() and not bun._halo.visible)
	bun._process(12); assert(bun.is_ready() and not bun.is_burnt())
	bun._process(.1); assert(bun.is_burnt())
	bun.cook_time = 10
	game._begin_patty_drag(bun)
	assert(game.dragging_patty == bun and game.spatula_patty == null)
	var before_slide: Vector2 = Vector2(bun.position.x,bun.position.z)
	game._move_grill_patty_slide(bun,before_slide+Vector2(.12,0),before_slide,true)
	assert(bun.position.x > before_slide.x+.08 and bun.cook_time == 10)
	game.dragging_patty = null
	game.shift_paused = true; bun._process(2); assert(bun.cook_time == 10)
	game.shift_paused = false
	game._pickup_bun_from_grill(bun)
	bun._process(2); assert(bun.cook_time == 10)
	game._commit_bun_to_build(bun)
	assert(game._station_has_toasted_buns(0))
	assert(game.stations[0].items == ["bun_bottom", "bun_top"])
	var data = load("res://scripts/game_data.gd")
	var order = ["bun_bottom", "patty", "bun_top", "toasted_bun"]
	game.stations[0].items = ["bun_bottom", "patty", "bun_top"]
	assert(data.compare_orders(game._station_order_items(0), order).perfect)
	assert(not data.compare_orders(game.stations[0].items, order).perfect)
	assert(game._ticket_line_specs(order).any(func(line): return line.id == "toasted_bun"))
	game._pickup_station_bun_to_hand(0, 2)
	assert(game.stations[0].items == ["patty"] and game.spatula_patty.cook_time == 10)
	assert(not game._station_has_toasted_buns(0))
	game._place_spatula_on_grill_local(0, Vector3(game.GRILL_CENTER_X, game.GRILL_SURFACE_Y, game.GRILL_SURFACE_Z))
	assert(game.grill[0].cook_time == 10)
	game._begin_patty_drag(game.grill[0])
	game._end_patty_drag()
	assert(game.grill[0] == null and game.spatula_patty == null and game._station_has_toasted_buns(0), "Tap finished buns straight to Build")
	game.supply_stock["bun_bottom"] = 10
	game.supply_stock["bun_top"] = 10
	game._bun_pile_drag = {"origin": Vector2.ZERO}
	var drag := InputEventMouseMotion.new()
	drag.position = Vector2(30, 0)
	assert(game._handle_bun_pile_drag(drag))
	assert(game.supply_stock["bun_bottom"] == 9 and game.supply_stock["bun_top"] == 9)
	assert(game.spatula_patty != null and game.spatula_patty.cook_time == 0)
	assert(game.spatula_lmb_held)
	print("BUN_TOAST_OK: 4/16 timing, halo, pause, pickup/return, order requirement, retained progress")
	game.queue_free(); await process_frame; quit()
