## Lightweight first scene after the engine splash. Preload the menu behind the intro.
extends Control
const Video = preload("res://scripts/cinematic_video.gd")
const MENU := "res://scenes/main.tscn"
var cinematic: Control
var skip_button: Button
var _requested_menu := false
var _changing := false
var _load_error := OK
var _menu: Node
var _preparing := false
var _previous_disable_3d := false
var _menu_script: Script

func _ready() -> void:
	cinematic = Video.new()
	cinematic.video_path = "res://assets/cinematics/burger_pals_intro.ogv"
	cinematic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cinematic)
	cinematic.finished.connect(skip_intro)
	skip_button = Button.new()
	skip_button.name = "SkipIntro"
	skip_button.text = "Skip intro  [Space / Esc]"
	skip_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	skip_button.offset_left = -280
	skip_button.offset_top = -72
	skip_button.offset_right = -24
	skip_button.offset_bottom = -24
	skip_button.add_theme_font_size_override("font_size", 20)
	add_child(skip_button)
	skip_button.pressed.connect(skip_intro)
	# Resolve script preloads on the main thread before the scene loader starts.
	# Exported GDScript can otherwise race shared font/model/shader dependencies,
	# reporting bundled resources as missing even with sub-threads disabled.
	_menu_script = load("res://scripts/game.gd") as Script
	_load_error = ResourceLoader.load_threaded_request(MENU, "PackedScene", false)
	# Go straight to the movie; keep the company card disabled for now.
	cinematic.play()
	IntroBootMusic.ensure_playing_on_title()

	if cinematic.video.stream == null: skip_intro()
	if OS.get_cmdline_user_args().has("--verify-gameplay"):
		skip_intro()
		get_tree().create_timer(180.0).timeout.connect(func():
			push_error("EXPORTED_GAMEPLAY_TIMEOUT")
			get_tree().quit(1)
		)

func skip_intro() -> void:
	if _requested_menu: return
	_requested_menu = true
	IntroBootMusic.play_intro_voice()
	skip_button.disabled = true
	skip_button.text = "Opening menu..."

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	var joy := event as InputEventJoypadButton
	if (key != null and key.pressed and not key.echo and key.keycode in [KEY_SPACE, KEY_ESCAPE, KEY_ENTER]) or (joy != null and joy.pressed and joy.button_index in [JOY_BUTTON_A, JOY_BUTTON_START]):
		skip_intro()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if _changing: return
	var status := ResourceLoader.load_threaded_get_status(MENU)
	if not _preparing and status == ResourceLoader.THREAD_LOAD_LOADED and _requested_menu:
		_preparing = true
		_prepare_menu.call_deferred()
	elif _load_error != OK or status == ResourceLoader.THREAD_LOAD_FAILED:
		_changing = true
		push_error("Could not load the main menu")
		skip_button.text = "Could not open menu. Please restart."
	if _requested_menu and is_instance_valid(_menu) and _menu.get("menu_ready"):
		_changing = true
		_reveal_menu.call_deferred()

func _prepare_menu() -> void:
	var scene := ResourceLoader.load_threaded_get(MENU) as PackedScene
	_menu = scene.instantiate()
	_menu.process_mode = Node.PROCESS_MODE_DISABLED
	_menu.get_node("UI").hide()
	_previous_disable_3d = get_viewport().disable_3d
	get_viewport().disable_3d = true
	get_tree().root.add_child(_menu)

func _reveal_menu() -> void:
	get_viewport().disable_3d = _previous_disable_3d
	_menu.process_mode = Node.PROCESS_MODE_INHERIT
	_menu.get_node("UI").show()
	get_tree().current_scene = _menu
	cinematic.stop()
	if OS.get_cmdline_user_args().has("--verify-gameplay"):
		await _menu._run_comprehensive_gameplay_load()
		_menu._start_game_immediate(false)
		for frame in 90: await get_tree().process_frame
		if not _menu.playing or not _menu._kitchen_ready:
			push_error("EXPORTED_GAMEPLAY_FAILED")
			get_tree().quit(1)
		else:
			print("EXPORTED_GAMEPLAY_OK preparation_ms=", _menu.get_meta("loading_item_preparation_ms",0), " movies=",_menu.get_meta("loading_movie_count",0))
			get_tree().quit()
	# Music lives in its autoload; revealing the prepared menu never restarts it.
	queue_free()
