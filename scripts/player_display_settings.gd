extends VBoxContainer
## Display previews never overwrite the last confirmed configuration.

const SAVE_PATH := "user://display_settings.cfg"
const MODES := [Window.MODE_WINDOWED, Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]
const FPS_LIMITS := [30, 60, 120, 144, 0]
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]
const CONFIRM_SECONDS := 15

var menu: CanvasLayer
var mode_choice: OptionButton
var resolution_choice: OptionButton
var fps_choice: OptionButton
var vsync: CheckButton
var resolution_hint: Label
var apply_button: Button
var confirmation: Control
var countdown_label: Label
var keep_button: Button
var countdown: Timer
var deadline_ms := 0
var saved_mode := 0
var windowed_size := Vector2i(1280, 720)
var previous: Dictionary = {}

func setup(settings_menu: CanvasLayer) -> void:
	menu = settings_menu
	add_theme_constant_override("separation", 6)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_choice = choice("Display mode")
	for title in ["Windowed", "Borderless", "Fullscreen"]: mode_choice.add_item(title)
	mode_choice.item_selected.connect(func(_index: int): update_resolution_hint())
	resolution_choice = choice("Window resolution")
	resolution_hint = menu.label("", 12)
	resolution_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(resolution_hint)
	apply_button = Button.new()
	apply_button.text = "APPLY DISPLAY"
	menu.style_button(apply_button)
	apply_button.pressed.connect(apply_changes)
	add_child(apply_button)
	fps_choice = choice("FPS limit")
	for limit in FPS_LIMITS: fps_choice.add_item("Unlimited" if limit == 0 else "%d FPS" % limit)
	fps_choice.item_selected.connect(func(index: int):
		Engine.max_fps = FPS_LIMITS[index]
		save_display()
	)
	vsync = menu.check(self, "VSync", func(on: bool):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if on else DisplayServer.VSYNC_DISABLED)
		save_display()
	)
	var hint: Label = menu.label("VSync may limit FPS to your display's refresh rate.", 12)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)
	build_confirmation()
	load_display()
	refresh()

func choice(title: String) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	var caption: Label = menu.label(title, 17)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(caption)
	var result := OptionButton.new()
	result.custom_minimum_size = Vector2(228, 40)
	menu.Fonts.apply_button(result, false, 16)
	for state in ["normal", "hover", "pressed"]:
		result.add_theme_stylebox_override(state, menu.box(menu.GOLD.lightened(0.25) if state == "hover" else menu.GOLD, menu.GOLD.darkened(0.2), 8, 3))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		result.add_theme_color_override(state, menu.INK)
	var popup := result.get_popup()
	popup.add_theme_font_override("font", menu.Fonts.body)
	popup.add_theme_font_size_override("font_size", 16)
	popup.add_theme_stylebox_override("panel", menu.box(menu.CREAM, menu.GOLD, 8, 3))
	popup.add_theme_stylebox_override("hover", menu.box(menu.TEAL, menu.TEAL, 4, 0))
	popup.add_theme_color_override("font_color", menu.INK)
	popup.add_theme_color_override("font_hover_color", menu.CREAM)
	row.add_child(result)
	return result

func refresh() -> void:
	if has_pending(): return
	saved_mode = mode_index()
	if get_window().mode == Window.MODE_WINDOWED:
		windowed_size = get_window().size
	windowed_size = safe_window_size(windowed_size)
	mode_choice.select(saved_mode)
	resolution_choice.clear()
	var sizes: Array[Vector2i] = []
	for size in RESOLUTIONS:
		if safe_window_size(size) == size: sizes.append(size)
	if not sizes.has(windowed_size): sizes.append(windowed_size)
	for size in sizes:
		resolution_choice.add_item("%d × %d" % [size.x, size.y])
		resolution_choice.set_item_metadata(resolution_choice.item_count - 1, size)
		if size == windowed_size: resolution_choice.select(resolution_choice.item_count - 1)
	fps_choice.select(maxi(0, FPS_LIMITS.find(Engine.max_fps)))
	vsync.set_pressed_no_signal(DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED)
	update_resolution_hint()

func update_resolution_hint() -> void:
	resolution_choice.disabled = mode_choice.selected != 0
	var native := DisplayServer.screen_get_size(get_window().current_screen)
	resolution_hint.text = "Choose a window size, then apply." if mode_choice.selected == 0 else "Uses your display's native resolution (%d × %d)." % [native.x, native.y]

func safe_window_size(requested: Vector2i) -> Vector2i:
	var usable := DisplayServer.screen_get_usable_rect(get_window().current_screen)
	var maximum := Vector2i(maxi(320, usable.size.x - 16), maxi(240, usable.size.y - 48))
	return Vector2i(clampi(requested.x, 320, maximum.x), clampi(requested.y, 240, maximum.y))

func mode_index() -> int:
	return maxi(0, MODES.find(get_window().mode))

