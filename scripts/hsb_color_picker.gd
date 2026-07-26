## Photoshop-style HSB color picker (saturation/brightness square + hue + opacity).
extends Control

signal color_changed(color: Color)

const UiFontsScript := preload("res://scripts/ui_fonts.gd")

var hue: float = 0.08 ## 0..1
var saturation: float = 0.85
var brightness: float = 0.95
var alpha: float = 0.85

var _sb_rect: Control
var _hue_slider: Control
var _alpha_slider: Control
var _preview: ColorRect
var _hex_label: Label
var _h_label: Label
var _s_label: Label
var _b_label: Label
var _a_label: Label

var _drag_sb: bool = false
var _drag_hue: bool = false
var _drag_alpha: bool = false
var _suppress: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(220, 210)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_refresh_labels()
	queue_redraw()


func set_color(c: Color) -> void:
	_suppress = true
	var hsb := _rgb_to_hsb(c)
	hue = hsb.x
	saturation = hsb.y
	brightness = hsb.z
	alpha = c.a
	_suppress = false
	_refresh_labels()
	queue_redraw()
	if _preview:
		_preview.color = get_color()


func get_color() -> Color:
	var rgb := _hsb_to_rgb(hue, saturation, brightness)
	return Color(rgb.r, rgb.g, rgb.b, alpha)


func _build() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	root.add_child(top)

	_sb_rect = Control.new()
	_sb_rect.custom_minimum_size = Vector2(150, 150)
	_sb_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_sb_rect.gui_input.connect(_on_sb_input)
	_sb_rect.draw.connect(_draw_sb)
	top.add_child(_sb_rect)

	_hue_slider = Control.new()
	_hue_slider.custom_minimum_size = Vector2(18, 150)
	_hue_slider.mouse_filter = Control.MOUSE_FILTER_STOP
	_hue_slider.gui_input.connect(_on_hue_input)
	_hue_slider.draw.connect(_draw_hue)
	top.add_child(_hue_slider)

	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 4)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(side)

	_preview = ColorRect.new()
	_preview.custom_minimum_size = Vector2(48, 48)
	_preview.color = get_color()
	side.add_child(_preview)

	_hex_label = Label.new()
	_hex_label.text = "#FF5933"
	UiFontsScript.apply_label(_hex_label, false, 11)
	_hex_label.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95))
	side.add_child(_hex_label)

	_h_label = Label.new()
	_s_label = Label.new()
	_b_label = Label.new()
	_a_label = Label.new()
	for lab in [_h_label, _s_label, _b_label, _a_label]:
		UiFontsScript.apply_label(lab, false, 10)
		lab.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85))
		side.add_child(lab)

	var alpha_row := HBoxContainer.new()
	alpha_row.add_theme_constant_override("separation", 6)
	root.add_child(alpha_row)

	var a_cap := Label.new()
	a_cap.text = "A"
	UiFontsScript.apply_label(a_cap, true, 11)
	a_cap.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	a_cap.custom_minimum_size = Vector2(14, 0)
	alpha_row.add_child(a_cap)

	_alpha_slider = Control.new()
	_alpha_slider.custom_minimum_size = Vector2(0, 16)
	_alpha_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_alpha_slider.mouse_filter = Control.MOUSE_FILTER_STOP
	_alpha_slider.gui_input.connect(_on_alpha_input)
	_alpha_slider.draw.connect(_draw_alpha)
	alpha_row.add_child(_alpha_slider)


func _emit_if_needed() -> void:
	if _suppress:
		return
	var c := get_color()
	if _preview:
		_preview.color = c
	_refresh_labels()
	queue_redraw()
	if _sb_rect:
		_sb_rect.queue_redraw()
	if _hue_slider:
		_hue_slider.queue_redraw()
	if _alpha_slider:
		_alpha_slider.queue_redraw()
	color_changed.emit(c)


func _refresh_labels() -> void:
	var c := get_color()
	if _hex_label:
		_hex_label.text = "#%02X%02X%02X" % [int(c.r * 255.0), int(c.g * 255.0), int(c.b * 255.0)]
	if _h_label:
		_h_label.text = "H  %d°" % int(round(hue * 360.0))
	if _s_label:
		_s_label.text = "S  %d%%" % int(round(saturation * 100.0))
	if _b_label:
		_b_label.text = "B  %d%%" % int(round(brightness * 100.0))
	if _a_label:
		_a_label.text = "A  %d%%" % int(round(alpha * 100.0))


func _on_sb_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drag_sb = event.pressed
		if event.pressed:
			_sample_sb(event.position)
			accept_event()
	elif event is InputEventMouseMotion and _drag_sb:
		_sample_sb(event.position)
		accept_event()


func _sample_sb(pos: Vector2) -> void:
	var sz := _sb_rect.size
	if sz.x < 1.0 or sz.y < 1.0:
		return
	saturation = clampf(pos.x / sz.x, 0.0, 1.0)
	brightness = clampf(1.0 - pos.y / sz.y, 0.0, 1.0)
	_emit_if_needed()


func _on_hue_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drag_hue = event.pressed
		if event.pressed:
			_sample_hue(event.position)
			accept_event()
	elif event is InputEventMouseMotion and _drag_hue:
		_sample_hue(event.position)
		accept_event()


