extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.set_script(load("res://tests/main_ticket_harness.gd"))
	root.add_child(game)
	current_scene = game
	game._seed_first_run_configs()
	game._style_static_labels()
	game._setup_stations_data()
	game._setup_game_audio()
	await game._initialize_kitchen()
	game.start_overlay.hide()
	game.flash_label.hide()
	game.game_over_panel.hide()
	game._set_phone_in_truck(false)
	game._set_grill_on(true)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	for i in 16: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/matte_grill_release/grill.png")
	print("MATTE_GRILL_PREVIEW_OK")
	quit()
