## Top-down city map for parking the food truck. UI only — spawn/patience wire-up later.
extends Control

const UiFontsScript := preload("res://scripts/ui_fonts.gd")
const TruckLocationsScript := preload("res://scripts/truck_locations.gd")

signal closed
signal location_confirmed(location_id: String)

var _selected_id: String = TruckLocationsScript.DEFAULT_ID
var _parked_id: String = TruckLocationsScript.DEFAULT_ID
var _pin_buttons: Dictionary = {} ## id -> Button
var _name_label: Label = null
var _tier_label: Label = null
var _blurb_label: Label = null
var _crowd_label: Label = null
var _patience_label: Label = null
var _park_btn: Button = null
var _status_label: Label = null
var _map_host: Control = null


func _ready() -> void:
	## Built from open() so fonts / theme are ready.
	pass


func open(current_id: String) -> void:
	_parked_id = current_id if not current_id.is_empty() else TruckLocationsScript.DEFAULT_ID
	_selected_id = _parked_id
	if get_child_count() == 0:
		_build()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh_pins()
	_refresh_detail()


func close() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	closed.emit()


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.05, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			## Click dim = ignore; use Back. Keeps accidental closes rare on big map.
			pass
	)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "LocationMapPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -520.0
	panel.offset_right = 520.0
	panel.offset_top = -340.0
	panel.offset_bottom = 340.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.09, 0.10, 0.13, 0.98)
	psb.border_color = Color(1.0, 0.72, 0.28, 0.95)
	psb.set_border_width_all(2)
	psb.set_corner_radius_all(14)
	psb.content_margin_left = 18
	psb.content_margin_right = 18
	psb.content_margin_top = 14
	psb.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", psb)
	add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)

	var title := Label.new()
	title.text = "PARK THE TRUCK"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFontsScript.apply_luckiest_label(title, 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
	root.add_child(title)

	var hint := Label.new()
	hint.text = "Pick a spot on the city map. Harder areas mean more customers and less wait time."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiFontsScript.apply_label(hint, false, 13)
	hint.add_theme_color_override("font_color", Color(0.72, 0.75, 0.80))
	root.add_child(hint)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	root.add_child(body)

	## --- Left: stylized top-down city ---
	var map_frame := PanelContainer.new()
	map_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_frame.custom_minimum_size = Vector2(560, 420)
	var map_sb := StyleBoxFlat.new()
	map_sb.bg_color = Color(0.14, 0.18, 0.14, 1.0)
	map_sb.set_corner_radius_all(10)
	map_sb.set_border_width_all(1)
	map_sb.border_color = Color(0.35, 0.42, 0.38, 0.9)
	map_sb.content_margin_left = 0
	map_sb.content_margin_right = 0
	map_sb.content_margin_top = 0
	map_sb.content_margin_bottom = 0
	map_frame.add_theme_stylebox_override("panel", map_sb)
	body.add_child(map_frame)

	_map_host = Control.new()
	_map_host.name = "CityMap"
	_map_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_host.clip_contents = true
	_map_host.mouse_filter = Control.MOUSE_FILTER_STOP
	_map_host.draw.connect(_draw_city_map)
	_map_host.resized.connect(func():
		_map_host.queue_redraw()
		_layout_pins()
	)
	map_frame.add_child(_map_host)

	_spawn_pins()

	## --- Right: detail card ---
	var detail := VBoxContainer.new()
	detail.custom_minimum_size = Vector2(280, 0)
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 8)
	body.add_child(detail)

	var detail_card := PanelContainer.new()
	detail_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = Color(0.06, 0.07, 0.09, 0.95)
	dsb.set_corner_radius_all(10)
	dsb.set_border_width_all(1)
	dsb.border_color = Color(1.0, 0.88, 0.55, 0.22)
	dsb.content_margin_left = 14
	dsb.content_margin_right = 14
	dsb.content_margin_top = 12
	dsb.content_margin_bottom = 12
	detail_card.add_theme_stylebox_override("panel", dsb)
	detail.add_child(detail_card)

	var dcol := VBoxContainer.new()
	dcol.add_theme_constant_override("separation", 8)
	detail_card.add_child(dcol)

	var spot_lab := Label.new()
	spot_lab.text = "SELECTED SPOT"
	UiFontsScript.apply_label(spot_lab, true, 11)
	spot_lab.add_theme_color_override("font_color", Color(0.65, 0.68, 0.74))
	dcol.add_child(spot_lab)

	_name_label = Label.new()
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiFontsScript.apply_luckiest_label(_name_label, 22)
	_name_label.add_theme_color_override("font_color", Color(0.98, 0.98, 1.0))
	dcol.add_child(_name_label)

	_tier_label = Label.new()
	UiFontsScript.apply_label(_tier_label, true, 14)
	dcol.add_child(_tier_label)

	_blurb_label = Label.new()
	_blurb_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_blurb_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UiFontsScript.apply_label(_blurb_label, false, 13)
	_blurb_label.add_theme_color_override("font_color", Color(0.82, 0.85, 0.90))
	dcol.add_child(_blurb_label)

	dcol.add_child(HSeparator.new())

	_crowd_label = Label.new()
	UiFontsScript.apply_label(_crowd_label, false, 13)
	_crowd_label.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95))
	dcol.add_child(_crowd_label)

	_patience_label = Label.new()
	UiFontsScript.apply_label(_patience_label, false, 13)
	_patience_label.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95))
	dcol.add_child(_patience_label)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiFontsScript.apply_label(_status_label, false, 12)
	_status_label.add_theme_color_override("font_color", Color(0.55, 0.85, 0.62))
	dcol.add_child(_status_label)

	_park_btn = Button.new()
	_park_btn.text = "PARK HERE"
	_park_btn.custom_minimum_size = Vector2(0, 48)
	_park_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UiFontsScript.apply_luckiest_button(_park_btn, 18)
	_style_primary_btn(_park_btn)
	_park_btn.pressed.connect(_on_park_pressed)
	detail.add_child(_park_btn)

	## Legend + back
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	root.add_child(footer)

	var legend := HBoxContainer.new()
	legend.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	legend.add_theme_constant_override("separation", 14)
	footer.add_child(legend)
	_add_legend_chip(legend, TruckLocationsScript.TIER_EASY)
	_add_legend_chip(legend, TruckLocationsScript.TIER_MEDIUM)
	_add_legend_chip(legend, TruckLocationsScript.TIER_HARD)
	_add_legend_chip(legend, TruckLocationsScript.TIER_EXTREME)

	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(110, 40)
	back.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UiFontsScript.apply_button(back, true, 14)
	back.pressed.connect(func():
		close()
	)
	footer.add_child(back)

	call_deferred("_layout_pins")
	call_deferred("_refresh_detail")


