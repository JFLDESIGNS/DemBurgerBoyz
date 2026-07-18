## In-game kitchen wall browser — YouTube / podcasts while you cook.
extends Control

signal closed
signal navigated(url: String, title: String)

const UiFontsScript := preload("res://scripts/ui_fonts.gd")

const HOME_URL := "kitchen://home"
const BOOKMARKS: Array[Dictionary] = [
	{"label": "YouTube", "url": "https://www.youtube.com", "title": "YouTube"},
	{"label": "Lo-fi Beats", "url": "https://www.youtube.com/watch?v=jfKfPfyJRdk", "title": "Lo-fi Hip Hop Radio"},
	{"label": "Podcasts", "url": "https://www.youtube.com/podcasts", "title": "YouTube Podcasts"},
	{"label": "Cooking", "url": "https://www.youtube.com/results?search_query=cooking+podcast", "title": "Cooking Podcasts"},
	{"label": "News Radio", "url": "https://www.youtube.com/results?search_query=news+radio+live", "title": "News Radio Live"},
]

var current_url: String = HOME_URL
var current_title: String = "Kitchen Home"
var history: Array[String] = []
var history_i: int = -1

var _url_edit: LineEdit
var _page: Control
var _status: Label
var _tv_mirror: Callable = Callable() ## optional: sync 3D TV screen


func setup(tv_mirror: Callable = Callable()) -> void:
	_tv_mirror = tv_mirror
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 80
	_build_ui()
	_go_home(false)


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.05, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_request_close()
	)
	add_child(dim)

	var frame := PanelContainer.new()
	frame.name = "BrowserFrame"
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.custom_minimum_size = Vector2(920, 560)
	frame.offset_left = -460
	frame.offset_right = 460
	frame.offset_top = -280
	frame.offset_bottom = 280
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.13, 0.16, 0.98)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.35, 0.38, 0.45)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 10
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 16
	frame.add_theme_stylebox_override("panel", sb)
	add_child(frame)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	frame.add_child(root)

	## Title bar
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	root.add_child(title_row)
	var title := Label.new()
	title.text = "Kitchen TV · Browser"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiFontsScript.apply_label(title, true, 16)
	title.add_theme_color_override("font_color", Color(0.95, 0.92, 0.82))
	title_row.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(36, 28)
	UiFontsScript.apply_button(close_btn, true, 14)
	close_btn.pressed.connect(_request_close)
	title_row.add_child(close_btn)

	## Nav + URL
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 6)
	root.add_child(nav)
	for item in [
		{"t": "←", "cb": _go_back},
		{"t": "→", "cb": _go_forward},
		{"t": "⌂", "cb": func(): _go_home(true)},
	]:
		var b := Button.new()
		b.text = str(item["t"])
		b.custom_minimum_size = Vector2(36, 30)
		UiFontsScript.apply_button(b, true, 13)
		b.pressed.connect(item["cb"])
		nav.add_child(b)

	_url_edit = LineEdit.new()
	_url_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_url_edit.placeholder_text = "Search YouTube or paste a link…"
	_url_edit.text_submitted.connect(func(t: String): _navigate(t, true))
	nav.add_child(_url_edit)
	var go := Button.new()
	go.text = "Go"
	go.custom_minimum_size = Vector2(52, 30)
	UiFontsScript.apply_button(go, true, 13)
	go.pressed.connect(func(): _navigate(_url_edit.text, true))
	nav.add_child(go)

	## Bookmarks
	var marks := HBoxContainer.new()
	marks.add_theme_constant_override("separation", 6)
	root.add_child(marks)
	for bm in BOOKMARKS:
		var mb := Button.new()
		mb.text = str(bm["label"])
		mb.custom_minimum_size = Vector2(0, 28)
		UiFontsScript.apply_button(mb, true, 11)
		var u: String = str(bm["url"])
		var ti: String = str(bm["title"])
		mb.pressed.connect(func(): _open_bookmark(u, ti))
		marks.add_child(mb)

	## Page body
	var page_wrap := PanelContainer.new()
	page_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.08, 0.09, 0.11, 1.0)
	psb.set_corner_radius_all(8)
	psb.content_margin_left = 14
	psb.content_margin_right = 14
	psb.content_margin_top = 12
	psb.content_margin_bottom = 12
	page_wrap.add_theme_stylebox_override("panel", psb)
	root.add_child(page_wrap)

	_page = VBoxContainer.new()
	_page.add_theme_constant_override("separation", 10)
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_wrap.add_child(_page)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiFontsScript.apply_label(_status, false, 11)
	_status.add_theme_color_override("font_color", Color(0.55, 0.62, 0.7))
	root.add_child(_status)


func _request_close() -> void:
	closed.emit()


func _go_home(add_hist: bool) -> void:
	_navigate(HOME_URL, add_hist)


func _go_back() -> void:
	if history_i <= 0:
		return
	history_i -= 1
	_navigate(history[history_i], false)


func _go_forward() -> void:
	if history_i < 0 or history_i >= history.size() - 1:
		return
	history_i += 1
	_navigate(history[history_i], false)


func _open_bookmark(url: String, title: String) -> void:
	current_title = title
	_navigate(url, true)


