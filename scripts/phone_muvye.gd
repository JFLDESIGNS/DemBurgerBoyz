extends Control

signal cinema_mode_changed(enabled: bool)

const UiFontsScript := preload("res://scripts/ui_fonts.gd")

const MOVIES: Array[Dictionary] = [
	{
		"title": "The Restaurant Operator",
		"year": "1946",
		"video": "res://assets/video/restaurant_operator_240p.ogv",
		"art": "res://assets/video/box_art/restaurant_operator.png",
	},
	{
		"title": "Pastry Town Wedding",
		"year": "1934",
		"video": "res://assets/video/pastry_town_wedding_240p.ogv",
		"art": "res://assets/video/box_art/pastry_town_wedding.png",
	},
	{
		"title": "The Fresh Vegetable Mystery",
		"year": "1939",
		"video": "res://assets/video/the_fresh_vegetable_mystery_240p.ogv",
		"art": "res://assets/video/box_art/the_fresh_vegetable_mystery.png",
	},
]

var _video: VideoStreamPlayer
var _title: Label
var _year: Label
var _poster: TextureRect
var _play_button: Button
var _seek: HSlider
var _time: Label
var _volume: HSlider
var _mute_button: Button
var _loop_button: CheckButton
var _cinema_button: Button
var _library_view: Control
var _player_view: Control
var _player_chrome: Control
var _browse_index: int = 0
var _current_movie: int = -1
var _dragging_seek: bool = false
var _active: bool = false
var _resume_when_active: bool = false
var _cinema: bool = false
var _volume_db: float = 18.0
var _video_frame: AspectRatioContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	## Stay in the phone VBox under the nav bar. FULL_RECT overlays the Back button.
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_ui()
	_show_library()
	set_process(true)


func set_active(active: bool) -> void:
	_active = active
	if not active:
		set_cinema(false)
	if _video == null:
		return
	if active:
		if _resume_when_active and _video.is_playing():
			_video.paused = false
	else:
		_resume_when_active = _video.is_playing() and not _video.paused
		if _video.is_playing():
			_video.paused = true
	_refresh_play_button()


func set_cinema(enabled: bool) -> void:
	if _cinema == enabled:
		if enabled:
			_apply_cinema_layout()
		return
	_cinema = enabled
	_apply_cinema_layout()
	cinema_mode_changed.emit(_cinema)


func handle_key(key: InputEventKey) -> bool:
	if not _active or not key.pressed or key.echo:
		return false
	match key.keycode:
		KEY_ESCAPE:
			if _cinema:
				set_cinema(false)
				return true
			if _player_view.visible:
				_show_library()
				return true
		KEY_F:
			if _player_view.visible:
				set_cinema(not _cinema)
				return true
		KEY_SPACE:
			if _library_view.visible:
				_play_movie(_browse_index)
			else:
				_toggle_play_pause()
			return true
		KEY_LEFT:
			if _library_view.visible:
				_browse(-1)
			else:
				_seek_relative(-10.0)
			return true
		KEY_RIGHT:
			if _library_view.visible:
				_browse(1)
			else:
				_seek_relative(10.0)
			return true
		KEY_M:
			_toggle_mute()
			return true
		KEY_1, KEY_2, KEY_3:
			_play_movie(int(key.keycode - KEY_1))
			return true
	return false


func _process(_delta: float) -> void:
	if not _active or _video == null or _current_movie < 0 or not _player_view.visible:
		return
	var length: float = _video.get_stream_length()
	var position: float = _video.get_stream_position()
	if length > 0.0:
		_seek.max_value = length
		if not _dragging_seek:
			_seek.set_value_no_signal(position)
	_time.text = "%s / %s" % [_format_time(position), _format_time(length)]
	_refresh_play_button()
	_sync_video_aspect()


