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
var _map_tex_rect: TextureRect = null
var _map_tex_size: Vector2 = Vector2(1024, 682)
var _cat_marker: Control = null ## Black circle + ears with white glow; wanders the map
var _cat_uv: Vector2 = Vector2(0.5, 0.5)
var _cat_target_uv: Vector2 = Vector2(0.5, 0.5)
var _cat_wait: float = 0.0
var _cat_wander_ready: bool = false
const TOWN_MAP_PATH := "res://assets/ui/town_map.png"
const CAT_MARKER_SIZE := 40.0
const CAT_WANDER_SPEED := 0.085 ## UV units per second toward next spot
const CAT_PAUSE_MIN := 0.55
const CAT_PAUSE_MAX := 1.8


func _ready() -> void:
	## Built from open() so fonts / theme are ready.
	set_process(false)


func open(current_id: String) -> void:
	_parked_id = current_id if not current_id.is_empty() else TruckLocationsScript.DEFAULT_ID
	_selected_id = _parked_id
	if get_child_count() == 0:
		_build()
	## Rebuild art if a prior open failed to load the PNG.
	if _map_tex_rect != null and _map_tex_rect.texture == null:
		_map_tex_rect.texture = _load_town_map_texture()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ensure_cat_wander_start()
	_layout_map_and_pins()
	_refresh_pins()
	_refresh_detail()
	call_deferred("_layout_map_and_pins")
	set_process(true)


func close() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	closed.emit()


func set_parked_id(location_id: String) -> void:
	## Co-op parking sync — refresh pin highlight without reopening.
	_parked_id = location_id if not location_id.is_empty() else TruckLocationsScript.DEFAULT_ID
	if not visible:
		return
	_refresh_pins()
	_refresh_detail()


func _process(delta: float) -> void:
	if not visible or _cat_marker == null or not is_instance_valid(_cat_marker):
		return
	_tick_cat_wander(delta)
	_layout_cat_marker()


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
	_map_host.resized.connect(func():
		_layout_map_texture()
		_layout_pins()
	)
	map_frame.add_child(_map_host)

	_map_tex_rect = TextureRect.new()
	_map_tex_rect.name = "TownMapArt"
	_map_tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_map_tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_tex_rect.z_index = 0
	_map_tex_rect.texture = _load_town_map_texture()
	_map_tex_rect.modulate = Color(1, 1, 1, 1)
	_map_host.add_child(_map_tex_rect)

	_spawn_pins()
	_spawn_cat_marker()

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

	call_deferred("_layout_map_and_pins")
	call_deferred("_refresh_detail")


func _layout_map_and_pins() -> void:
	_layout_map_texture()
	_layout_pins()
	_layout_cat_marker()


func _spawn_cat_marker() -> void:
	if _map_host == null:
		return
	if _cat_marker != null and is_instance_valid(_cat_marker):
		_cat_marker.queue_free()
	var tex := TextureRect.new()
	tex.name = "CatMapMarker"
	tex.texture = _make_black_cat_icon()
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.custom_minimum_size = Vector2(CAT_MARKER_SIZE, CAT_MARKER_SIZE)
	tex.size = Vector2(CAT_MARKER_SIZE, CAT_MARKER_SIZE)
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.z_index = 8
	tex.tooltip_text = "Street cat"
	_map_host.add_child(tex)
	_cat_marker = tex
	_ensure_cat_wander_start()


func _make_black_cat_icon() -> Texture2D:
	## Readable map pin: soft white glow + black circle head + triangle ears.
	var s := 64
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := 32.0
	var cy := 36.0
	## Soft white glow behind the cat.
	for y in s:
		for x in s:
			var dx := (float(x) - cx) / 22.0
			var dy := (float(y) - cy) / 22.0
			var r2 := dx * dx + dy * dy
			if r2 <= 1.0:
				var a := pow(1.0 - r2, 1.35) * 0.92
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	## Black circle body/head.
	var black := Color(0.04, 0.04, 0.05, 1.0)
	for y in s:
		for x in s:
			var dx := (float(x) - cx) / 14.5
			var dy := (float(y) - cy) / 14.5
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, black)
	## Left ear triangle.
	_fill_ear_triangle(img, Vector2(18, 28), Vector2(26, 28), Vector2(20, 10), black)
	## Right ear triangle.
	_fill_ear_triangle(img, Vector2(38, 28), Vector2(46, 28), Vector2(44, 10), black)
	## Tiny white eye dots so it reads as a face.
	img.set_pixel(27, 34, Color(0.92, 0.92, 0.95, 1.0))
	img.set_pixel(28, 34, Color(0.92, 0.92, 0.95, 1.0))
	img.set_pixel(36, 34, Color(0.92, 0.92, 0.95, 1.0))
	img.set_pixel(37, 34, Color(0.92, 0.92, 0.95, 1.0))
	return ImageTexture.create_from_image(img)


func _fill_ear_triangle(img: Image, a: Vector2, b: Vector2, tip: Vector2, col: Color) -> void:
	var min_x := int(floor(minf(a.x, minf(b.x, tip.x))))
	var max_x := int(ceil(maxf(a.x, maxf(b.x, tip.x))))
	var min_y := int(floor(minf(a.y, minf(b.y, tip.y))))
	var max_y := int(ceil(maxf(a.y, maxf(b.y, tip.y))))
	var w := img.get_width()
	var h := img.get_height()
	for y in range(clampi(min_y, 0, h - 1), clampi(max_y, 0, h - 1) + 1):
		for x in range(clampi(min_x, 0, w - 1), clampi(max_x, 0, w - 1) + 1):
			var p := Vector2(float(x) + 0.5, float(y) + 0.5)
			if _point_in_triangle(p, a, b, tip):
				img.set_pixel(x, y, col)


