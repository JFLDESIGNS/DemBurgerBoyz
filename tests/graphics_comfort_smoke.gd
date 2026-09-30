extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assert(str(ProjectSettings.get_setting("application/config/custom_user_dir_name")).begins_with("BurgerSettingsMenuTest"))
	create_timer(60).timeout.connect(func(): push_error("GRAPHICS_COMFORT_TIMEOUT"); quit(1))
	var game = load("res://scenes/main.tscn").instantiate()
	game.set_script(load("res://tests/title_menu_fixture.gd"))
	root.add_child(game)
	current_scene = game
	game._style_static_labels()
	game._setup_multiplayer_ui()
	game.flash_label.hide()
	game.game_over_panel.hide()
	game._open_player_settings()
	var menu = game.player_settings
	if menu.get("quality_choice") == null or menu.get("reduced_motion_check") == null:
		push_error("Settings must expose quality, render scale, and reduced motion")
		quit(1)
		return
	var ui_scale := root.content_scale_factor
	for preset in ["Low", "Medium", "High"]:
		menu.set_quality_preset(preset)
		var cfg := ConfigFile.new()
		assert(cfg.load(game.GFX_CFG_PATH) == OK)
		var values: Dictionary = game._quality_preset_values(preset)
		for key in values: assert(cfg.get_value("gfx", key) == values[key])
		assert(is_equal_approx(root.scaling_3d_scale, values.render_scale))
		assert(root.msaa_3d == int(values.msaa_level))
		assert(menu.quality_choice.get_item_text(menu.quality_choice.selected) == preset)
		assert(cfg.load(menu.LightBalance.SAVE_PATH) == OK)
		assert(cfg.get_value("balance", "bloom_enabled") == values.glow_on)
	menu.graphics_controls["render_scale"].value = 0.5
	assert(is_equal_approx(root.scaling_3d_scale, 0.5))
	assert(is_equal_approx(root.content_scale_factor, ui_scale), "Render scale must leave UI scale intact")
	assert(menu.quality_choice.get_item_text(menu.quality_choice.selected) == "Custom")
	menu.close()
	menu.open()
	assert(menu.graphics_controls["render_scale"].get_meta("readout").text == "50%")
	menu.set_quality_preset("High")
	assert(is_equal_approx(root.scaling_3d_scale, 1.0), "Reapplying a preset must reset a custom scale")
	menu.reduced_motion_check.button_pressed = true
	assert(game.reduced_motion)
	var layout = game.start_overlay.get_node("TitleMenuLayout")
	game.start_btn.mouse_entered.emit()
	game.start_btn.button_down.emit()
	layout._entrance()
	await create_timer(0.3).timeout
	assert(game.start_btn.position == Vector2.ZERO)
	for holder in layout.entries:
		assert(holder.position == holder.get_meta("home") and holder.modulate.a == 1.0)
	game.camera = Camera3D.new()
	game.add_child(game.camera)
	game.camera.position = game.slot_camera_base_pos
	game._start_slot_camera_shake()
	game._update_slot_camera_shake(0.016)
	assert(game.slot_camera_shake_t == 0.0 and game.camera.position == game.slot_camera_base_pos)
	game.reduced_motion = false
	game._load_accessibility_settings()
	assert(game.reduced_motion, "Reduced motion must persist")
	menu.reduced_motion_check.button_pressed = false
	game.start_btn.mouse_entered.emit()
	await create_timer(0.4).timeout
	assert(is_equal_approx(game.start_btn.position.y, -4), "Normal hover must return when reduced motion is off")
	game._start_slot_camera_shake()
	assert(game.slot_camera_shake_t > 0.0)
	menu.reduced_motion_check.button_pressed = true
	assert(game.slot_camera_shake_t == 0.0 and game.camera.position == game.slot_camera_base_pos)
	# Restore the default accessibility preference for unrelated title tests.
	menu.reduced_motion_check.button_pressed = false
	print("GRAPHICS_COMFORT_OK: presets, custom scale, persistence, motion suppression and restore")
	quit()
