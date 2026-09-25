extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	create_timer(180).timeout.connect(func(): push_error("LIGHT_BALANCE_TIMEOUT"); quit(1))
	var legacy := ConfigFile.new()
	legacy.set_value("balance","bias",0.025)
	legacy.set_value("balance","normal_bias",0.35)
	legacy.set_value("balance","sun_color",Color("ffd477"))
	legacy.set_value("balance","azimuth",81.0)
	assert(legacy.save("user://light_balance.cfg") == OK)
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
	game._build_screen_style_filter()
	var balance = game.light_balance
	assert(balance != null)
	assert(is_equal_approx(float(balance.values.bias),0.06))
	assert(is_equal_approx(float(balance.values.normal_bias),1.0))
	assert(balance.values.sun_color == Color("ffd477"), "Bias migration must preserve color")
	assert(is_equal_approx(float(balance.values.azimuth),81.0), "Bias migration must preserve angle")
	balance.values = balance.DEFAULTS.duplicate()
	balance.apply()
	for i in 5: await process_frame
	assert(balance.sun.visible and balance.sun.shadow_enabled)
	assert(game.gfx_env.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR)
	assert(game.gfx_env.ambient_light_color.b > game.gfx_env.ambient_light_color.r)
	assert(balance.sun.light_color.r > balance.sun.light_color.b)
	assert(not game._profile_sun.visible)
	assert(not game.level_editor._dressing.get_node("WarmWindowKey").visible)
	assert(game.screen_style_layer.visible)
	var accent := SpotLight3D.new()
	accent.name = "BalanceTestAccent"
	game.level_editor._dressing.add_child(accent)
	await process_frame
	assert(accent.visible, "Placed lights must work by default")
	balance.set_value("placed_lights",false)
	assert(not accent.visible, "Explicit accent mute must still work")
	assert(load("res://scripts/level_light_settings.gd").snapshot(accent).visible, "Saving dressing must preserve authored visibility")
	balance.set_value("placed_lights",true)
	assert(accent.visible, "Opt-in must restore placed lights without changing their settings")
	balance.set_value("placed_lights",false)
	assert(not accent.visible)
	var added: Light3D = game.level_editor._make_dressing_light("omni")
	game.level_editor._finish_place(added)
	await process_frame
	assert(added.visible and balance.values.placed_lights, "Adding a light must unmute accents")
	added.queue_free()
	accent.queue_free()
	await process_frame
	balance.set_value("sun_energy", 2.4)
	balance.set_value("shadow_tint", Color("3366ee"))
	balance.set_value("transition_saturation", 0.7)
	balance.save()
	var cfg := ConfigFile.new()
	assert(cfg.load(balance.SAVE_PATH) == OK)
	assert(is_equal_approx(float(cfg.get_value("balance","sun_energy")),2.4))
	assert(game.screen_style_mat.get_shader_parameter("grade_transition_saturation") == 0.7)
	var restored = load("res://scripts/light_balance.gd").new()
	game.add_child(restored)
	restored.setup(game)
	assert(is_equal_approx(float(restored.values.sun_energy),2.4), "Reload must restore saved intensity")
	assert(restored.values.shadow_tint == Color("3366ee"), "Reload must restore colors")
	restored.set_process(false)
	restored.sun.queue_free()
	restored.queue_free()
	# Existing graphics application must not stomp the selected lighting balance.
	game._apply_graphics_settings(game._read_graphics_from_ui())
	assert(is_equal_approx(balance.sun.light_energy,2.4))
	assert(game.gfx_env.ambient_light_color == balance.values.ambient_color)
	game._set_graphics_slider_value("exposure",1.1)
	assert(is_equal_approx(float(balance.values.exposure),1.1))
	assert(is_equal_approx(game.gfx_env.tonemap_exposure,1.1))
	game._set_graphics_check_value("glow_on",false)
	assert(not balance.values.bloom_enabled and not game.gfx_env.glow_enabled)
	balance.set_value("simple",false)
	assert(not balance.sun.visible)
	balance.set_value("simple",true)
	balance.values = balance.DEFAULTS.duplicate()
	balance.apply()
	balance.save()
	game.level_editor.set_active(true)
	balance.show_panel(game.level_editor._ui)
	assert(balance.controls.size() >= 35)
	balance.controls.sun_energy.value = 2.3
	assert(is_equal_approx(balance.sun.light_energy,2.3))
	game.set_profile_sun_sky(82.0, 22.0)
	assert(game.get_light_profile_sun_sky().is_equal_approx(Vector2(82,22)))
	assert(is_equal_approx(balance.controls.azimuth.value,82.0))
	assert(is_equal_approx(balance.number_controls.azimuth.value,82.0))
	game.reset_profile_sun_sky()
	assert(game.get_light_profile_sun_sky().is_equal_approx(Vector2(76,24)))
	balance.controls.post_enabled.button_pressed = false
	assert(not bool(game.screen_style_mat.get_shader_parameter("grade_post_enabled")))
	balance.controls.post_enabled.button_pressed = true
	balance.controls.sun_energy.value = 2.0
	if DisplayServer.get_name() != "headless":
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1280,720)
		for i in 16: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/light_balance_release/panel.png")
		var scroll: ScrollContainer = balance.section_headers["POST PROCESSING / COLOR GRADE"].get_parent().get_parent()
		scroll.scroll_vertical = int(balance.section_headers["POST PROCESSING / COLOR GRADE"].position.y)
		for i in 6: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/light_balance_release/color_controls.png")
		scroll.scroll_vertical = int(balance.section_headers["LENS & TEXTURE"].position.y)
		for i in 6: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/light_balance_release/lens_controls.png")
		game.level_editor.set_active(false)
		for i in 12: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/light_balance_release/kitchen.png")
		for energy in [0.65, 1.0, 1.3]:
			balance.set_value("ambient_energy",energy)
			for i in 8: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://build/light_balance_release/ambient_%s.png" % str(energy))
		balance.set_value("ambient_energy",balance.DEFAULTS.ambient_energy)
	print("LIGHT_BALANCE_OK single sun, colors, UI, persistence, graphics reapply, bypass")
	game.queue_free()
	for i in 5: await process_frame
	quit()