func _build_ui() -> void:
	_library_view = VBoxContainer.new()
	_library_view.name = "MuvyeLibrary"
	_library_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_library_view.add_theme_constant_override("separation", 6)
	add_child(_library_view)

	var picker := HBoxContainer.new()
	picker.alignment = BoxContainer.ALIGNMENT_CENTER
	picker.add_theme_constant_override("separation", 4)
	picker.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_library_view.add_child(picker)

	var prev_title := _round_button("<", 28, 120)
	prev_title.tooltip_text = "Previous title"
	prev_title.pressed.connect(func() -> void: _browse(-1))
	picker.add_child(prev_title)

	var poster_frame := PanelContainer.new()
	poster_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	poster_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var poster_style := StyleBoxFlat.new()
	poster_style.bg_color = Color(0.02, 0.02, 0.03, 1.0)
	poster_style.border_color = Color("FFD45A")
	poster_style.set_border_width_all(2)
	poster_style.set_corner_radius_all(8)
	poster_style.content_margin_left = 4
	poster_style.content_margin_right = 4
	poster_style.content_margin_top = 4
	poster_style.content_margin_bottom = 4
	poster_frame.add_theme_stylebox_override("panel", poster_style)
	picker.add_child(poster_frame)

	var poster_button := Button.new()
	poster_button.name = "MuvyeFeaturedPoster"
	poster_button.flat = true
	poster_button.focus_mode = Control.FOCUS_NONE
	poster_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	poster_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	poster_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	poster_button.pressed.connect(func() -> void: _play_movie(_browse_index))
	poster_frame.add_child(poster_button)
	_poster = TextureRect.new()
	_poster.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_poster.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_poster.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_poster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	poster_button.add_child(_poster)

	var next_title := _round_button(">", 28, 120)
	next_title.tooltip_text = "Next title"
	next_title.pressed.connect(func() -> void: _browse(1))
	picker.add_child(next_title)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.add_theme_color_override("font_color", Color("FFF3C4"))
	UiFontsScript.apply_luckiest_label(_title, 16)
	_library_view.add_child(_title)

	_year = Label.new()
	_year.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_year.add_theme_color_override("font_color", Color(0.82, 0.86, 0.94, 1.0))
	UiFontsScript.apply_label(_year, false, 11)
	_library_view.add_child(_year)

	var watch := _round_button("WATCH", 0, 34)
	watch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	watch.pressed.connect(func() -> void: _play_movie(_browse_index))
	_library_view.add_child(watch)

	_player_view = VBoxContainer.new()
	_player_view.name = "MuvyePlayerView"
	_player_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_player_view.add_theme_constant_override("separation", 4)
	_player_view.visible = false
	add_child(_player_view)

	var screen := PanelContainer.new()
	screen.name = "MuvyePhoneScreen"
	screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var screen_style := StyleBoxFlat.new()
	screen_style.bg_color = Color.BLACK
	screen_style.set_corner_radius_all(4)
	screen.add_theme_stylebox_override("panel", screen_style)
	_player_view.add_child(screen)
	_video_frame = AspectRatioContainer.new()
	_video_frame.name = "MuvyeAspect"
	_video_frame.ratio = 4.0 / 3.0
	_video_frame.stretch_mode = AspectRatioContainer.STRETCH_FIT
	_video_frame.alignment_horizontal = AspectRatioContainer.ALIGNMENT_CENTER
	_video_frame.alignment_vertical = AspectRatioContainer.ALIGNMENT_CENTER
	_video_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_video_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen.add_child(_video_frame)
	_video = VideoStreamPlayer.new()
	_video.name = "PhoneMuvyePlayer"
	_video.expand = true
	_video.volume_db = _volume_db
	_video.finished.connect(_on_finished)
	_video_frame.add_child(_video)

	_player_chrome = VBoxContainer.new()
	_player_chrome.name = "MuvyeChrome"
	_player_chrome.add_theme_constant_override("separation", 3)
	_player_view.add_child(_player_chrome)

	var timeline := HBoxContainer.new()
	timeline.add_theme_constant_override("separation", 4)
	_player_chrome.add_child(timeline)
	_seek = HSlider.new()
	_seek.min_value = 0.0
	_seek.max_value = 1.0
	_seek.step = 0.05
	_seek.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seek.drag_started.connect(func() -> void: _dragging_seek = true)
	_seek.drag_ended.connect(_on_seek_drag_ended)
	timeline.add_child(_seek)
	_time = Label.new()
	_time.text = "0:00 / 0:00"
	_time.custom_minimum_size.x = 72
	_time.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_time.add_theme_color_override("font_color", Color(0.88, 0.91, 0.97, 1.0))
	UiFontsScript.apply_label(_time, false, 10)
	timeline.add_child(_time)

	var transport := HBoxContainer.new()
	transport.alignment = BoxContainer.ALIGNMENT_CENTER
	transport.add_theme_constant_override("separation", 3)
	_player_chrome.add_child(transport)
	var previous := _round_button("<", 28, 26)
	previous.tooltip_text = "Previous movie"
	previous.pressed.connect(func() -> void: _change_movie(-1))
	transport.add_child(previous)
	_play_button = _round_button("PLAY", 52, 26)
	_play_button.pressed.connect(_toggle_play_pause)
	transport.add_child(_play_button)
	var titles := _round_button("LIST", 40, 26)
	titles.tooltip_text = "Back to titles"
	titles.pressed.connect(_show_library)
	transport.add_child(titles)
	var next := _round_button(">", 28, 26)
	next.tooltip_text = "Next movie"
	next.pressed.connect(func() -> void: _change_movie(1))
	transport.add_child(next)
	_cinema_button = _round_button("FULL", 48, 26)
	_cinema_button.tooltip_text = "Fill the phone screen with the film"
	_cinema_button.pressed.connect(func() -> void: set_cinema(not _cinema))
	transport.add_child(_cinema_button)

	var audio := HBoxContainer.new()
	audio.alignment = BoxContainer.ALIGNMENT_CENTER
	audio.add_theme_constant_override("separation", 3)
	_player_chrome.add_child(audio)
	var vol_label := Label.new()
	vol_label.text = "VOL"
	UiFontsScript.apply_label(vol_label, true, 9)
	vol_label.add_theme_color_override("font_color", Color(0.82, 0.87, 0.94, 1.0))
	audio.add_child(vol_label)
	_volume = HSlider.new()
	_volume.min_value = -24.0
	_volume.max_value = 24.0
	_volume.step = 1.0
	_volume.value = _volume_db
	_volume.custom_minimum_size.x = 58
	_volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_volume.value_changed.connect(_on_volume_changed)
	audio.add_child(_volume)
	_mute_button = _round_button("MUTE", 40, 24)
	_mute_button.pressed.connect(_toggle_mute)
	audio.add_child(_mute_button)
	_loop_button = CheckButton.new()
	_loop_button.text = "LOOP"
	_loop_button.focus_mode = Control.FOCUS_NONE
	_loop_button.toggled.connect(func(enabled: bool) -> void: _video.loop = enabled)
	UiFontsScript.apply_button(_loop_button, false, 9)
	audio.add_child(_loop_button)

	_refresh_library()


