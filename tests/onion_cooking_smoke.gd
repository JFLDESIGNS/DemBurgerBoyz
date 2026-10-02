extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	create_timer(40).timeout.connect(func(): quit(1))
	var game = load("res://scenes/main.tscn").instantiate()
	game.set_script(load("res://tests/social_shift_fixture.gd"))
	root.add_child(game); current_scene = game; game.playing = true
	game._setup_stations_data()
	game.grill.resize(game.GRILL_SLOTS)
	game.slot_positions.resize(game.GRILL_SLOTS)
	var kitchen = game._ensure_onion_kitchen()
	var batch = load("res://scripts/onion_batch.gd").new()
	batch.game = game; game.world.add_child(batch); batch.set_process(false)
	kitchen.batches.append(batch)
	batch.position = Vector3(game.GRILL_CENTER_X, game.GRILL_SURFACE_Y+.008, game.GRILL_SURFACE_Z)
	assert(batch.pieces.get_child_count() == 4)
	game.grill_on = true
	batch._process(5)
	assert(batch.cook_time == 5 and not batch.is_ready())
	batch.chop(); assert(batch.pieces.get_child_count() == 8)
	batch.chop(); assert(batch.chops == 2 and batch.pieces.get_child_count() == 32)
	batch._process(5); assert(batch.is_ready() and batch.portions == 4)
	assert(is_equal_approx(float(batch.materials[0].get_shader_parameter("progress")),1.0))
	assert(not batch.label.visible and batch.label.text.is_empty())
	var before: Vector3 = batch.global_position
	kitchen.push_from_burger(Vector2(before.x-.35,before.z), Vector2(before.x-.05,before.z))
	assert(batch.global_position.distance_to(before) > .1)
	assert(batch.motion_energy > 0)
	assert(batch.portions == 4)
	batch.pressed = true; batch._process(.1); assert(batch.pieces.scale.y < .9)
	batch.pressed = false
	game.hand_spatula_root = Node3D.new(); game.add_child(game.hand_spatula_root)
	var blade := MeshInstance3D.new(); var box := BoxMesh.new(); box.size = Vector3(.15,.025,.25); blade.mesh = box
	game.hand_spatula_root.add_child(blade)
	kitchen.drag = {"batch":batch,"moved":true,"direction":Vector2(.02,0),"target":Vector2(batch.position.x+.1,batch.position.z)}
	kitchen.apply_spatula(.016)
	var slide_basis: Basis = game.hand_spatula_root.global_basis
	kitchen.drag.direction = Vector2(-.02,0)
	kitchen.apply_spatula(.1)
	assert(game.hand_spatula_root.global_basis.is_equal_approx(slide_basis), "Reversing slide must not flip the spatula")
	assert(game.hand_spatula_root.global_basis.y.is_equal_approx(Vector3.UP), "Press/slide must keep blade flat")
	var world_box: AABB = game.hand_spatula_root.global_transform*game._shop_preview_bounds(game.hand_spatula_root)
	assert(world_box.position.y >= game.GRILL_SURFACE_Y+.007, "Blade must stay above steel")
	var slide_start: Vector3 = batch.global_position
	batch.pressed = true
	kitchen._process(.016)
	assert(batch.global_position.distance_to(slide_start) > 0 and batch.global_position.distance_to(slide_start) < .1, "Sliding should follow smoothly, not snap")
	batch.pressed = false
	kitchen.drag.clear()
	game.shift_paused = true; batch.cook_time = 3; batch._process(3); assert(batch.cook_time == 3)
	game.shift_paused = false
	var hold: Rect2 = game._warmer_rect()
	batch.position.x = hold.get_center().x; batch.position.z = hold.get_center().y
	batch._process(3); assert(batch.cook_time == 3, "HOLD must stop cooking")
	batch.cook_time = 10
	for n in 4:
		game.stations[0].items = ["bun_bottom", "patty", "bun_top"]
		assert(kitchen.portion(batch))
		assert(game.stations[0].items.has("onion") and game.stations[0].cooked_onion)
		assert(batch.portions == 3-n)
	assert(kitchen.batches.is_empty())
	var data = load("res://scripts/game_data.gd")
	var requested = ["bun_bottom","patty","onion","bun_top","grilled_onion"]
	assert(data.compare_orders(game._station_order_items(0),requested).perfect)
	assert(not data.compare_orders(game.stations[0].items,requested).perfect)
	assert(game._ticket_line_specs(requested).any(func(line): return line.id == "grilled_onion"))
	requested.append("toasted_bun")
	assert(game._ticket_line_specs(requested)[0].id == "toasted_bun")
	var customer = load("res://scripts/customer.gd").new()
	customer.order.assign(requested)
	customer.order_elapsed_sec = customer.SERVE_PERFECT_SEC + 8.0
	assert(customer.speed_rating().label == "Perfect" and customer.speed_rating().stars == 5.0)
	assert(customer.speed_rating().wait == customer.order_elapsed_sec)
	customer.order_elapsed_sec += .01
	assert(customer.speed_rating().label == "Great job")
	customer.order.erase("toasted_bun")
	assert(customer.speed_rating().label != "Perfect")
	customer.free()
	var bun = game._make_held_bun(); bun.set_process(false)
	for half in ["Top", "Bottom"]:
		var bounds: AABB = game._shop_preview_bounds(bun.get_node(half))
		assert(maxf(bounds.size.x,bounds.size.z) <= .161)
		assert(absf(bounds.position.y) < .001)
	assert(is_equal_approx(absf(bun.get_node("Bottom").get_child(0).rotation.z), PI))
	bun.cook_time = 2; bun.heating = true; bun.is_held = false; bun.set_hint_focus(true)
	assert(not bun._hint.visible, "No TOAST label during cooking")
	var sprites = load("res://scripts/food_sprites.gd")
	assert(sprites.bun_cooked_tex(8) != sprites.get_tex("bun_bottom"))
	assert(sprites.bun_cooked_tex(17) != sprites.bun_cooked_tex(8))
	game.hud_chrome_collapsed = false
	game.phone_column = VBoxContainer.new(); game.add_child(game.phone_column)
	game._phone_lock_screen = Button.new(); game.phone_column.add_child(game._phone_lock_screen)
	game.phone_nav_title = Label.new(); game.phone_column.add_child(game.phone_nav_title)
	game.phone_scroll = ScrollContainer.new(); game.phone_scroll.custom_minimum_size = Vector2(300,200); game.phone_column.add_child(game.phone_scroll)
	game.phone_shop_page = VBoxContainer.new(); game.phone_scroll.add_child(game.phone_shop_page)
	var spacer := Control.new(); spacer.custom_minimum_size = Vector2(300,600); game.phone_shop_page.add_child(spacer)
	var card := PanelContainer.new(); card.name = "ShopCard_%s" % game.SHOP_FRYER_MACHINE; card.custom_minimum_size = Vector2(300,300); game.phone_shop_page.add_child(card)
	await game._open_phone_to_fryer()
	assert(game._phone_expanded and not game._phone_lock_screen.visible)
	assert(game._phone_app_id == "shop" and game.phone_scroll.scroll_vertical > 500)
	print("ONION_COOKING_OK: four rings, chop stages, translucency, pause/HOLD, four portions, bun size/orientation")
	game.queue_free(); await process_frame; quit()
