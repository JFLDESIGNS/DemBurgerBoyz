extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assert(str(ProjectSettings.get_setting("application/config/custom_user_dir_name")).begins_with("BurgerSettingsMenuTest"), "Use an isolated settings test profile")
	create_timer(45).timeout.connect(func(): push_error("SETTINGS_TIMEOUT"); quit(1))
	var game = load("res://scenes/main.tscn").instantiate()
	game.set_script(load("res://tests/title_menu_fixture.gd"))
	root.add_child(game)
	current_scene = game
	game._style_static_labels()
	game._setup_multiplayer_ui()
	game.flash_label.hide()
	game.game_over_panel.hide()
	var button = game.start_overlay.find_child("SettingsButton", true, false)
	if button == null:
		push_error("Title screen must expose Settings before the kitchen loads")
		quit(1)
		return
	button.pressed.emit()
	await process_frame
	assert(game.player_settings.visible and game.options_menu_open)
	assert(not game._kitchen_ready)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	game._input(escape)
	assert(not game.player_settings.visible and not game.options_menu_open)
	game._build_window_pause_ui()
	game.shift_paused = true
	game.window_shutter.show()
	game.window_shutter.get_node("SettingsButton").pressed.emit()
	assert(game.player_settings.visible)
	game.player_settings.close()
	assert(game.shift_paused, "Back must preserve the paused shift")
	print("SETTINGS_NAVIGATION_OK")
	game.shift_paused = false
	game.window_shutter.hide()
	game._open_player_settings()
	var settings = game.player_settings
	settings.audio_controls["master_volume_linear"].value = 0.63
	settings.audio_controls["sound_effects_volume_linear"].value = 0.27
	settings.audio_controls["radio_volume_linear"].value = 0.41
	assert(is_equal_approx(game.master_volume_linear, 0.63))
	assert(is_equal_approx(game.sound_effects_volume_linear, 0.27))
	assert(is_equal_approx(game.radio_volume_linear, 0.41))
	settings.audio_controls["master_volume_linear"].value = 0.0
	assert(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")))
	settings.audio_controls["master_volume_linear"].value = 0.63
	settings.graphics_controls["exposure"].value = 0.82
	settings.graphics_controls["shadows"].button_pressed = false
	var cfg := ConfigFile.new()
	assert(cfg.load(game.GFX_CFG_PATH) == OK)
	assert(is_equal_approx(float(cfg.get_value("gfx", "exposure")), 0.82))
	assert(not bool(cfg.get_value("gfx", "shadows")))
	assert(cfg.has_section_key("gfx", "heat_warp_on"), "Saving one setting must retain others")
	assert(cfg.load(settings.LightBalance.SAVE_PATH) == OK)
	assert(is_equal_approx(float(cfg.get_value("balance", "exposure")), 0.82), "Kitchen lighting must retain title-screen brightness")
	# The lighting editor has its own authoritative save file.
	cfg.set_value("balance", "exposure", 1.13)
	cfg.set_value("balance", "bloom_enabled", false)
	assert(cfg.save(settings.LightBalance.SAVE_PATH) == OK)
	settings.close()
	game._set_master_volume_linear(0.9, false)
	game._set_sound_effects_volume_linear(0.9, false)
	game._set_radio_volume_linear(0.9, false)
	settings.open()
	assert(is_equal_approx(game.master_volume_linear, 0.63))
	assert(is_equal_approx(game.sound_effects_volume_linear, 0.27))
	assert(is_equal_approx(game.radio_volume_linear, 0.41))
	assert(settings.audio_controls["radio_volume_linear"].get_meta("readout").text == "41%")
	assert(is_equal_approx(settings.graphics_controls["exposure"].value, 1.13))
	assert(not settings.graphics_controls["glow_on"].button_pressed)
	assert(not settings.graphics_controls["shadows"].button_pressed)
	print("SETTINGS_PERSISTENCE_OK")
	if DisplayServer.get_name() != "headless":
		root.mode = Window.MODE_WINDOWED
		DirAccess.make_dir_recursive_absolute("res://build/settings_preview")
		for resolution in [Vector2i(1280,720), Vector2i(1920,1080), Vector2i(800,600)]:
			root.size = resolution
			for tab in range(settings.tabs.get_tab_count()):
				settings.tabs.current_tab = tab
				for i in 8: await process_frame
				assert(root.get_visible_rect().encloses(settings.panel.get_global_rect()), "Settings must fit viewport")
				assert(settings.panel.get_global_rect().encloses(settings.back.get_global_rect()), "Back must stay accessible")
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://build/settings_preview/%d_%d.png" % [resolution.x, tab])
		settings.close()
		root.size = Vector2i(1280,720)
		await create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/settings_preview/title.png")
		print("SETTINGS_LAYOUT_OK")
	quit()