func _show_library() -> void:
	set_cinema(false)
	if _video != null:
		_video.stop()
		_video.paused = false
	_resume_when_active = false
	_current_movie = -1
	if _library_view != null:
		_library_view.visible = true
	if _player_view != null:
		_player_view.visible = false
	_refresh_library()


func _browse(direction: int) -> void:
	_browse_index = posmod(_browse_index + direction, MOVIES.size())
	_refresh_library()


func _refresh_library() -> void:
	if _browse_index < 0 or _browse_index >= MOVIES.size():
		return
	var movie: Dictionary = MOVIES[_browse_index]
	if _poster != null:
		_poster.texture = load(str(movie["art"])) as Texture2D
	if _title != null:
		_title.text = str(movie["title"]).to_upper()
	if _year != null:
		_year.text = str(movie["year"])


func _play_movie(index: int) -> void:
	if index < 0 or index >= MOVIES.size():
		return
	var stream := load(str(MOVIES[index]["video"])) as VideoStream
	if stream == null:
		if _title != null:
			_title.text = "VIDEO MISSING"
		return
	_browse_index = index
	_current_movie = index
	_library_view.visible = false
	_player_view.visible = true
	_video.stop()
	_video.stream = stream
	_video.loop = _loop_button.button_pressed
	_video.volume_db = _volume_db
	_video.paused = false
	_video.play()
	_resume_when_active = true
	_sync_video_aspect()
	_refresh_play_button()
	_apply_cinema_layout()


func _toggle_play_pause() -> void:
	if _current_movie < 0:
		_play_movie(_browse_index)
		return
	if not _video.is_playing():
		_video.play()
		_video.paused = false
	else:
		_video.paused = not _video.paused
	_resume_when_active = _video.is_playing() and not _video.paused
	_refresh_play_button()


func _change_movie(direction: int) -> void:
	var next_index: int = 0 if _current_movie < 0 else posmod(_current_movie + direction, MOVIES.size())
	_play_movie(next_index)


func _seek_relative(seconds: float) -> void:
	if _current_movie < 0:
		return
	var length: float = _video.get_stream_length()
	_video.stream_position = clampf(_video.stream_position + seconds, 0.0, length)


func _on_seek_drag_ended(value_changed: bool) -> void:
	_dragging_seek = false
	if value_changed and _current_movie >= 0:
		_video.stream_position = _seek.value


func _on_volume_changed(value: float) -> void:
	_volume_db = value
	_video.volume_db = value
	_mute_button.text = "MUTE"


func _toggle_mute() -> void:
	if _video.volume_db <= -79.0:
		_video.volume_db = _volume_db
		_volume.set_value_no_signal(_volume_db)
		_mute_button.text = "MUTE"
	else:
		_volume_db = _video.volume_db
		_video.volume_db = -80.0
		_mute_button.text = "ON"


func _on_finished() -> void:
	if _loop_button.button_pressed:
		_video.play()
	else:
		_resume_when_active = false
		_refresh_play_button()


func _refresh_play_button() -> void:
	if _play_button == null:
		return
	_play_button.text = "PAUSE" if _video != null and _video.is_playing() and not _video.paused else "PLAY"


func _apply_cinema_layout() -> void:
	if _cinema_button != null:
		_cinema_button.text = "EXIT" if _cinema else "FULL"
	if _player_chrome != null:
		_player_chrome.visible = true


func _sync_video_aspect() -> void:
	if _video == null or _video_frame == null:
		return
	var tex: Texture2D = _video.get_video_texture()
	if tex == null:
		return
	var video_h: int = tex.get_height()
	if video_h <= 0:
		return
	_video_frame.ratio = float(tex.get_width()) / float(video_h)


func _round_button(caption: String, width: float, height: float) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(width, height)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UiFontsScript.apply_button(button, false, 10)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.18, 0.24, 1.0)
	style.border_color = Color(0.42, 0.48, 0.58, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.24, 0.22, 0.12, 1.0)
	hover.border_color = Color("FFD45A")
	button.add_theme_stylebox_override("hover", hover)
	var pressed := style.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.32, 0.22, 0.08, 1.0)
	button.add_theme_stylebox_override("pressed", pressed)
	return button


func _format_time(seconds: float) -> String:
	if seconds < 0.0 or is_nan(seconds) or is_inf(seconds):
		return "0:00"
	var total: int = int(seconds)
	return "%d:%02d" % [total / 60, total % 60]