func _point_in_triangle(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var v0 := c - a
	var v1 := b - a
	var v2 := p - a
	var dot00 := v0.dot(v0)
	var dot01 := v0.dot(v1)
	var dot02 := v0.dot(v2)
	var dot11 := v1.dot(v1)
	var dot12 := v1.dot(v2)
	var inv := 1.0 / maxf(dot00 * dot11 - dot01 * dot01, 0.00001)
	var u := (dot11 * dot02 - dot01 * dot12) * inv
	var v := (dot00 * dot12 - dot01 * dot02) * inv
	return u >= 0.0 and v >= 0.0 and (u + v) <= 1.0


func _ensure_cat_wander_start() -> void:
	var spots := _cat_wander_uvs()
	if spots.is_empty():
		_cat_uv = Vector2(0.5, 0.5)
		_cat_target_uv = _cat_uv
		_cat_wander_ready = true
		return
	if not _cat_wander_ready:
		_cat_uv = spots[randi() % spots.size()]
		_cat_wander_ready = true
	_pick_next_cat_target(spots)
	_cat_wait = randf_range(0.15, 0.6)


func _cat_wander_uvs() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for loc in TruckLocationsScript.all():
		var uv: Vector2 = loc.get("map", Vector2.ZERO)
		if uv != Vector2.ZERO:
			out.append(uv)
	return out


func _pick_next_cat_target(spots: Array[Vector2] = []) -> void:
	if spots.is_empty():
		spots = _cat_wander_uvs()
	if spots.is_empty():
		_cat_target_uv = _cat_uv
		return
	var pick := spots[randi() % spots.size()]
	## Prefer a different spot so the cat actually travels.
	var guard := 0
	while pick.distance_squared_to(_cat_uv) < 0.002 and guard < 8:
		pick = spots[randi() % spots.size()]
		guard += 1
	_cat_target_uv = pick


func _tick_cat_wander(delta: float) -> void:
	if _cat_wait > 0.0:
		_cat_wait = maxf(0.0, _cat_wait - delta)
		return
	var to := _cat_target_uv - _cat_uv
	var dist := to.length()
	if dist < 0.008:
		_cat_uv = _cat_target_uv
		_cat_wait = randf_range(CAT_PAUSE_MIN, CAT_PAUSE_MAX)
		_pick_next_cat_target()
		return
	var step := CAT_WANDER_SPEED * delta
	if step >= dist:
		_cat_uv = _cat_target_uv
	else:
		_cat_uv += to.normalized() * step


func _layout_cat_marker() -> void:
	if _cat_marker == null or _map_host == null:
		return
	var img_r := _map_image_rect()
	if img_r.size.x < 8.0 or img_r.size.y < 8.0:
		return
	var uv := Vector2(clampf(_cat_uv.x, 0.04, 0.96), clampf(_cat_uv.y, 0.04, 0.96))
	var sz := Vector2(CAT_MARKER_SIZE, CAT_MARKER_SIZE)
	_cat_marker.custom_minimum_size = sz
	_cat_marker.position = img_r.position + Vector2(uv.x * img_r.size.x, uv.y * img_r.size.y) - sz * 0.5
	_cat_marker.size = sz


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
		btn.z_index = 2
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


func _load_town_map_texture() -> Texture2D:
	## Export-safe: read image bytes from the PCK first (same as open/closed signs).
	## Forced into the pack via export_presets include_filter.
	var paths: Array[String] = [
		"res://assets/ui/town_map.png",
		"res://IMAGES/town_map.png",
	]
	for path in paths:
		if FileAccess.file_exists(path):
			var bytes := FileAccess.get_file_as_bytes(path)
			if bytes.size() > 64:
				var img := Image.new()
				var err := img.load_png_from_buffer(bytes)
				if err != OK:
					err = img.load_jpg_from_buffer(bytes)
				if err == OK:
					_map_tex_size = Vector2(img.get_width(), img.get_height())
					return ImageTexture.create_from_image(img)
		if ResourceLoader.exists(path):
			var imported: Texture2D = load(path) as Texture2D
			if imported != null:
				_map_tex_size = imported.get_size()
				return imported
	push_warning("Town map texture missing — pins will sit on empty green")
	return null


func _map_image_rect() -> Rect2:
	## Letterboxed rect where town_map.png actually draws inside _map_host.
	if _map_host == null:
		return Rect2()
	var host := _map_host.size
	if host.x < 4.0 or host.y < 4.0:
		return Rect2()
	var tex := _map_tex_size
	if tex.x < 1.0 or tex.y < 1.0:
		tex = Vector2(1024, 682)
	var scale := minf(host.x / tex.x, host.y / tex.y)
	var drawn := tex * scale
	var origin := (host - drawn) * 0.5
	return Rect2(origin, drawn)


func _layout_map_texture() -> void:
	if _map_tex_rect == null or _map_host == null:
		return
	_map_tex_rect.position = Vector2.ZERO
	_map_tex_rect.size = _map_host.size


func _layout_pins() -> void:
	if _map_host == null:
		return
	var img_r := _map_image_rect()
	if img_r.size.x < 8.0 or img_r.size.y < 8.0:
		return
	for loc in TruckLocationsScript.all():
		var id := str(loc["id"])
		var btn: Button = _pin_buttons.get(id) as Button
		if btn == null:
			continue
		var uv: Vector2 = loc["map"]
		var pos := img_r.position + Vector2(uv.x * img_r.size.x, uv.y * img_r.size.y) \
				- btn.custom_minimum_size * 0.5
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