func _normalize_url(raw: String) -> String:
	var t := raw.strip_edges()
	if t == "" or t.to_lower() == "home" or t.begins_with("kitchen://"):
		return HOME_URL
	if t.begins_with("http://") or t.begins_with("https://"):
		return t
	## Bare search → YouTube search
	if not t.contains(".") or t.contains(" "):
		return "https://www.youtube.com/results?search_query=%s" % t.uri_encode()
	return "https://%s" % t


func _navigate(raw: String, add_hist: bool) -> void:
	var url := _normalize_url(raw)
	if add_hist:
		if history_i >= 0 and history_i < history.size() - 1:
			history = history.slice(0, history_i + 1)
		if history.is_empty() or history[history.size() - 1] != url:
			history.append(url)
			history_i = history.size() - 1
		else:
			history_i = history.size() - 1
	current_url = url
	_url_edit.text = "" if url == HOME_URL else url
	if url == HOME_URL:
		current_title = "Kitchen Home"
		_show_home()
		_status.text = "Pick a station — audio opens beside the game so you can keep cooking."
	else:
		if current_title == "Kitchen Home" or current_title == "":
			current_title = _guess_title(url)
		_show_streaming(url, current_title)
		_status.text = "Streaming in your system browser (Edge app / default). Game keeps running."
		_launch_external(url)
	navigated.emit(current_url, current_title)
	if _tv_mirror.is_valid():
		_tv_mirror.call(current_url, current_title)


func _guess_title(url: String) -> String:
	if url.contains("jfKfPfyJRdk"):
		return "Lo-fi Hip Hop Radio"
	if url.contains("podcast"):
		return "Podcasts"
	if url.contains("youtube.com"):
		return "YouTube"
	return "Browser"


func _clear_page() -> void:
	for c in _page.get_children():
		c.queue_free()


func _show_home() -> void:
	_clear_page()
	var head := Label.new()
	head.text = "What are we putting on the kitchen TV?"
	UiFontsScript.apply_label(head, true, 20)
	head.add_theme_color_override("font_color", Color(1.0, 0.92, 0.75))
	_page.add_child(head)
	var sub := Label.new()
	sub.text = "YouTube, lo-fi, or a podcast — opens as a real browser stream while you smash burgers."
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiFontsScript.apply_label(sub, false, 13)
	sub.add_theme_color_override("font_color", Color(0.7, 0.75, 0.82))
	_page.add_child(sub)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.add_child(grid)

	for bm in BOOKMARKS:
		var card := Button.new()
		card.text = "%s\n%s" % [str(bm["label"]), str(bm["title"])]
		card.custom_minimum_size = Vector2(280, 86)
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		UiFontsScript.apply_button(card, true, 13)
		var u: String = str(bm["url"])
		var ti: String = str(bm["title"])
		card.pressed.connect(func(): _open_bookmark(u, ti))
		grid.add_child(card)


func _show_streaming(url: String, title: String) -> void:
	_clear_page()
	var head := Label.new()
	head.text = "▶  %s" % title
	UiFontsScript.apply_label(head, true, 22)
	head.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	_page.add_child(head)

	var link := Label.new()
	link.text = url
	link.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiFontsScript.apply_label(link, false, 11)
	link.add_theme_color_override("font_color", Color(0.55, 0.75, 1.0))
	_page.add_child(link)

	var note := Label.new()
	note.text = "A real browser window opened for video/audio (YouTube needs a full browser). Keep this game focused and cook — the stream keeps playing in the background."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiFontsScript.apply_label(note, false, 13)
	note.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	_page.add_child(note)

	## Fake equalizer vibe on the in-game TV.
	var eq := HBoxContainer.new()
	eq.add_theme_constant_override("separation", 6)
	eq.alignment = BoxContainer.ALIGNMENT_CENTER
	_page.add_child(eq)
	for i in 12:
		var bar := ColorRect.new()
		bar.custom_minimum_size = Vector2(14, 20 + (i * 7) % 48)
		bar.color = Color(0.3, 0.85, 0.55, 0.9)
		eq.add_child(bar)
		var tw := create_tween()
		tw.set_loops()
		var h0 := bar.custom_minimum_size.y
		tw.tween_property(bar, "custom_minimum_size:y", h0 + 28.0, 0.25 + i * 0.03).set_trans(Tween.TRANS_SINE)
		tw.tween_property(bar, "custom_minimum_size:y", h0, 0.25 + i * 0.03).set_trans(Tween.TRANS_SINE)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_page.add_child(row)
	var reopen := Button.new()
	reopen.text = "Open / Focus Stream"
	reopen.custom_minimum_size = Vector2(180, 36)
	UiFontsScript.apply_button(reopen, true, 13)
	reopen.pressed.connect(func(): _launch_external(url))
	row.add_child(reopen)
	var home := Button.new()
	home.text = "Back to Home"
	home.custom_minimum_size = Vector2(140, 36)
	UiFontsScript.apply_button(home, true, 13)
	home.pressed.connect(func(): _go_home(true))
	row.add_child(home)


func _launch_external(url: String) -> void:
	## Prefer Edge app-mode so it feels like a TV window beside the game.
	var candidates: Array[String] = [
		"C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
		"C:/Program Files/Microsoft/Edge/Application/msedge.exe",
		"C:/Program Files/Google/Chrome/Application/chrome.exe",
		"C:/Program Files (x86)/Google/Chrome/Application/chrome.exe",
	]
	for path in candidates:
		if FileAccess.file_exists(path):
			OS.create_process(path, ["--app=%s" % url, "--new-window"])
			return
	OS.shell_open(url)