func apply_mode(mode: int, size: Vector2i) -> void:
	var window := get_window()
	var screen := window.current_screen
	# Leave fullscreen before setting client size and restoring window decorations.
	window.mode = Window.MODE_WINDOWED
	window.borderless = false
	window.current_screen = screen
	window.size = safe_window_size(size)
	var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
	window.position = usable.position + (usable.size - window.size) / 2
	window.mode = MODES[mode]

func apply_changes() -> void:
	if has_pending(): return
	var window := get_window()
	previous = {"mode": window.mode, "size": window.size, "position": window.position,
		"screen": window.current_screen, "borderless": window.borderless}
	apply_mode(mode_choice.selected, resolution_choice.get_selected_metadata())
	deadline_ms = Time.get_ticks_msec() + CONFIRM_SECONDS * 1000
	confirmation.show()
	update_countdown()
	countdown.start()
	keep_button.grab_focus()

func has_pending() -> bool:
	return not previous.is_empty()

func keep_changes() -> void:
	if not has_pending(): return
	saved_mode = mode_index()
	if get_window().mode == Window.MODE_WINDOWED: windowed_size = get_window().size
	previous.clear()
	finish_preview()
	save_display()
	refresh()

func revert_changes() -> void:
	if not has_pending(): return
	var window := get_window()
	window.mode = Window.MODE_WINDOWED
	window.borderless = previous.borderless
	window.current_screen = previous.screen
	window.size = previous.size
	window.position = previous.position
	window.mode = previous.mode
	previous.clear()
	finish_preview()
	refresh()

func finish_preview() -> void:
	countdown.stop()
	confirmation.hide()
	apply_button.grab_focus()

func update_countdown() -> void:
	var remaining := ceili(float(deadline_ms - Time.get_ticks_msec()) / 1000.0)
	if remaining <= 0:
		revert_changes()
		return
	countdown_label.text = "Reverting in %d seconds" % remaining

func save_display() -> void:
	var cfg := ConfigFile.new()
	# FPS / VSync can save during a preview without accepting its mode or size.
	cfg.set_value("display", "mode", saved_mode)
	cfg.set_value("display", "window_size", windowed_size)
	cfg.set_value("display", "fps_limit", Engine.max_fps)
	cfg.set_value("display", "vsync", DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED)
	if cfg.save(SAVE_PATH) != OK: menu.status.text = "Could not save display settings"

func load_display() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		saved_mode = mode_index()
		return
	var legacy_mode := 1 if bool(cfg.get_value("display", "fullscreen", true)) else 0
	saved_mode = clampi(int(cfg.get_value("display", "mode", legacy_mode)), 0, 2)
	var size = cfg.get_value("display", "window_size", Vector2i(1280, 720))
	windowed_size = safe_window_size(size if size is Vector2i else Vector2i(1280, 720))
	var fps := int(cfg.get_value("display", "fps_limit", 0))
	Engine.max_fps = fps if FPS_LIMITS.has(fps) else 0
	apply_mode(saved_mode, windowed_size)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(cfg.get_value("display", "vsync", true)) else DisplayServer.VSYNC_DISABLED)

func build_confirmation() -> void:
	confirmation = Control.new()
	confirmation.name = "DisplayConfirmation"
	confirmation.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirmation.hide()
	menu.panel.get_parent().add_child(confirmation)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.08, 0.16, 0.16, 0.85)
	confirmation.add_child(dim)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", menu.box(menu.CREAM, menu.GOLD, 16, 6))
	confirmation.add_child(card)
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	card.offset_left = -240
	card.offset_right = 240
	card.offset_top = -110
	card.offset_bottom = 110
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	card.add_child(col)
	var title: Label = menu.label("KEEP THESE CHANGES?", 25, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	countdown_label = menu.label("", 18)
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(countdown_label)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	col.add_child(buttons)
	keep_button = Button.new()
	keep_button.text = "KEEP"
	menu.style_button(keep_button)
	keep_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keep_button.pressed.connect(keep_changes)
	buttons.add_child(keep_button)
	var revert := Button.new()
	revert.text = "REVERT"
	menu.style_button(revert)
	revert.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	revert.pressed.connect(revert_changes)
	buttons.add_child(revert)
	# The overlay blocks mouse clicks; an explicit focus loop blocks keyboard escape.
	for button in [keep_button, revert]:
		var other: Button = revert if button == keep_button else keep_button
		var path: NodePath = button.get_path_to(other)
		button.focus_next = path
		button.focus_previous = path
		button.focus_neighbor_left = path
		button.focus_neighbor_right = path
		button.focus_neighbor_top = path
		button.focus_neighbor_bottom = path
	var hint: Label = menu.label("Esc to revert", 12)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)
	countdown = Timer.new()
	countdown.wait_time = 0.1
	countdown.ignore_time_scale = true
	countdown.process_mode = Node.PROCESS_MODE_ALWAYS
	countdown.timeout.connect(update_countdown)
	add_child(countdown)
