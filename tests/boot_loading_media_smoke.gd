extends SceneTree
var failures: Array[String] = []
var visual := false
var output := ""
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func _initialize() -> void: call_deferred("run")
func shot(file: String) -> void:
	if not visual: return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(file + ".png"))
func run() -> void:
	create_timer(90).timeout.connect(func(): push_error("BOOT_MEDIA_TIMEOUT"); quit(1))
	visual = "--visual" in OS.get_cmdline_user_args()
	output = OS.get_environment("BURGER_PROBE_OUTPUT")
	if output.is_empty(): output = ProjectSettings.globalize_path("res://build/elbow_ticket_fix")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	var music = root.get_node("IntroBootMusic")
	var intro = load("res://scenes/boot_intro.tscn").instantiate()
	root.add_child(intro)
	intro.set_process(false)
	expect(intro.cinematic.video.stream != null, "Intro video is missing")
	expect(intro.cinematic.video.is_playing(), "Intro must start playing after the logo")
	expect(music.mode == "title" and music.is_playing(), "Burger Time must start with the intro")
	expect(absf(music.player.stream.get_length() - 216.4) < 0.2, "Wrong title song")
	await create_timer(0.8).timeout
	await shot("intro_video")
	var player: AudioStreamPlayer = music.player
	var before_skip: float = player.get_playback_position()
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	intro._unhandled_input(space)
	expect(intro._requested_menu, "Space must skip the intro")
	expect(music.player == player and player.playing, "Skipping the intro must preserve the music player")
	music.ensure_playing_on_title()
	expect(player.get_playback_position() >= before_skip - 0.05, "Menu entry restarted Burger Time")
	var menu_scene := ResourceLoader.load_threaded_get(intro.MENU) as PackedScene
	intro.queue_free()
	await process_frame
	var game = menu_scene.instantiate()
	game.set_script(load(get_script().resource_path.get_base_dir().path_join("boot_media_harness.gd")))
	root.add_child(game)
	game._build_gameplay_loading_screen()
	expect(not game._gameplay_load_overlay.visible, "Loading video must initially stay hidden")
	await game._loading_video.prewarm()
	expect(game._loading_video.video.paused, "Menu must retain a decoded loading-video frame")
	game._show_gameplay_loading_screen()
	expect(not game._loading_video.video.paused, "Loading must resume the prewarmed decoder")
	expect(game._gameplay_load_overlay.modulate.is_equal_approx(Color(0.64,0.64,0.64,1)), "Entire loading screen must be another 20 percent darker")
	expect(music.mode == "loading" and player.playing, "Loading must switch to considerburger")
	expect(game._loading_video.video.stream != null and game._loading_video.video.is_playing(), "Loading video is missing or stopped")
	expect(game._loading_video.looping, "Loading video must loop")
	expect(absf(player.stream.get_length() - 47.84) < 0.2, "Wrong loading song")
	await create_timer(3.0).timeout
	await shot("loading_video")
	var decoder_loops := [0]
	game._loading_video.video.finished.connect(func(): decoder_loops[0] += 1)
	# Exercise the real decoder crossing the 20-second end, including music continuity.
	if visual:
		await create_timer(20.0).timeout
		expect(decoder_loops[0] >= 1, "Loading movie did not reach and loop past its end")
		expect(game._loading_video.video.is_playing(), "Loading movie did not restart")
		expect(player.get_playback_position() > 19.0, "Video loop restarted the loading song")
		await shot("loading_video_loop")
	else:
		game._loading_video._on_finished()
		expect(game._loading_video.video.is_playing(), "Loading loop did not restart")
	game._hide_gameplay_loading_screen()
	expect(not game._loading_video.video.is_playing(), "Hidden loading movie kept decoding")
	expect(not music.is_playing(), "Loading music must stop before gameplay")
	music.ensure_playing_on_title()
	expect(music.mode == "title" and music.is_playing(), "Returning to menu must restore Burger Time")
	music.stop()
	game.queue_free()
	await process_frame
	if failures.is_empty(): print("BOOT_LOADING_MEDIA_OK")
	quit(0 if failures.is_empty() else 1)
