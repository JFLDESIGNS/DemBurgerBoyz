extends SceneTree
var failures: Array[String] = []
func _init() -> void:
	call_deferred("_run")
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
func _run() -> void:
	# This test deliberately saves settings; require a separate test profile.
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir", "")).begins_with("BurgerPerformanceIsolatedTest"):
		push_error("Run this integration test in an isolated project/profile (see PERFORMANCE_NOTES.md).")
		quit(1)
		return
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game._apply_quality_preset("Low")
	expect(is_equal_approx(root.scaling_3d_scale, 0.75) and root.msaa_3d == Viewport.MSAA_DISABLED, "Low preset must lower rendering cost")
	expect(not game.gfx_env.ssil_enabled and not game.gfx_outside_fill.shadow_enabled and not game.gfx_kitchen.shadow_enabled, "Low preset must disable secondary effects")
	game.gfx_choices["msaa_level"].select(3)
	game._load_graphics_settings()
	game._apply_graphics_settings(game._read_graphics_from_ui())
	expect(root.msaa_3d == Viewport.MSAA_DISABLED, "Saved preset must restore graphics choices")
	game._apply_quality_preset("Medium")
	expect(root.msaa_3d == Viewport.MSAA_2X and root.screen_space_aa == Viewport.SCREEN_SPACE_AA_DISABLED, "Medium preset must use only 2x MSAA")
	game._apply_quality_preset("High")
	expect(root.msaa_3d == Viewport.MSAA_4X and game.gfx_env.ssil_enabled, "High preset must restore high quality")
	var audio = game.game_audio
	audio.set_process(false)
	var beds := {"hiss": ["set_burner_hiss", "cooking"], "spray": ["set_ext_spray", "tools"], "shake": ["set_shaker_rattle", "tools"], "soda": ["set_soda_pour", "drinks"], "ice": ["set_ice_grind", "ice"], "softserve": ["set_softserve_dispense", "softserve"]}
	for key in beds:
		var setter: String = beds[key][0]
		var level: String = beds[key][1]
		var player: AudioStreamPlayer = audio.get("_" + key + "_player")
		audio.sfx_levels[level] = 1.0
		audio.call(setter, true)
		expect(player.stream is AudioStreamWAV and player.playing, "Cached audio must start: " + key)
		var full_db := player.volume_db
		audio.sfx_levels[level] = 0.25
		audio._refresh_active_sfx_levels()
		expect(player.volume_db < full_db - 5.0, "Live volume control must affect cached audio: " + key)
		audio.call(setter, false)
		expect(not player.playing, "Cached audio must stop: " + key)
	for failure in failures:
		push_error(failure)
	print("PERFORMANCE_SETTINGS_SMOKE_OK" if failures.is_empty() else "PERFORMANCE_SETTINGS_SMOKE_FAILED")
	game.queue_free()
	for i in 5:
		await process_frame
	quit(0 if failures.is_empty() else 1)
