extends CanvasLayer
## Player-facing settings also work before the kitchen is initialized.

const Fonts = preload("res://scripts/ui_fonts.gd")
const LightBalance = preload("res://scripts/light_balance.gd")
const CREAM := Color("FFF5DA")
const INK := Color("4C382B")
const TEAL := Color("147E83")
const RED := Color("D84C3E")
const GOLD := Color("E5BA65")

var game: Node
var panel: PanelContainer
var tabs: TabContainer
var back: Button
var status: Label
var audio_controls: Dictionary = {}
var graphics_controls: Dictionary = {}
var display_options: VBoxContainer
var previous_focus: Control
var previous_options_open := false

func setup(owner_game: Node) -> void:
	game = owner_game
	name = "PlayerSettings"
	layer = 110
	visible = false
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.08, 0.16, 0.16, 0.76)
	root.add_child(dim)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", box(CREAM, GOLD, 20, 8))
	root.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	var heading := label("SETTINGS", 34, true)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color", TEAL)
	col.add_child(heading)
	var subtitle := label("A little tuning. Your kind of kitchen.", 15)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(subtitle)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_stylebox_override("panel", box(CREAM, CREAM, 10, 0))
	var bar := tabs
	bar.add_theme_font_override("font", Fonts.title)
	bar.add_theme_font_size_override("font_size", 20)
	bar.add_theme_stylebox_override("tab_selected", box(TEAL, TEAL.darkened(0.25), 8, 3))
	bar.add_theme_stylebox_override("tab_unselected", box(GOLD, GOLD.darkened(0.2), 8, 3))
	bar.add_theme_stylebox_override("tab_hovered", box(GOLD.lightened(0.15), GOLD, 8, 3))
	bar.add_theme_color_override("font_selected_color", CREAM)
	bar.add_theme_color_override("font_unselected_color", INK)
	bar.add_theme_color_override("font_hovered_color", INK)
	col.add_child(tabs)
	var audio := page("Audio")
	for spec in [["Master volume", "master_volume_linear", "_set_master_volume_linear"], ["Sound effects", "sound_effects_volume_linear", "_set_sound_effects_volume_linear"], ["Radio", "radio_volume_linear", "_set_radio_volume_linear"]]:
		var setter := String(spec[2])
		audio_controls[spec[1]] = slider(audio, spec[0], 0.0, 1.0, func(value: float):
			game.call(setter, value)
		)
	var display := page("Display")
	display_options = preload("res://scripts/player_display_settings.gd").new()
	display.add_child(display_options)
	var graphics := page("Graphics")
	graphics.add_theme_constant_override("separation", 8)
	for spec in [["glow_on", "Glow / bloom"], ["shadows", "Shadows"], ["heat_warp_on", "Heat shimmer"]]:
		var key := String(spec[0])
		graphics_controls[key] = check(graphics, spec[1], func(on: bool): set_graphics(key, on))
	graphics_controls["exposure"] = slider(graphics, "Brightness", 0.4, 1.8, func(value: float): set_graphics("exposure", value), false)
	status = label("FPS, VSync, audio and graphics save automatically", 13)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(status)
	back = Button.new()
	back.name = "BackButton"
	back.text = "BACK"
	style_button(back)
	back.pressed.connect(close)
	col.add_child(back)
	var hint := label("Esc to go back", 12)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)
	get_viewport().size_changed.connect(layout)
	layout()
	display_options.setup(self)

func open() -> void:
	if visible: return
	previous_focus = get_viewport().gui_get_focus_owner()
	previous_options_open = game.options_menu_open
	game.options_menu_open = true
	game._load_audio_settings()
	for key in audio_controls:
		audio_controls[key].value = game.get(key)
	var cfg := ConfigFile.new()
	if cfg.load(game.GFX_CFG_PATH) != OK:
		cfg.load(game.FIRST_RUN_GFX_CFG_PATH)
	var balance_cfg := ConfigFile.new()
	balance_cfg.load(LightBalance.SAVE_PATH)
	for key in graphics_controls:
		var value = cfg.get_value("gfx", key, game.GFX_DEFAULTS.get(key))
		if LightBalance.GRAPHICS_KEYS.has(key):
			var balance_key: String = LightBalance.GRAPHICS_KEYS[key]
			value = game.light_balance.values[balance_key] if is_instance_valid(game.light_balance) else balance_cfg.get_value("balance", balance_key, LightBalance.DEFAULTS[balance_key])
		elif game._kitchen_ready:
			if game.gfx_checks.has(key): value = game.gfx_checks[key].button_pressed
			elif game.gfx_sliders.has(key): value = game.gfx_sliders[key].value
		var control = graphics_controls[key]
		if control is CheckButton:
			control.set_pressed_no_signal(bool(value))
		else:
			control.set_value_no_signal(float(value))
			control.get_meta("readout").text = "%.2f" % float(value)
	display_options.refresh()
	tabs.current_tab = 0
	visible = true
	layout()
	back.grab_focus()