func _sample_hue(pos: Vector2) -> void:
	var h := _hue_slider.size.y
	if h < 1.0:
		return
	hue = clampf(pos.y / h, 0.0, 1.0)
	_emit_if_needed()


func _on_alpha_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drag_alpha = event.pressed
		if event.pressed:
			_sample_alpha(event.position)
			accept_event()
	elif event is InputEventMouseMotion and _drag_alpha:
		_sample_alpha(event.position)
		accept_event()


func _sample_alpha(pos: Vector2) -> void:
	var w := _alpha_slider.size.x
	if w < 1.0:
		return
	alpha = clampf(pos.x / w, 0.0, 1.0)
	_emit_if_needed()


func _draw_sb() -> void:
	var sz := _sb_rect.size
	var steps := 32
	for y in steps:
		for x in steps:
			var s := (float(x) + 0.5) / float(steps)
			var b := 1.0 - (float(y) + 0.5) / float(steps)
			var col := _hsb_to_rgb(hue, s, b)
			var r := Rect2(
				Vector2(sz.x * float(x) / float(steps), sz.y * float(y) / float(steps)),
				Vector2(sz.x / float(steps) + 1.0, sz.y / float(steps) + 1.0)
			)
			_sb_rect.draw_rect(r, col, true)
	## Cursor
	var cx := saturation * sz.x
	var cy := (1.0 - brightness) * sz.y
	_sb_rect.draw_arc(Vector2(cx, cy), 6.0, 0.0, TAU, 24, Color(0, 0, 0, 0.85), 2.0, true)
	_sb_rect.draw_arc(Vector2(cx, cy), 6.0, 0.0, TAU, 24, Color(1, 1, 1, 0.95), 1.2, true)


func _draw_hue() -> void:
	var sz := _hue_slider.size
	var steps := 48
	for i in steps:
		var t0 := float(i) / float(steps)
		var t1 := float(i + 1) / float(steps)
		var col := _hsb_to_rgb(t0, 1.0, 1.0)
		var r := Rect2(Vector2(0.0, sz.y * t0), Vector2(sz.x, sz.y * (t1 - t0) + 1.0))
		_hue_slider.draw_rect(r, col, true)
	var y := hue * sz.y
	_hue_slider.draw_line(Vector2(0.0, y), Vector2(sz.x, y), Color(0, 0, 0, 0.9), 3.0)
	_hue_slider.draw_line(Vector2(0.0, y), Vector2(sz.x, y), Color(1, 1, 1, 0.95), 1.4)


func _draw_alpha() -> void:
	var sz := _alpha_slider.size
	## Checkerboard
	var cell := 6.0
	var cols := int(ceil(sz.x / cell))
	var rows := int(ceil(sz.y / cell))
	for row in rows:
		for col in cols:
			var light := ((row + col) % 2) == 0
			var c := Color(0.75, 0.75, 0.75) if light else Color(0.45, 0.45, 0.45)
			_alpha_slider.draw_rect(Rect2(col * cell, row * cell, cell, cell), c, true)
	var rgb := _hsb_to_rgb(hue, saturation, brightness)
	var left := Color(rgb.r, rgb.g, rgb.b, 0.0)
	var right := Color(rgb.r, rgb.g, rgb.b, 1.0)
	## Approximate gradient with strips
	var strips := 40
	for i in strips:
		var t := float(i) / float(strips)
		var t1 := float(i + 1) / float(strips)
		var col := left.lerp(right, t)
		_alpha_slider.draw_rect(
			Rect2(sz.x * t, 0.0, sz.x * (t1 - t) + 1.0, sz.y),
			col,
			true
		)
	var x := alpha * sz.x
	_alpha_slider.draw_line(Vector2(x, 0.0), Vector2(x, sz.y), Color(0, 0, 0, 0.9), 3.0)
	_alpha_slider.draw_line(Vector2(x, 0.0), Vector2(x, sz.y), Color(1, 1, 1, 0.95), 1.4)


static func _hsb_to_rgb(h: float, s: float, v: float) -> Color:
	h = fposmod(h, 1.0)
	s = clampf(s, 0.0, 1.0)
	v = clampf(v, 0.0, 1.0)
	if s <= 0.0001:
		return Color(v, v, v)
	var hh := h * 6.0
	var i := int(floor(hh))
	var f := hh - float(i)
	var p := v * (1.0 - s)
	var q := v * (1.0 - s * f)
	var t := v * (1.0 - s * (1.0 - f))
	match i % 6:
		0:
			return Color(v, t, p)
		1:
			return Color(q, v, p)
		2:
			return Color(p, v, t)
		3:
			return Color(p, q, v)
		4:
			return Color(t, p, v)
		_:
			return Color(v, p, q)


static func _rgb_to_hsb(c: Color) -> Vector3:
	var mx := maxf(c.r, maxf(c.g, c.b))
	var mn := minf(c.r, minf(c.g, c.b))
	var d := mx - mn
	var h := 0.0
	var s := 0.0 if mx <= 0.0001 else d / mx
	var v := mx
	if d > 0.0001:
		if mx == c.r:
			h = fposmod((c.g - c.b) / d, 6.0)
		elif mx == c.g:
			h = (c.b - c.r) / d + 2.0
		else:
			h = (c.r - c.g) / d + 4.0
		h /= 6.0
	return Vector3(h, s, v)
