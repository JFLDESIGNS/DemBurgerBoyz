extends SceneTree
var elapsed := 0.0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	create_timer(120).timeout.connect(func(): push_error("BOOT_ACTUAL_FLOW_TIMEOUT"); quit(1))
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	var intro = load("res://scenes/boot_intro.tscn").instantiate()
	root.add_child(intro)
	current_scene = intro
	var boot_started := Time.get_ticks_msec()
	await create_timer(14.0 if "--warm-skip" in OS.get_cmdline_user_args() else 1.0).timeout
	var music = root.get_node("IntroBootMusic")
	var player: AudioStreamPlayer = music.player
	var song_position := player.get_playback_position()
	var skipped := Time.get_ticks_msec()
	intro.skip_intro()
	while current_scene == intro or current_scene == null:
		await process_frame
	for f in 12: await process_frame
	var game = current_scene
	assert(game.scene_file_path == "res://scenes/main.tscn")
	assert(game.start_overlay.visible)
	assert(music.mode == "title" and player.playing and player == music.player)
	assert(player.get_playback_position() >= song_position - 0.05)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var output := OS.get_environment("BURGER_PROBE_OUTPUT")
		if output.is_empty():output = ProjectSettings.globalize_path("res://build/elbow_ticket_fix")
		root.get_texture().get_image().save_png(output.path_join("menu_after_skip.png"))
	print("BOOT_TIMING skip_to_menu_ms=",Time.get_ticks_msec()-skipped," total_ms=",Time.get_ticks_msec()-boot_started)
	print("BOOT_ACTUAL_FLOW_OK")
	music.stop()
	current_scene = null
	game.queue_free()
	for f in 8: await process_frame
	quit()