func close() -> void:
	if not visible: return
	if display_options.has_pending():
		display_options.revert_changes()
		return
	visible = false
	game.options_menu_open = previous_options_open
	if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree():
		previous_focus.grab_focus()

func layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var dimensions := Vector2(minf(560, viewport_size.x - 32), minf(610, viewport_size.y - 32))
	panel.size = dimensions
	panel.position = (viewport_size - dimensions) * 0.5

func set_graphics(key: String, value: Variant) -> void:
	if game._kitchen_ready:
		if value is bool: game._set_graphics_check_value(key, value)
		else: game._set_graphics_slider_value(key, value)
	else:
		# Save only this key; the kitchen loads the full configuration later.
		var cfg := ConfigFile.new()
		if cfg.load(game.GFX_CFG_PATH) != OK: cfg.load(game.FIRST_RUN_GFX_CFG_PATH)
		cfg.set_value("gfx", key, value)
		if cfg.save(game.GFX_CFG_PATH) != OK: status.text = "Could not save graphics settings"
		if LightBalance.GRAPHICS_KEYS.has(key):
			var balance_cfg := ConfigFile.new()
			balance_cfg.load(LightBalance.SAVE_PATH)
			balance_cfg.set_value("balance", LightBalance.GRAPHICS_KEYS[key], value)
			if balance_cfg.save(LightBalance.SAVE_PATH) != OK: status.text = "Could not save lighting settings"

func page(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 18)
	scroll.add_child(content)
	return content

func slider(parent: Control, title: String, minimum: float, maximum: float, action: Callable, percent := true) -> HSlider:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	parent.add_child(col)
	var row := HBoxContainer.new()
	col.add_child(row)
	var caption := label(title, 18)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(caption)
	var value_label := label("", 18, true)
	value_label.add_theme_color_override("font_color", TEAL)
	row.add_child(value_label)
	var control := HSlider.new()
	control.min_value = minimum
	control.max_value = maximum
	control.step = 0.01
	control.custom_minimum_size.y = 32
	control.tooltip_text = title
	control.set_meta("readout", value_label)
	control.add_theme_stylebox_override("slider", box(GOLD.lightened(0.35), GOLD, 4, 0))
	control.add_theme_stylebox_override("grabber_area", box(TEAL, TEAL, 4, 0))
	control.add_theme_stylebox_override("grabber_area_highlight", box(TEAL.lightened(0.15), TEAL, 4, 0))
	control.add_theme_icon_override("grabber", svg_icon('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24"><circle cx="12" cy="12" r="10" fill="#FFF5DA" stroke="#147E83" stroke-width="3"/></svg>'))
	control.add_theme_icon_override("grabber_highlight", svg_icon('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24"><circle cx="12" cy="12" r="10" fill="#E5BA65" stroke="#147E83" stroke-width="3"/></svg>'))
	control.value_changed.connect(func(value: float):
		value_label.text = "%d%%" % roundi(value * 100) if percent else "%.2f" % value
		if visible: action.call(value)
	)
	col.add_child(control)
	value_label.text = "0%" if percent else "%.2f" % minimum
	return control

static func label(text: String, size: int, heading := false) -> Label:
	var result := Label.new()
	result.text = text
	Fonts.apply_label(result, heading, size)
	result.add_theme_color_override("font_color", INK)
	return result

static func check(parent: Control, title: String, action: Callable) -> CheckButton:
	var result := CheckButton.new()
	result.text = title
	result.custom_minimum_size.y = 38
	Fonts.apply_button(result, false, 18)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		result.add_theme_color_override(state, INK)
	result.add_theme_icon_override("checked", svg_icon('<svg xmlns="http://www.w3.org/2000/svg" width="44" height="26"><rect x="1" y="1" width="42" height="24" rx="12" fill="#147E83"/><circle cx="31" cy="13" r="9" fill="#FFF5DA"/></svg>'))
	result.add_theme_icon_override("unchecked", svg_icon('<svg xmlns="http://www.w3.org/2000/svg" width="44" height="26"><rect x="1" y="1" width="42" height="24" rx="12" fill="#E5BA65"/><circle cx="13" cy="13" r="9" fill="#FFF5DA"/></svg>'))
	result.toggled.connect(action)
	parent.add_child(result)
	return result

static func style_button(button: Button) -> void:
	Fonts.apply_button(button, true, 20)
	button.custom_minimum_size.y = 48
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, box(RED.lightened(0.08) if state == "hover" else RED, RED.darkened(0.3), 10, 2 if state == "pressed" else 5))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, CREAM)
	var focus := box(Color.TRANSPARENT, TEAL, 10, 3)
	focus.set_border_width_all(3)
	button.add_theme_stylebox_override("focus", focus)

static func box(fill: Color, edge: Color, radius: int, depth: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.border_width_bottom = depth
	style.set_corner_radius_all(radius)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

static func svg_icon(svg: String) -> ImageTexture:
	var image := Image.new()
	image.load_svg_from_string(svg)
	return ImageTexture.create_from_image(image)