func _style_primary_btn(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.85, 0.45, 0.12, 0.95)
	normal.set_corner_radius_all(9)
	normal.set_border_width_all(2)
	normal.border_color = Color(0.72, 0.18, 0.02, 0.88)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 10
	normal.content_margin_bottom = 8
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(1.0, 0.55, 0.18, 1.0)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.7, 0.35, 0.08, 1.0)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.25, 0.26, 0.28, 0.9)
	disabled.border_color = Color(0.4, 0.42, 0.46, 0.7)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_disabled_color", Color(0.7, 0.72, 0.75))
	btn.add_theme_constant_override("outline_size", 0)


func _add_legend_chip(parent: Control, tier: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	parent.add_child(row)
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(12, 12)
	swatch.color = TruckLocationsScript.tier_color(tier)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(swatch)
	var lab := Label.new()
	lab.text = TruckLocationsScript.tier_label(tier)
	UiFontsScript.apply_label(lab, false, 11)
	lab.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82))
	row.add_child(lab)


func _spawn_pins() -> void:
	for loc in TruckLocationsScript.all():
		var id := str(loc["id"])
		var btn := Button.new()
		btn.name = "Pin_%s" % id
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.custom_minimum_size = Vector2(22, 22)
		btn.text = ""
		btn.tooltip_text = str(loc["name"])
		var tier := str(loc["tier"])
		_style_pin(btn, tier, false)
		btn.pressed.connect(_on_pin_pressed.bind(id))
		_map_host.add_child(btn)
		_pin_buttons[id] = btn


