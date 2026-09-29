extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assert(str(ProjectSettings.get_setting("application/config/custom_user_dir_name")).begins_with("BurgerSettingsMenuTest"), "Use an isolated settings test profile")
	create_timer(150).timeout.connect(func(): push_error("SETTINGS_KITCHEN_TIMEOUT"); quit(1))
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.menu_ready: await process_frame
	game._open_player_settings()
	game.player_settings.graphics_controls["exposure"].value = 0.76
	game.player_settings.graphics_controls["glow_on"].button_pressed = false
	game.player_settings.close()
	await game._initialize_kitchen()
	assert(is_equal_approx(game.gfx_env.tonemap_exposure, 0.76), "Title brightness must survive kitchen initialization")
	assert(not game.gfx_env.glow_enabled, "Title bloom choice must survive kitchen initialization")
	game._set_options_menu_open(true)
	game.options_panel.find_child("PlayerSettingsButton", true, false).button_down.emit()
	assert(game.player_settings.visible)
	game.player_settings.close()
	assert(game.options_menu_open, "Back must return to the existing options menu")
	game._set_options_menu_open(false)
	game.light_balance.set_value("exposure", 0.97)
	game._open_player_settings()
	assert(is_equal_approx(game.player_settings.graphics_controls["exposure"].value, 0.97), "Settings must reflect live lighting edits")
	game.player_settings.graphics_controls["exposure"].value = 1.05
	game.player_settings.graphics_controls["glow_on"].button_pressed = true
	assert(is_equal_approx(game.gfx_env.tonemap_exposure, 1.05))
	assert(game.gfx_env.glow_enabled)
	game.player_settings.audio_controls["sound_effects_volume_linear"].value = 0.32
	assert(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))), 0.32))
	game.player_settings.close()
	print("SETTINGS_KITCHEN_OK")
	quit()
