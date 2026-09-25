extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var game=load("res://scenes/main.tscn").instantiate()
	game.set_script(load("res://tests/main_ticket_harness.gd"))
	root.add_child(game)
	game.start_overlay.hide()
	game.flash_label.hide()
	game.game_over_panel.hide()
	game._setup_game_audio()
	game.radio = load("res://scripts/truck_radio.gd").new()
	game.add_child(game.radio)
	game.phone_radio_volume_slider = HSlider.new()
	game.phone_radio_volume_slider.max_value = 1.0
	game.phone_radio_volume_slider.step = 0.01
	game.add_child(game.phone_radio_volume_slider)
	game._build_options_menu()
	game._set_options_menu_open(true)
	var mix=game.options_panel.find_child("Audio Mix",true,false)
	assert(mix!=null and mix.get_parent() is TabContainer,"Mixer must be a normal Options tab")
	assert(mix.get_parent()!=game.options_hidden_tabs,"Mixer must not require the hidden-controls password")
	mix.get_parent().current_tab=mix.get_index()
	await process_frame
	assert(mix.is_visible_in_tree(),"Mixer must be visible without unlocking Hidden")
	var entries:Array=game.game_audio.get_sfx_tuning_entries()
	assert(entries.size()>0)
	var key:String=entries[0]["key"]
	var slider:HSlider=game.options_hidden_tree_light_sliders["sfx_"+key]
	assert(mix.is_ancestor_of(slider))
	var previous:float=slider.value
	slider.value=0.37
	assert(is_equal_approx(game.game_audio.get_sfx_level(key),0.37),"Mix slider must update audio")
	slider.value=previous
	assert(mix.is_ancestor_of(game.options_hidden_room_tone_vol))
	assert(mix.is_ancestor_of(game.options_hidden_outdoor_ambience_vol))
	var general: HSlider = game.options_hidden_tree_light_sliders["mix_general"]
	var effects: HSlider = game.options_hidden_tree_light_sliders["mix_effects"]
	var radio: HSlider = game.options_hidden_tree_light_sliders["mix_radio"]
	assert(mix.is_ancestor_of(general) and mix.is_ancestor_of(effects) and mix.is_ancestor_of(radio))
	general.value = 0.65
	effects.value = 0.35
	radio.value = 0.42
	var sfx_bus := AudioServer.get_bus_index("SFX")
	assert(sfx_bus >= 0)
	assert(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(0)), 0.65 * 0.20))
	assert(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(sfx_bus)), 0.35))
	assert(is_equal_approx(game.radio.volume_linear, 0.42))
	assert(is_equal_approx(game.phone_radio_volume_slider.value, 0.42))
	assert(game.radio._player.bus == &"Master")
	assert(game.game_audio._players[0].bus == &"SFX")
	assert(game.game_audio._sizzle_player.bus == &"SFX")
	effects.value = 0.0
	assert(AudioServer.is_bus_mute(sfx_bus) and not AudioServer.is_bus_mute(0))
	assert(is_equal_approx(game.radio.volume_linear, 0.42))
	effects.value = 0.35
	game._set_radio_volume_linear(0.56)
	assert(is_equal_approx(radio.value, 0.56))
	game._set_master_volume_linear(0.0)
	assert(AudioServer.is_bus_mute(0))
	general.value = 0.65
	game._set_sound_effects_volume_linear(0.9, false)
	game._set_radio_volume_linear(0.9, false)
	game._load_audio_settings()
	assert(is_equal_approx(effects.value, 0.35))
	assert(is_equal_approx(radio.value, 0.56))
	assert(is_equal_approx(general.value, 0.65))
	assert(game.options_hidden_tree_light_labs["mix_radio"].text == "56%")
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/audio_mix_release/audio_mix.png")
	print("AUDIO_MIX_ACCESS_OK")
	game.queue_free();await process_frame;quit()