func _style_pin(btn: Button, tier: String, selected: bool) -> void:
	var c := TruckLocationsScript.tier_color(tier)
	var normal := StyleBoxFlat.new()
	normal.bg_color = c
	normal.set_corner_radius_all(11)
	normal.set_border_width_all(2 if selected else 1)
	normal.border_color = Color(1, 1, 1, 0.95) if selected else c.darkened(0.35)
	if selected:
		normal.shadow_color = Color(c.r, c.g, c.b, 0.55)
		normal.shadow_size = 8
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = c.lightened(0.15)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)


func _layout_pins() -> void:
	if _map_host == null:
		return
	var sz := _map_host.size
	if sz.x < 8.0 or sz.y < 8.0:
		return
	var pad := 18.0
	var inner := sz - Vector2(pad * 2.0, pad * 2.0)
	for loc in TruckLocationsScript.all():
		var id := str(loc["id"])
		var btn: Button = _pin_buttons.get(id) as Button
		if btn == null:
			continue
		var uv: Vector2 = loc["map"]
		var pos := Vector2(pad, pad) + Vector2(uv.x * inner.x, uv.y * inner.y) - btn.custom_minimum_size * 0.5
		btn.position = pos
		btn.size = btn.custom_minimum_size


func _on_pin_pressed(id: String) -> void:
	_selected_id = id
	_refresh_pins()
	_refresh_detail()


func _refresh_pins() -> void:
	for loc in TruckLocationsScript.all():
		var id := str(loc["id"])
		var btn: Button = _pin_buttons.get(id) as Button
		if btn == null:
			continue
		var selected := id == _selected_id
		_style_pin(btn, str(loc["tier"]), selected)
		## Parked spot reads slightly larger.
		var base := 26.0 if id == _parked_id else 22.0
		if selected:
			base = 28.0
		btn.custom_minimum_size = Vector2(base, base)
		btn.size = btn.custom_minimum_size
	_layout_pins()


func _crowd_text(tier: String) -> String:
	match tier:
		TruckLocationsScript.TIER_EASY:
			return "Crowds: Light"
		TruckLocationsScript.TIER_MEDIUM:
			return "Crowds: Steady"
		TruckLocationsScript.TIER_HARD:
			return "Crowds: Heavy"
		_:
			return "Crowds: Packed"


func _patience_text(tier: String) -> String:
	match tier:
		TruckLocationsScript.TIER_EASY:
			return "Patience: Relaxed"
		TruckLocationsScript.TIER_MEDIUM:
			return "Patience: Average"
		TruckLocationsScript.TIER_HARD:
			return "Patience: Short"
		_:
			return "Patience: Razor-thin"


func _refresh_detail() -> void:
	var loc := TruckLocationsScript.get_by_id(_selected_id)
	if loc.is_empty():
		return
	var tier := str(loc["tier"])
	if _name_label:
		_name_label.text = str(loc["name"])
	if _tier_label:
		_tier_label.text = TruckLocationsScript.tier_label(tier)
		_tier_label.add_theme_color_override("font_color", TruckLocationsScript.tier_color(tier))
	if _blurb_label:
		_blurb_label.text = str(loc["blurb"])
	if _crowd_label:
		_crowd_label.text = _crowd_text(tier)
	if _patience_label:
		_patience_label.text = _patience_text(tier)
	if _status_label:
		if _selected_id == _parked_id:
			_status_label.text = "Currently parked here"
			_status_label.add_theme_color_override("font_color", Color(0.55, 0.85, 0.62))
		else:
			_status_label.text = "Tap Park Here to move the truck"
			_status_label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88))
	if _park_btn:
		_park_btn.disabled = (_selected_id == _parked_id)
		_park_btn.text = "PARKED" if _park_btn.disabled else "PARK HERE"


func _on_park_pressed() -> void:
	if _selected_id == _parked_id:
		return
	_parked_id = _selected_id
	_refresh_pins()
	_refresh_detail()
	location_confirmed.emit(_parked_id)
	close()


