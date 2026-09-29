extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assert(str(ProjectSettings.get_setting("application/config/custom_user_dir_name")).begins_with("BurgerSettingsMenuTest"))
	create_timer(70).timeout.connect(func(): push_error("DISPLAY_SETTINGS_TIMEOUT"); quit(1))
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
	if menu.get("display_options") == null:
		push_error("Settings must expose display mode, resolution, and FPS controls")
		quit(1)
		return
	var display = menu.display_options
	root.mode = Window.MODE_WINDOWED
	root.borderless = false
	root.size = Vector2i(1280, 720)
	for i in 5: await process_frame
	display.refresh()
	display.save_display()
	var original_size := root.size
	var original_position := root.position
	var original_file := FileAccess.get_file_as_string(display.SAVE_PATH)
	display.mode_choice.select(1)
	display.apply_changes()
	for i in 5: await process_frame
	assert(display.has_pending() and display.confirmation.visible)
	assert(root.mode == Window.MODE_FULLSCREEN)
	assert(FileAccess.get_file_as_string(display.SAVE_PATH) == original_file, "Preview must not persist before Keep")
	display.keep_button.grab_focus()
	await press_tab(true)
	assert(display.confirmation.is_ancestor_of(root.gui_get_focus_owner()), "Shift+Tab must stay inside confirmation")
	await press_tab(false)
	await press_tab(false)
	assert(display.confirmation.is_ancestor_of(root.gui_get_focus_owner()), "Tab must stay inside confirmation")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/display_confirmation.png")
	# Escape must cancel the preview, leaving Settings open.
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	game._input(escape)
	for i in 5: await process_frame
	assert(menu.visible and not display.has_pending())
	assert(root.mode == Window.MODE_WINDOWED and not root.borderless)
	assert(root.size == original_size and root.position == original_position)
	# Simulate a larger remembered window size after changing monitors in fullscreen.
	root.mode = Window.MODE_FULLSCREEN
	display.windowed_size = Vector2i(9999, 9999)
	display.refresh()
	for index in display.resolution_choice.item_count:
		var available: Vector2i = display.resolution_choice.get_item_metadata(index)
		assert(display.safe_window_size(available) == available, "Every choice must fit the current monitor")
	root.mode = Window.MODE_WINDOWED
	root.borderless = false
	root.size = original_size
	root.position = original_position
	display.refresh()
	display.mode_choice.select(2)
	display.apply_changes()
	for i in 5: await process_frame
	assert(root.mode == Window.MODE_EXCLUSIVE_FULLSCREEN)
	# Let the real timer perform the rollback.
	await create_timer(15.3).timeout
	for i in 5: await process_frame
	assert(not display.has_pending() and root.mode == Window.MODE_WINDOWED)
	assert(root.size == original_size)
	assert(FileAccess.get_file_as_string(display.SAVE_PATH) == original_file)
	# Confirm a window size, then reload the configuration from disk.
	display.mode_choice.select(0)
	display.resolution_choice.select(mini(1, display.resolution_choice.item_count - 1))
	var chosen: Vector2i = display.resolution_choice.get_selected_metadata()
	display.apply_changes()
	for i in 5: await process_frame
	assert(root.size == chosen)
	display.keep_changes()
	display.fps_choice.select(1)
	display.fps_choice.item_selected.emit(1)
	assert(Engine.max_fps == 60)
	display.vsync.set_pressed_no_signal(false)
	display.vsync.toggled.emit(false)
	Engine.max_fps = 0
	root.size = Vector2i(1000, 700)
	display.load_display()
	for i in 5: await process_frame
	assert(Engine.max_fps == 60 and root.size == chosen)
	assert(DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED)
	# An unrelated setting saved during preview must keep the confirmed display mode.
	display.refresh()
	display.mode_choice.select(1)
	display.apply_changes()
	display.fps_choice.select(2)
	display.fps_choice.item_selected.emit(2)
	var cfg := ConfigFile.new()
	assert(cfg.load(display.SAVE_PATH) == OK)
	assert(int(cfg.get_value("display", "mode")) == 0)
	assert(int(cfg.get_value("display", "fps_limit")) == 120)
	display.revert_changes()
	assert(Engine.max_fps == 120)
	for index in display.FPS_LIMITS.size():
		display.fps_choice.select(index)
		display.fps_choice.item_selected.emit(index)
		assert(Engine.max_fps == display.FPS_LIMITS[index])
	# Both full-screen modes must survive a save and reload after confirmation.
	for mode in [1, 2]:
		display.mode_choice.select(mode)
		display.apply_changes()
		for i in 3: await process_frame
		display.keep_changes()
		root.mode = Window.MODE_WINDOWED
		display.load_display()
		for i in 3: await process_frame
		assert(root.mode == display.MODES[mode])
	# Legacy saves remain valid, including the old fullscreen toggle.
	cfg.clear()
	cfg.set_value("display", "fullscreen", false)
	cfg.set_value("display", "vsync", true)
	assert(cfg.save(display.SAVE_PATH) == OK)
	display.load_display()
	assert(root.mode == Window.MODE_WINDOWED and Engine.max_fps == 0)
	display.refresh()
	menu.tabs.current_tab = 1
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/display_settings.png")
	print("DISPLAY_SETTINGS_OK: modes, Escape, timed rollback, persistence, FPS, legacy saves")
	quit()

func press_tab(backwards: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_TAB
	event.shift_pressed = backwards
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