func _draw_city_map() -> void:
	## Procedural top-down city: grass, blocks, roads, water, labels.
	if _map_host == null:
		return
	var s := _map_host.size
	if s.x < 4.0 or s.y < 4.0:
		return

	## Base grass / parkland
	_map_host.draw_rect(Rect2(Vector2.ZERO, s), Color(0.22, 0.38, 0.24), true)

	## Water (river / marina)
	_map_host.draw_colored_polygon(PackedVector2Array([
		Vector2(s.x * 0.0, s.y * 0.0),
		Vector2(s.x * 0.22, s.y * 0.0),
		Vector2(s.x * 0.10, s.y * 0.28),
		Vector2(s.x * 0.0, s.y * 0.22),
	]), Color(0.22, 0.42, 0.58, 0.85))

	## City blocks
	var blocks: Array[Rect2] = [
		Rect2(0.28, 0.12, 0.18, 0.16),
		Rect2(0.50, 0.10, 0.16, 0.14),
		Rect2(0.70, 0.08, 0.18, 0.18),
		Rect2(0.34, 0.34, 0.14, 0.14),
		Rect2(0.52, 0.32, 0.18, 0.16),
		Rect2(0.74, 0.34, 0.16, 0.14),
		Rect2(0.30, 0.56, 0.16, 0.14),
		Rect2(0.50, 0.54, 0.14, 0.16),
		Rect2(0.68, 0.56, 0.18, 0.14),
		Rect2(0.36, 0.78, 0.20, 0.12),
		Rect2(0.62, 0.78, 0.22, 0.12),
		Rect2(0.08, 0.40, 0.14, 0.18),
		Rect2(0.10, 0.66, 0.14, 0.16),
	]
	for b in blocks:
		var r := Rect2(b.position * s, b.size * s)
		_map_host.draw_rect(r, Color(0.32, 0.34, 0.38), true)
		_map_host.draw_rect(r.grow(-3.0), Color(0.38, 0.40, 0.45), true)

	## Park oval
	var park_c := Vector2(s.x * 0.18, s.y * 0.82)
	_map_host.draw_circle(park_c, minf(s.x, s.y) * 0.09, Color(0.28, 0.50, 0.30))
	_map_host.draw_circle(park_c, minf(s.x, s.y) * 0.055, Color(0.34, 0.58, 0.34))

	## Stadium blob
	_map_host.draw_circle(Vector2(s.x * 0.82, s.y * 0.16), minf(s.x, s.y) * 0.07, Color(0.45, 0.36, 0.42))

	## Roads (horizontal)
	var road := Color(0.18, 0.18, 0.20)
	var lane := Color(0.72, 0.68, 0.35, 0.55)
	var h_roads: Array[float] = [0.28, 0.48, 0.70]
	for yf in h_roads:
		var y := yf * s.y
		_map_host.draw_rect(Rect2(0.0, y - 7.0, s.x, 14.0), road, true)
		_map_host.draw_line(Vector2(0.0, y), Vector2(s.x, y), lane, 1.2)
	## Roads (vertical)
	var v_roads: Array[float] = [0.26, 0.46, 0.66, 0.86]
	for xf in v_roads:
		var x := xf * s.x
		_map_host.draw_rect(Rect2(x - 7.0, 0.0, 14.0, s.y), road, true)
		_map_host.draw_line(Vector2(x, 0.0), Vector2(x, s.y), lane, 1.2)

	## Soft district labels
	_draw_map_label("PARKS", Vector2(s.x * 0.14, s.y * 0.88), Color(0.7, 0.9, 0.7, 0.45))
	_draw_map_label("DOWNTOWN", Vector2(s.x * 0.52, s.y * 0.40), Color(0.9, 0.88, 0.7, 0.4))
	_draw_map_label("STADIUM", Vector2(s.x * 0.80, s.y * 0.08), Color(0.95, 0.7, 0.75, 0.4))
	_draw_map_label("MALL", Vector2(s.x * 0.76, s.y * 0.84), Color(0.85, 0.8, 0.95, 0.4))


func _draw_map_label(text: String, pos: Vector2, color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	if UiFontsScript.body != null:
		font = UiFontsScript.body
	_map_host.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, color)
