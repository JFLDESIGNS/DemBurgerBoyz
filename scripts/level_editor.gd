## In-game fly-cam dresser: select world objects, place props / lights / napkins.
extends Node

const UiFontsScript := preload("res://scripts/ui_fonts.gd")
const SunSkyPadScript := preload("res://scripts/sun_sky_pad.gd")
const SAVE_PATH := "user://level_dressing.cfg"
const SAVE_SECTION := "dressing"
const GIZMO_LEN := 0.28
const GIZMO_HIT_PX := 14.0

signal active_changed(on: bool)

var active: bool = false
var previewing_main: bool = false

var _game: Node = null
var _world: Node3D = null
var _grill: Node3D = null
var _main_cam: Camera3D = null
var _fly_cam: Camera3D = null
var _dressing: Node3D = null
var _gizmo: Node3D = null
var _selected: Node3D = null
var _layer: CanvasLayer = null
var _ui: Control = null
var _outliner: ItemList = null
var _inspector: VBoxContainer = null
var _status: Label = null
var _preview_btn: Button = null
var _outliner_nodes: Array = []
var _inspector_busy: bool = false
var _look_yaw: float = 180.0
var _look_pitch: float = -8.0
var _move_speed: float = 3.4
var _rmb_look: bool = false
var _gizmo_axis: int = -1
var _gizmo_grab_origin := Vector3.ZERO
var _gizmo_grab_obj := Vector3.ZERO
var _place_counter := 0
var _napkin_darkness_default := 0.0
var _napkin_pattern_scale_default := 1.0
var _profile_btns: Array[Button] = []
var _sun_pad = null
var _sun_lab: Label = null
var _sun_azim_spin: SpinBox = null
var _sun_elev_spin: SpinBox = null
var _lighting_busy: bool = false


func setup(game: Node, world: Node3D, grill: Node3D, main_cam: Camera3D) -> void:
	_game = game
	_world = world
	_grill = grill
	_main_cam = main_cam
	_ensure_dressing_root()
	_build_fly_cam()
	_build_gizmo()
	_build_ui()
	_load_dressing()


func is_active() -> bool:
	return active


func is_pointer_over_ui(screen_pos: Vector2) -> bool:
	if not active or previewing_main or _ui == null or not _ui.visible:
		return false
	for panel in [_ui.get_node_or_null("TopBar"), _ui.get_node_or_null("Outliner"), _ui.get_node_or_null("Inspector")]:
		if panel is Control and (panel as Control).visible and (panel as Control).get_global_rect().has_point(screen_pos):
			return true
	return false


func toggle() -> void:
	set_active(not active)


func set_active(on: bool) -> void:
	if active == on:
		return
	if on:
		previewing_main = false
		_enter_fly()
	else:
		_exit_editor()
	active = on
	if _layer:
		_layer.visible = on and not previewing_main
	active_changed.emit(on)


func _enter_fly() -> void:
	if _fly_cam == null or _main_cam == null:
		return
	_fly_cam.global_transform = _main_cam.global_transform
	_fly_cam.fov = _main_cam.fov
	var e := _fly_cam.global_rotation
	_look_yaw = rad_to_deg(e.y)
	_look_pitch = rad_to_deg(e.x)
	_fly_cam.current = true
	_main_cam.current = false
	previewing_main = false
	if _layer:
		_layer.visible = true
	_refresh_preview_button()
	_refresh_outliner()
	refresh_lighting_ui()
	_set_status("L-mode — RMB look · WASD fly · Q/E up/down · click to select · lighting in the left panel")


func _exit_editor() -> void:
	previewing_main = false
	_gizmo_axis = -1
	_rmb_look = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _main_cam:
		_main_cam.current = true
	if _fly_cam:
		_fly_cam.current = false
	if _gizmo:
		_gizmo.visible = false
	if _layer:
		_layer.visible = false
	_save_dressing()


func set_preview_main(on: bool) -> void:
	if not active:
		return
	previewing_main = on
	if on:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_rmb_look = false
		if _main_cam:
			_main_cam.current = true
		if _fly_cam:
			_fly_cam.current = false
		if _gizmo:
			_gizmo.visible = false
		if _layer:
			_layer.visible = false
		_set_status("Main camera preview — Esc or the button to fly again")
	else:
		_enter_fly()
		_update_gizmo()
	_refresh_preview_button()


func handle_input(event: InputEvent) -> bool:
	if not active:
		return false
	if event is InputEventKey and event.pressed and not event.echo:
		var key_ev := event as InputEventKey
		var code: Key = key_ev.keycode
		if code == KEY_ESCAPE:
			if previewing_main:
				set_preview_main(false)
			elif _selected != null:
				_select(null)
			else:
				set_active(false)
			return true
		if previewing_main:
			return true
		if code == KEY_DELETE or code == KEY_BACKSPACE:
			_delete_selected()
			return true
	if previewing_main:
		return event is InputEventMouse
	if is_pointer_over_ui(_event_pos(event)):
		return false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_rmb_look = mb.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if mb.pressed else Input.MOUSE_MODE_VISIBLE
			return true
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_move_speed = clampf(_move_speed * 1.12, 0.4, 18.0)
			return true
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_move_speed = clampf(_move_speed / 1.12, 0.4, 18.0)
			return true
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var axis := _pick_gizmo_axis(mb.position)
				if axis >= 0 and _selected != null:
					_gizmo_axis = axis
					_gizmo_grab_origin = _axis_grab_world(mb.position, axis)
					_gizmo_grab_obj = _selected.global_position
					return true
				_click_select(mb.position)
				return true
			_gizmo_axis = -1
			return true
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _rmb_look:
			_look_yaw -= mm.relative.x * 0.12
			_look_pitch = clampf(_look_pitch - mm.relative.y * 0.12, -89.0, 89.0)
			_apply_fly_look()
			return true
		if _gizmo_axis >= 0 and _selected != null:
			var now := _axis_grab_world(mm.position, _gizmo_axis)
			var delta := now - _gizmo_grab_origin
			_selected.global_position = _gizmo_grab_obj + delta
			_update_gizmo()
			_refresh_inspector_values()
			return true
	return false


func update_fly(delta: float) -> void:
	if not active or previewing_main or _fly_cam == null:
		return
	var wish := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		wish.z -= 1.0
	if Input.is_key_pressed(KEY_S):
		wish.z += 1.0
	if Input.is_key_pressed(KEY_A):
		wish.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		wish.x += 1.0
	if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_SPACE):
		wish.y += 1.0
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_CTRL):
		wish.y -= 1.0
	if wish != Vector3.ZERO:
		wish = wish.normalized()
		var sprint := 2.35 if Input.is_key_pressed(KEY_SHIFT) else 1.0
		var basis := _fly_cam.global_basis
		var move := (basis.x * wish.x + Vector3.UP * wish.y + basis.z * wish.z) * _move_speed * sprint * delta
		_fly_cam.global_position += move
	_update_gizmo()


func _apply_fly_look() -> void:
	if _fly_cam == null:
		return
	_fly_cam.rotation_degrees = Vector3(_look_pitch, _look_yaw, 0.0)


func _event_pos(event: InputEvent) -> Vector2:
	if event is InputEventMouse:
		return (event as InputEventMouse).position
	return _game.get_viewport().get_mouse_position() if _game else Vector2.ZERO


func _cam() -> Camera3D:
	if previewing_main:
		return _main_cam
	return _fly_cam if _fly_cam != null and _fly_cam.current else _main_cam


func _ensure_dressing_root() -> void:
	if _world == null:
		return
	_dressing = _world.get_node_or_null("LevelDressing") as Node3D
	if _dressing == null:
		_dressing = Node3D.new()
		_dressing.name = "LevelDressing"
		_world.add_child(_dressing)


func _build_fly_cam() -> void:
	if _world == null:
		return
	_fly_cam = Camera3D.new()
	_fly_cam.name = "LevelEditorFlyCam"
	_fly_cam.current = false
	_fly_cam.fov = 58.0
	_world.add_child(_fly_cam)


func _build_gizmo() -> void:
	_gizmo = Node3D.new()
	_gizmo.name = "LevelEditorGizmo"
	_gizmo.visible = false
	if _world:
		_world.add_child(_gizmo)
	_add_gizmo_axis(Vector3(1, 0, 0), Color(0.92, 0.22, 0.18), "AxisX")
	_add_gizmo_axis(Vector3(0, 1, 0), Color(0.28, 0.86, 0.32), "AxisY")
	_add_gizmo_axis(Vector3(0, 0, 1), Color(0.22, 0.48, 1.0), "AxisZ")


func _add_gizmo_axis(dir: Vector3, color: Color, node_name: String) -> void:
	var shaft := MeshInstance3D.new()
	shaft.name = node_name
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.008
	cyl.bottom_radius = 0.008
	cyl.height = GIZMO_LEN
	cyl.radial_segments = 8
	shaft.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.no_depth_test = true
	mat.render_priority = 80
	shaft.material_override = mat
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tip := MeshInstance3D.new()
	tip.name = node_name + "Tip"
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.022
	cone.height = 0.06
	cone.radial_segments = 10
	tip.mesh = cone
	tip.material_override = mat
	tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var holder := Node3D.new()
	holder.name = node_name + "Hold"
	if dir.y > 0.5:
		shaft.position = Vector3(0, GIZMO_LEN * 0.5, 0)
		tip.position = Vector3(0, GIZMO_LEN + 0.03, 0)
	elif dir.x > 0.5:
		holder.rotation_degrees = Vector3(0, 0, -90)
		shaft.position = Vector3(0, GIZMO_LEN * 0.5, 0)
		tip.position = Vector3(0, GIZMO_LEN + 0.03, 0)
	else:
		holder.rotation_degrees = Vector3(90, 0, 0)
		shaft.position = Vector3(0, GIZMO_LEN * 0.5, 0)
		tip.position = Vector3(0, GIZMO_LEN + 0.03, 0)
	holder.add_child(shaft)
	holder.add_child(tip)
	_gizmo.add_child(holder)


func _update_gizmo() -> void:
	if _gizmo == null:
		return
	if _selected == null or not is_instance_valid(_selected) or previewing_main:
		_gizmo.visible = false
		return
	_gizmo.visible = true
	_gizmo.global_position = _selected.global_position
	_gizmo.global_basis = Basis.IDENTITY


func _pick_gizmo_axis(screen_pos: Vector2) -> int:
	if _selected == null or _gizmo == null or not _gizmo.visible:
		return -1
	var cam := _cam()
	if cam == null:
		return -1
	var origin := _selected.global_position
	if cam.is_position_behind(origin):
		return -1
	var best := -1
	var best_d := GIZMO_HIT_PX
	var axes := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	for i in 3:
		var axis_v: Vector3 = axes[i]
		var tip: Vector3 = origin + axis_v * (GIZMO_LEN + 0.04)
		if cam.is_position_behind(tip):
			continue
		var a := cam.unproject_position(origin)
		var b := cam.unproject_position(tip)
		var d := _dist_to_segment(screen_pos, a, b)
		if d < best_d:
			best_d = d
			best = i
	return best


func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := 0.0 if ab.length_squared() < 0.001 else clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _axis_grab_world(screen_pos: Vector2, axis: int) -> Vector3:
	var cam := _cam()
	if cam == null or _selected == null:
		return Vector3.ZERO
	var origin := _selected.global_position
	var dir: Vector3 = [Vector3.RIGHT, Vector3.UP, Vector3.BACK][axis]
	var ray_o := cam.project_ray_origin(screen_pos)
	var ray_d := cam.project_ray_normal(screen_pos)
	var n := ray_d.cross(dir).cross(ray_d)
	if n.length_squared() < 0.00001:
		return origin
	n = n.normalized()
	var denom: float = dir.dot(n)
	if absf(denom) < 0.00001:
		return origin
	var t: float = (ray_o - origin).dot(n) / denom
	return origin + dir * t


func _click_select(screen_pos: Vector2) -> void:
	var cam := _cam()
	if cam == null or _game == null:
		return
	var from := cam.project_ray_origin(screen_pos)
	var to := from + cam.project_ray_normal(screen_pos) * 40.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collide_with_areas = true
	q.collide_with_bodies = true
	var hit: Dictionary = _game.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var col: Object = hit.get("collider")
		if col is Node:
			_select(_pickable_from(col as Node))
			return
	_select(_closest_visual_at(screen_pos))


func _pickable_from(node: Node) -> Node3D:
	var n: Node = node
	while n != null:
		if n == _gizmo or (n is Node and _gizmo != null and _gizmo.is_ancestor_of(n)):
			return _selected
		if n is Light3D:
			return n as Node3D
		if n is Node3D and n.get_parent() == _dressing:
			return n as Node3D
		if n is MeshInstance3D:
			return n as Node3D
		n = n.get_parent()
	return node as Node3D if node is Node3D else null


func _closest_visual_at(screen_pos: Vector2) -> Node3D:
	var cam := _cam()
	if cam == null:
		return null
	var best: Node3D = null
	var best_d := 36.0
	for node in _outliner_nodes:
		if node == null or not is_instance_valid(node) or not (node is Node3D):
			continue
		var p: Vector3 = (node as Node3D).global_position
		if cam.is_position_behind(p):
			continue
		var d := screen_pos.distance_to(cam.unproject_position(p))
		if d < best_d:
			best_d = d
			best = node
	return best


func _select(node: Node3D) -> void:
	if node != null and not is_instance_valid(node):
		node = null
	_selected = node
	_update_gizmo()
	_sync_outliner_selection()
	_rebuild_inspector()
	if node != null:
		_set_status("Selected %s" % node.name)


func _delete_selected() -> void:
	if _selected == null or not is_instance_valid(_selected):
		return
	if _dressing == null or not _dressing.is_ancestor_of(_selected) and _selected.get_parent() != _dressing:
		_set_status("Can't delete original level objects — only placed dressing")
		return
	var gone := _selected
	_select(null)
	gone.queue_free()
	call_deferred("_refresh_outliner")
	_save_dressing()
	_set_status("Deleted")


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "LevelEditorLayer"
	_layer.layer = 80
	_layer.visible = false
	_game.add_child(_layer)
	_ui = Control.new()
	_ui.name = "LevelEditorUI"
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_ui)
	_build_top_bar()
	_build_outliner_panel()
	_build_inspector_panel()


func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.09, 0.12, 0.94)
	sb.border_color = Color(0.42, 0.55, 0.68, 0.9)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _style_btn(btn: Button) -> void:
	btn.focus_mode = Control.FOCUS_NONE
	UiFontsScript.apply_button(btn, false, 12)
	btn.add_theme_color_override("font_color", Color(0.9, 0.93, 0.97))


func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	bar.name = "TopBar"
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.add_theme_stylebox_override("panel", _panel_style())
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 286.0
	bar.offset_right = -290.0
	bar.offset_top = 8.0
	bar.offset_bottom = 78.0
	_ui.add_child(bar)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	bar.add_child(v)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	for spec in [
		["Omni Light", func(): _place_light("omni")],
		["Spot Light", func(): _place_light("spot")],
		["Cube", func(): _place_primitive("cube")],
		["Sphere", func(): _place_primitive("sphere")],
		["Cylinder", func(): _place_primitive("cylinder")],
		["Plane", func(): _place_primitive("plane")],
		["Napkin", func(): _place_napkin()],
	]:
		var b := Button.new()
		b.text = str(spec[0])
		b.custom_minimum_size = Vector2(0, 28)
		_style_btn(b)
		b.pressed.connect(spec[1])
		row.add_child(b)
	_preview_btn = Button.new()
	_preview_btn.text = "Preview Main Cam"
	_preview_btn.custom_minimum_size = Vector2(0, 28)
	_style_btn(_preview_btn)
	_preview_btn.pressed.connect(func():
		set_preview_main(not previewing_main)
	)
	row.add_child(_preview_btn)
	var close_btn := Button.new()
	close_btn.text = "Exit (L)"
	close_btn.custom_minimum_size = Vector2(0, 28)
	_style_btn(close_btn)
	close_btn.pressed.connect(func(): set_active(false))
	row.add_child(close_btn)
	_status = Label.new()
	_status.text = "L-mode"
	UiFontsScript.apply_label(_status, false, 11)
	_status.add_theme_color_override("font_color", Color(0.78, 0.86, 0.94))
	v.add_child(_status)


func _refresh_preview_button() -> void:
	if _preview_btn == null:
		return
	_preview_btn.text = "Back to Fly Cam" if previewing_main else "Preview Main Cam"


func refresh_lighting_ui() -> void:
	if _selected != null and not is_instance_valid(_selected):
		_selected = null
		_update_gizmo()
	_refresh_profile_buttons()
	_sync_sun_pad_from_game()
	_refresh_outliner()
	if _inspector != null:
		_inspector_busy = true
		_rebuild_inspector()
		_inspector_busy = false


func _build_lighting_controls(parent: VBoxContainer) -> void:
	var head := Label.new()
	head.text = "LIGHTING PROFILES"
	UiFontsScript.apply_label(head, true, 12)
	head.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45))
	parent.add_child(head)
	var names: Array[String] = ["1 Classic", "2 Window Key", "3 Short Order", "4 Feature Rig"]
	if _game != null and _game.has_method("get_light_profile_names"):
		var from_game: Array = _game.get_light_profile_names()
		if from_game.size() >= 4:
			names.clear()
			for n in from_game:
				names.append(str(n))
	_profile_btns.clear()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	parent.add_child(grid)
	for i in names.size():
		var b := Button.new()
		b.text = names[i]
		b.custom_minimum_size = Vector2(0, 26)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_btn(b)
		b.pressed.connect(_on_profile_pressed.bind(i))
		grid.add_child(b)
		_profile_btns.append(b)
	var sun_head := Label.new()
	sun_head.text = "SUN SKY"
	UiFontsScript.apply_label(sun_head, true, 12)
	sun_head.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45))
	parent.add_child(sun_head)
	_sun_lab = Label.new()
	_sun_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiFontsScript.apply_label(_sun_lab, false, 11)
	_sun_lab.add_theme_color_override("font_color", Color(0.78, 0.86, 0.94))
	parent.add_child(_sun_lab)
	_sun_pad = SunSkyPadScript.new()
	_sun_pad.name = "SunSkyPad"
	_sun_pad.sky_changed.connect(_on_sun_sky_changed)
	parent.add_child(_sun_pad)
	var spin_row := HBoxContainer.new()
	spin_row.add_theme_constant_override("separation", 6)
	parent.add_child(spin_row)
	_sun_azim_spin = _make_sun_spin("Az", -15.0, 110.0, func(v: float):
		if _lighting_busy:
			return
		_apply_sun_spins()
	)
	_sun_elev_spin = _make_sun_spin("El", 16.0, 58.0, func(v: float):
		if _lighting_busy:
			return
		_apply_sun_spins()
	)
	spin_row.add_child(_sun_azim_spin)
	spin_row.add_child(_sun_elev_spin)
	var reset_btn := Button.new()
	reset_btn.text = "Reset Sun"
	reset_btn.custom_minimum_size = Vector2(0, 26)
	_style_btn(reset_btn)
	reset_btn.pressed.connect(func():
		if _game != null and _game.has_method("reset_profile_sun_sky"):
			_game.reset_profile_sun_sky()
		_set_status("Sun reset for this profile")
	)
	parent.add_child(reset_btn)
	_refresh_profile_buttons()
	_sync_sun_pad_from_game()


func _make_sun_spin(prefix: String, mn: float, mx: float, changed: Callable) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = mn
	spin.max_value = mx
	spin.step = 0.5
	spin.custom_minimum_size = Vector2(118, 0)
	spin.prefix = prefix + " "
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.value_changed.connect(changed)
	return spin


func _on_profile_pressed(id: int) -> void:
	if _game != null and _game.has_method("set_light_profile"):
		_game.set_light_profile(id)
	var label: String = str(id + 1)
	if id >= 0 and id < _profile_btns.size():
		label = _profile_btns[id].text
	_set_status("Lighting profile — %s" % label)


func _on_sun_sky_changed(azim: float, elev: float) -> void:
	if _game != null and _game.has_method("set_profile_sun_sky"):
		_game.set_profile_sun_sky(azim, elev)
	_lighting_busy = true
	if _sun_azim_spin:
		_sun_azim_spin.set_value_no_signal(azim)
	if _sun_elev_spin:
		_sun_elev_spin.set_value_no_signal(elev)
	_lighting_busy = false
	_refresh_sun_label(azim, elev)


func _apply_sun_spins() -> void:
	if _sun_azim_spin == null or _sun_elev_spin == null:
		return
	var azim: float = float(_sun_azim_spin.value)
	var elev: float = float(_sun_elev_spin.value)
	if _sun_pad:
		_sun_pad.set_sky(azim, elev)
	if _game != null and _game.has_method("set_profile_sun_sky"):
		_game.set_profile_sun_sky(azim, elev)
	_refresh_sun_label(azim, elev)


func _refresh_profile_buttons() -> void:
	var active: int = 1
	if _game != null and _game.has_method("get_light_profile_id"):
		active = int(_game.get_light_profile_id())
	for i in _profile_btns.size():
		var b: Button = _profile_btns[i]
		var on: bool = i == active
		b.modulate = Color(1.15, 0.95, 0.62) if on else Color.WHITE
		b.disabled = on


func _sync_sun_pad_from_game() -> void:
	var azim: float = 26.0
	var elev: float = 36.0
	if _game != null and _game.has_method("get_light_profile_sun_sky"):
		var sky: Vector2 = _game.get_light_profile_sun_sky()
		azim = sky.x
		elev = sky.y
	_lighting_busy = true
	if _sun_pad:
		_sun_pad.set_sky(azim, elev)
	if _sun_azim_spin:
		_sun_azim_spin.set_value_no_signal(azim)
	if _sun_elev_spin:
		_sun_elev_spin.set_value_no_signal(elev)
	_lighting_busy = false
	_refresh_sun_label(azim, elev)


func _refresh_sun_label(azim: float, elev: float) -> void:
	if _sun_lab == null:
		return
	var classic: bool = false
	var sky_owned: bool = true
	if _game != null and _game.has_method("get_light_profile_id"):
		classic = int(_game.get_light_profile_id()) <= 0
	if classic and _game != null and _game.has_method("classic_sun_uses_sky"):
		sky_owned = bool(_game.classic_sun_uses_sky())
	if classic and not sky_owned:
		_sun_lab.text = "Classic sun uses the original rig. Drag the disc to take over. Az %.0f°  El %.0f°" % [azim, elev]
	else:
		_sun_lab.text = "Drag the disc — right is camera-right, up is the window. Az %.0f°  El %.0f°" % [azim, elev]


func _build_outliner_panel() -> void:
	var panel := PanelContainer.new()
	panel.name = "Outliner"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_left = 8.0
	panel.offset_right = 278.0
	panel.offset_top = 8.0
	panel.offset_bottom = -8.0
	_ui.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	var title := Label.new()
	title.text = "WORLD OUTLINER"
	UiFontsScript.apply_label(title, true, 13)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45))
	v.add_child(title)
	_build_lighting_controls(v)
	_outliner = ItemList.new()
	_outliner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_outliner.allow_reselect = true
	_outliner.item_selected.connect(func(idx: int):
		if idx >= 0 and idx < _outliner_nodes.size():
			var node = _outliner_nodes[idx]
			_select(node if node is Node3D else null)
	)
	v.add_child(_outliner)


func _build_inspector_panel() -> void:
	var panel := PanelContainer.new()
	panel.name = "Inspector"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -282.0
	panel.offset_right = -8.0
	panel.offset_top = 8.0
	panel.offset_bottom = -8.0
	_ui.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_inspector = VBoxContainer.new()
	_inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inspector.add_theme_constant_override("separation", 6)
	scroll.add_child(_inspector)
	_rebuild_inspector()


func _refresh_outliner() -> void:
	if _outliner == null:
		return
	_outliner_nodes.clear()
	_outliner.clear()
	if _dressing != null:
		for child in _dressing.get_children():
			if child is Node3D:
				_add_outliner_item("Dressing / %s" % child.name, child)
	var lights: Array = []
	_collect_lights(_world, lights)
	if _grill != null:
		_collect_lights(_grill, lights)
	for light in lights:
		_add_outliner_item("Light / %s" % light.name, light)
	if _world != null:
		for child in _world.get_children():
			if child == _dressing or child == _fly_cam or child == _gizmo:
				continue
			if str(child.name) == "LightProfileRig":
				continue
			if child is Node3D:
				_add_outliner_item("World / %s" % child.name, child)
	if _grill != null:
		for child in _grill.get_children():
			if child is Node3D:
				_add_outliner_item("Grill / %s" % child.name, child)
	_sync_outliner_selection()


func _collect_lights(root: Node, out: Array) -> void:
	if root == null:
		return
	if root is Light3D:
		out.append(root)
	for child in root.get_children():
		_collect_lights(child, out)


func _add_outliner_item(label: String, node: Node) -> void:
	_outliner.add_item(label)
	_outliner_nodes.append(node)


func _sync_outliner_selection() -> void:
	if _outliner == null:
		return
	for i in _outliner_nodes.size():
		if _outliner_nodes[i] == _selected:
			_outliner.select(i)
			return
	_outliner.deselect_all()


func _rebuild_inspector() -> void:
	if _inspector == null:
		return
	for child in _inspector.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "PROPERTIES"
	UiFontsScript.apply_label(title, true, 13)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45))
	_inspector.add_child(title)
	if _selected == null or not is_instance_valid(_selected):
		var empty := Label.new()
		empty.text = "Select a light, mesh, or dressing object."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UiFontsScript.apply_label(empty, false, 12)
		empty.add_theme_color_override("font_color", Color(0.72, 0.78, 0.86))
		_inspector.add_child(empty)
		_add_napkin_look_controls(false)
		return
	var name_lab := Label.new()
	name_lab.text = _selected.name
	name_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiFontsScript.apply_label(name_lab, true, 14)
	_inspector.add_child(name_lab)
	_add_inspect_spin("Pos X", _selected.global_position.x, -12.0, 12.0, 0.01, func(v): _set_sel_pos("x", v))
	_add_inspect_spin("Pos Y", _selected.global_position.y, -4.0, 8.0, 0.01, func(v): _set_sel_pos("y", v))
	_add_inspect_spin("Pos Z", _selected.global_position.z, -12.0, 18.0, 0.01, func(v): _set_sel_pos("z", v))
	_add_inspect_spin("Rot X", _selected.rotation_degrees.x, -180.0, 180.0, 0.1, func(v): _set_sel_rot("x", v))
	_add_inspect_spin("Rot Y", _selected.rotation_degrees.y, -180.0, 180.0, 0.1, func(v): _set_sel_rot("y", v))
	_add_inspect_spin("Rot Z", _selected.rotation_degrees.z, -180.0, 180.0, 0.1, func(v): _set_sel_rot("z", v))
	_add_inspect_spin("Scale", _selected.scale.x, 0.05, 8.0, 0.01, func(v):
		if _selected:
			_selected.scale = Vector3.ONE * v
			_save_if_dressing()
	)
	_add_napkin_look_controls(_is_napkin(_selected))
	if _selected is Light3D:
		var light := _selected as Light3D
		_add_inspect_spin("Brightness", light.light_energy, 0.0, 16.0, 0.05, func(v):
			if _selected is Light3D:
				(_selected as Light3D).light_energy = v
				_save_if_dressing()
		)
		_add_inspect_spin("Specular Strength", light.light_specular, 0.0, 2.0, 0.01, func(v):
			if _selected is Light3D:
				(_selected as Light3D).light_specular = v
				_save_if_dressing()
		)
		if light is DirectionalLight3D:
			var sun := light as DirectionalLight3D
			_add_inspect_spin("Light Source Size", sun.light_angular_distance, 0.0, 10.0, 0.05, func(v):
				if _selected is DirectionalLight3D:
					(_selected as DirectionalLight3D).light_angular_distance = v
					_save_if_dressing()
			)
		else:
			_add_inspect_spin("Light Source Size", light.light_size, 0.0, 2.0, 0.01, func(v):
				if _selected is Light3D:
					(_selected as Light3D).light_size = v
					_save_if_dressing()
			)
		_add_inspect_spin("Range", _light_range(light), 0.1, 20.0, 0.05, func(v):
			_set_light_range(v)
		)
		if light is SpotLight3D:
			_add_inspect_spin("Spot Angle", (light as SpotLight3D).spot_angle, 1.0, 80.0, 0.5, func(v):
				if _selected is SpotLight3D:
					(_selected as SpotLight3D).spot_angle = v
					_save_if_dressing()
			)
		var vis := CheckButton.new()
		vis.text = "Visible"
		vis.button_pressed = light.visible
		UiFontsScript.apply_button(vis, false, 12)
		vis.toggled.connect(func(on: bool):
			if _selected:
				_selected.visible = on
				_save_if_dressing()
		)
		_inspector.add_child(vis)
		_add_light_shadow_controls(light)
	if _selected.get_parent() == _dressing:
		var del := Button.new()
		del.text = "Delete Object"
		_style_btn(del)
		del.pressed.connect(_delete_selected)
		_inspector.add_child(del)


func _add_inspect_spin(label_text: String, value: float, mn: float, mx: float, step: float, setter: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lab := Label.new()
	lab.text = label_text
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiFontsScript.apply_label(lab, false, 12)
	lab.add_theme_color_override("font_color", Color(0.82, 0.86, 0.92))
	row.add_child(lab)
	var spin := SpinBox.new()
	spin.min_value = mn
	spin.max_value = mx
	spin.step = step
	spin.value = value
	spin.custom_minimum_size = Vector2(96, 0)
	spin.value_changed.connect(func(v: float):
		if _inspector_busy:
			return
		setter.call(v)
		_update_gizmo()
	)
	row.add_child(spin)
	_inspector.add_child(row)


func _add_inspect_check(label_text: String, on: bool, setter: Callable) -> void:
	var btn := CheckButton.new()
	btn.text = label_text
	btn.button_pressed = on
	UiFontsScript.apply_button(btn, false, 12)
	btn.toggled.connect(func(pressed: bool):
		if _inspector_busy:
			return
		setter.call(pressed)
	)
	_inspector.add_child(btn)


func _add_light_shadow_controls(light: Light3D) -> void:
	var head := Label.new()
	head.text = "SHADOWS"
	UiFontsScript.apply_label(head, true, 12)
	head.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45))
	_inspector.add_child(head)
	_add_inspect_check("Cast Shadows", light.shadow_enabled, func(on: bool):
		if _selected is Light3D:
			(_selected as Light3D).shadow_enabled = on
			_save_if_dressing()
	)
	_add_inspect_spin("Shadow Blur", light.shadow_blur, 0.0, 4.0, 0.05, func(v: float):
		if _selected is Light3D:
			(_selected as Light3D).shadow_blur = v
			_save_if_dressing()
	)
	_add_inspect_spin("Shadow Bias", light.shadow_bias, 0.0, 0.5, 0.001, func(v: float):
		if _selected is Light3D:
			(_selected as Light3D).shadow_bias = v
			_save_if_dressing()
	)
	_add_inspect_spin("Normal Bias", light.shadow_normal_bias, 0.0, 4.0, 0.05, func(v: float):
		if _selected is Light3D:
			(_selected as Light3D).shadow_normal_bias = v
			_save_if_dressing()
	)
	_add_inspect_spin("Shadow Opacity", light.shadow_opacity, 0.0, 1.0, 0.01, func(v: float):
		if _selected is Light3D:
			(_selected as Light3D).shadow_opacity = v
			_save_if_dressing()
	)
	_add_inspect_check("Reverse Cull Face", light.shadow_reverse_cull_face, func(on: bool):
		if _selected is Light3D:
			(_selected as Light3D).shadow_reverse_cull_face = on
			_save_if_dressing()
	)
	if light is DirectionalLight3D:
		var sun := light as DirectionalLight3D
		_add_inspect_spin("Shadow Max Distance", sun.directional_shadow_max_distance, 4.0, 80.0, 0.5, func(v: float):
			if _selected is DirectionalLight3D:
				(_selected as DirectionalLight3D).directional_shadow_max_distance = v
				_save_if_dressing()
		)
		_add_inspect_spin("Shadow Fade Start", sun.directional_shadow_fade_start, 0.1, 1.0, 0.01, func(v: float):
			if _selected is DirectionalLight3D:
				(_selected as DirectionalLight3D).directional_shadow_fade_start = v
				_save_if_dressing()
		)
		_add_inspect_spin("Pancake Size", sun.directional_shadow_pancake_size, 0.0, 8.0, 0.05, func(v: float):
			if _selected is DirectionalLight3D:
				(_selected as DirectionalLight3D).directional_shadow_pancake_size = v
				_save_if_dressing()
		)
	elif light is OmniLight3D:
		var omni := light as OmniLight3D
		_add_inspect_check("Cube Omni Shadows", omni.omni_shadow_mode == OmniLight3D.SHADOW_CUBE, func(on: bool):
			if _selected is OmniLight3D:
				(_selected as OmniLight3D).omni_shadow_mode = (
					OmniLight3D.SHADOW_CUBE if on else OmniLight3D.SHADOW_DUAL_PARABOLOID
				)
				_save_if_dressing()
		)


func _is_napkin(n: Node) -> bool:
	return n != null and n is Node3D and (n as Node3D).name.begins_with("Napkin")


func _napkin_tint(darkness: float) -> Color:
	var b: float = clampf(1.0 - darkness, 0.08, 1.0)
	return Color(b, b, b, 1.0)


func _napkin_darkness_of(n: Node) -> float:
	if n == null or not n.has_meta("napkin_darkness"):
		return _napkin_darkness_default
	return clampf(float(n.get_meta("napkin_darkness")), 0.0, 0.90)


func _napkin_pattern_of(n: Node) -> float:
	if n == null or not n.has_meta("napkin_pattern_scale"):
		return _napkin_pattern_scale_default
	return clampf(float(n.get_meta("napkin_pattern_scale")), 0.25, 24.0)


func _apply_napkin_darkness(mi: MeshInstance3D, darkness: float) -> void:
	if mi == null:
		return
	var d: float = clampf(darkness, 0.0, 0.90)
	mi.set_meta("napkin_darkness", d)
	var mat := mi.material_override as StandardMaterial3D
	if mat == null:
		mat = _make_napkin_mat(d, _napkin_pattern_of(mi))
		mi.material_override = mat
	else:
		mat.albedo_color = _napkin_tint(d)


func _apply_napkin_pattern_scale(mi: MeshInstance3D, pattern_scale: float) -> void:
	if mi == null:
		return
	var s: float = clampf(pattern_scale, 0.25, 24.0)
	mi.set_meta("napkin_pattern_scale", s)
	var mat := mi.material_override as StandardMaterial3D
	if mat == null:
		mat = _make_napkin_mat(_napkin_darkness_of(mi), s)
		mi.material_override = mat
	else:
		mat.uv1_scale = Vector3(s, s, 1.0)


func _set_all_napkin_darkness(darkness: float) -> void:
	_napkin_darkness_default = clampf(darkness, 0.0, 0.90)
	if _dressing == null:
		return
	for child in _dressing.get_children():
		if child is MeshInstance3D and _is_napkin(child):
			_apply_napkin_darkness(child as MeshInstance3D, _napkin_darkness_default)
	_save_dressing()


func _set_all_napkin_pattern_scale(pattern_scale: float) -> void:
	_napkin_pattern_scale_default = clampf(pattern_scale, 0.25, 24.0)
	if _dressing == null:
		return
	for child in _dressing.get_children():
		if child is MeshInstance3D and _is_napkin(child):
			_apply_napkin_pattern_scale(child as MeshInstance3D, _napkin_pattern_scale_default)
	_save_dressing()


func _add_napkin_look_controls(include_selected: bool) -> void:
	if include_selected and _selected is MeshInstance3D:
		_add_inspect_spin("Napkin Darkness", _napkin_darkness_of(_selected), 0.0, 0.90, 0.01, func(v: float):
			if _selected is MeshInstance3D and _is_napkin(_selected):
				_apply_napkin_darkness(_selected as MeshInstance3D, v)
				_save_if_dressing()
		)
		_add_inspect_spin("Pattern Scale", _napkin_pattern_of(_selected), 0.25, 24.0, 0.05, func(v: float):
			if _selected is MeshInstance3D and _is_napkin(_selected):
				_apply_napkin_pattern_scale(_selected as MeshInstance3D, v)
				_save_if_dressing()
		)
	var has_napkin := false
	if _dressing != null:
		for child in _dressing.get_children():
			if _is_napkin(child):
				has_napkin = true
				break
	if has_napkin or include_selected:
		_add_inspect_spin("All Napkins Darkness", _napkin_darkness_default, 0.0, 0.90, 0.01, func(v: float):
			_set_all_napkin_darkness(v)
		)
		_add_inspect_spin("All Napkins Pattern Scale", _napkin_pattern_scale_default, 0.25, 24.0, 0.05, func(v: float):
			_set_all_napkin_pattern_scale(v)
		)


func _refresh_inspector_values() -> void:
	## Rebuild is simplest after a gizmo drag.
	_inspector_busy = true
	_rebuild_inspector()
	_inspector_busy = false


func _set_sel_pos(axis: String, v: float) -> void:
	if _selected == null:
		return
	var p := _selected.global_position
	match axis:
		"x": p.x = v
		"y": p.y = v
		"z": p.z = v
	_selected.global_position = p
	_update_gizmo()
	_save_if_dressing()


func _set_sel_rot(axis: String, v: float) -> void:
	if _selected == null:
		return
	var r := _selected.rotation_degrees
	match axis:
		"x": r.x = v
		"y": r.y = v
		"z": r.z = v
	_selected.rotation_degrees = r
	_save_if_dressing()


func _light_range(light: Light3D) -> float:
	if light is OmniLight3D:
		return (light as OmniLight3D).omni_range
	if light is SpotLight3D:
		return (light as SpotLight3D).spot_range
	return 0.0


func _set_light_range(v: float) -> void:
	if _selected is OmniLight3D:
		(_selected as OmniLight3D).omni_range = v
	elif _selected is SpotLight3D:
		(_selected as SpotLight3D).spot_range = v
	_save_if_dressing()


func _place_point() -> Vector3:
	var cam := _cam()
	if cam == null:
		return Vector3(0.0, 1.02, 0.08)
	var origin := cam.global_position
	var forward := -cam.global_basis.z
	var y := 1.02
	if absf(forward.y) > 0.02:
		var t := (y - origin.y) / forward.y
		if t > 0.35 and t < 8.0:
			return origin + forward * t
	return origin + forward * 1.45


func _place_light(kind: String) -> void:
	var light := _make_dressing_light(kind)
	light.position = _place_point() + Vector3(0.0, 0.35, 0.0)
	_finish_place(light)


func _place_primitive(kind: String) -> void:
	var mi := _make_dressing_primitive(kind)
	mi.position = _place_point()
	_finish_place(mi)


func _place_napkin() -> void:
	var mi := _make_dressing_napkin()
	mi.position = _place_point()
	mi.position.y = 1.055
	_finish_place(mi)
	_set_status("Placed napkin — drag the gizmos to dress the counter")


func _finish_place(node: Node3D) -> void:
	_ensure_dressing_root()
	_dressing.add_child(node)
	_select(node)
	_refresh_outliner()
	_save_dressing()
	_set_status("Placed %s" % node.name)


func _make_dressing_light(kind: String) -> Light3D:
	_place_counter += 1
	var light: Light3D
	if kind == "spot":
		var spot := SpotLight3D.new()
		spot.spot_range = 3.2
		spot.spot_angle = 40.0
		spot.rotation_degrees = Vector3(-55.0, 0.0, 0.0)
		light = spot
	else:
		var omni := OmniLight3D.new()
		omni.omni_range = 2.8
		light = omni
	light.name = "%sLight_%d" % [kind.capitalize(), _place_counter]
	light.light_color = Color(1.0, 0.92, 0.78)
	light.light_energy = 1.4
	light.shadow_enabled = true
	light.shadow_blur = 1.15
	light.shadow_bias = 0.03
	light.shadow_normal_bias = 0.85
	light.shadow_opacity = 0.85
	if light is OmniLight3D:
		(light as OmniLight3D).omni_shadow_mode = OmniLight3D.SHADOW_CUBE
	return light


func _make_dressing_primitive(kind: String) -> MeshInstance3D:
	_place_counter += 1
	var mi := MeshInstance3D.new()
	mi.name = "%s_%d" % [kind.capitalize(), _place_counter]
	match kind:
		"sphere":
			var sph := SphereMesh.new()
			sph.radius = 0.08
			sph.height = 0.16
			mi.mesh = sph
		"cylinder":
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.06
			cyl.bottom_radius = 0.06
			cyl.height = 0.16
			mi.mesh = cyl
		"plane":
			var plane := PlaneMesh.new()
			plane.size = Vector2(0.32, 0.32)
			mi.mesh = plane
		_:
			var box := BoxMesh.new()
			box.size = Vector3(0.16, 0.16, 0.16)
			mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.76, 0.82)
	mat.metallic = 0.15
	mat.roughness = 0.55
	mi.material_override = mat
	return mi


func _make_dressing_napkin() -> MeshInstance3D:
	_place_counter += 1
	var mi := MeshInstance3D.new()
	mi.name = "Napkin_%d" % _place_counter
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.26, 0.26)
	mi.mesh = plane
	mi.material_override = _make_napkin_mat(_napkin_darkness_default, _napkin_pattern_scale_default)
	mi.set_meta("napkin_darkness", _napkin_darkness_default)
	mi.set_meta("napkin_pattern_scale", _napkin_pattern_scale_default)
	return mi


func _make_napkin_mat(darkness: float = 0.0, pattern_scale: float = 1.0) -> StandardMaterial3D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 8:
			var check := int(floor(float(x) / 2.0) + floor(float(y) / 2.0)) % 2 == 0
			img.set_pixel(x, y, Color(0.82, 0.10, 0.14) if check else Color(0.96, 0.96, 0.94))
	var tex := ImageTexture.create_from_image(img)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.albedo_color = _napkin_tint(darkness)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var s: float = clampf(pattern_scale, 0.25, 24.0)
	mat.uv1_scale = Vector3(s, s, 1.0)
	mat.roughness = 0.82
	mat.metallic = 0.0
	return mat


func _save_if_dressing() -> void:
	if _selected != null and _dressing != null and (_selected.get_parent() == _dressing or _dressing.is_ancestor_of(_selected)):
		_save_dressing()


func _save_dressing() -> void:
	if _dressing == null:
		return
	var cfg := ConfigFile.new()
	var i := 0
	for child in _dressing.get_children():
		if not (child is Node3D):
			continue
		var n := child as Node3D
		var p := "n%d_" % i
		cfg.set_value(SAVE_SECTION, p + "name", n.name)
		cfg.set_value(SAVE_SECTION, p + "kind", _dressing_kind(n))
		cfg.set_value(SAVE_SECTION, p + "x", n.position.x)
		cfg.set_value(SAVE_SECTION, p + "y", n.position.y)
		cfg.set_value(SAVE_SECTION, p + "z", n.position.z)
		cfg.set_value(SAVE_SECTION, p + "rx", n.rotation_degrees.x)
		cfg.set_value(SAVE_SECTION, p + "ry", n.rotation_degrees.y)
		cfg.set_value(SAVE_SECTION, p + "rz", n.rotation_degrees.z)
		cfg.set_value(SAVE_SECTION, p + "sx", n.scale.x)
		cfg.set_value(SAVE_SECTION, p + "vis", n.visible)
		if n is Light3D:
			var L := n as Light3D
			cfg.set_value(SAVE_SECTION, p + "energy", L.light_energy)
			cfg.set_value(SAVE_SECTION, p + "specular", L.light_specular)
			cfg.set_value(SAVE_SECTION, p + "size", L.light_size)
			cfg.set_value(SAVE_SECTION, p + "cr", L.light_color.r)
			cfg.set_value(SAVE_SECTION, p + "cg", L.light_color.g)
			cfg.set_value(SAVE_SECTION, p + "cb", L.light_color.b)
			cfg.set_value(SAVE_SECTION, p + "range", _light_range(L))
			cfg.set_value(SAVE_SECTION, p + "shadow", L.shadow_enabled)
			cfg.set_value(SAVE_SECTION, p + "sblur", L.shadow_blur)
			cfg.set_value(SAVE_SECTION, p + "sbias", L.shadow_bias)
			cfg.set_value(SAVE_SECTION, p + "snbias", L.shadow_normal_bias)
			cfg.set_value(SAVE_SECTION, p + "sopacity", L.shadow_opacity)
			cfg.set_value(SAVE_SECTION, p + "srev", L.shadow_reverse_cull_face)
			if L is SpotLight3D:
				cfg.set_value(SAVE_SECTION, p + "angle", (L as SpotLight3D).spot_angle)
			if L is OmniLight3D:
				cfg.set_value(SAVE_SECTION, p + "scube", (L as OmniLight3D).omni_shadow_mode == OmniLight3D.SHADOW_CUBE)
			if L is DirectionalLight3D:
				var sun := L as DirectionalLight3D
				cfg.set_value(SAVE_SECTION, p + "smax", sun.directional_shadow_max_distance)
				cfg.set_value(SAVE_SECTION, p + "sfade", sun.directional_shadow_fade_start)
		if _is_napkin(n):
			cfg.set_value(SAVE_SECTION, p + "dark", _napkin_darkness_of(n))
			cfg.set_value(SAVE_SECTION, p + "pattern", _napkin_pattern_of(n))
		i += 1
	cfg.set_value(SAVE_SECTION, "count", i)
	cfg.set_value(SAVE_SECTION, "napkin_darkness", _napkin_darkness_default)
	cfg.set_value(SAVE_SECTION, "napkin_pattern", _napkin_pattern_scale_default)
	cfg.save(SAVE_PATH)


func _dressing_kind(n: Node3D) -> String:
	if n is OmniLight3D:
		return "omni"
	if n is SpotLight3D:
		return "spot"
	if n.name.begins_with("Napkin"):
		return "napkin"
	if n is MeshInstance3D:
		var mesh := (n as MeshInstance3D).mesh
		if mesh is SphereMesh:
			return "sphere"
		if mesh is CylinderMesh:
			return "cylinder"
		if mesh is PlaneMesh:
			return "plane"
		return "cube"
	return "cube"


func _load_dressing() -> void:
	_ensure_dressing_root()
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for child in _dressing.get_children():
		child.queue_free()
	_napkin_darkness_default = clampf(float(cfg.get_value(SAVE_SECTION, "napkin_darkness", 0.0)), 0.0, 0.90)
	_napkin_pattern_scale_default = clampf(float(cfg.get_value(SAVE_SECTION, "napkin_pattern", 1.0)), 0.25, 24.0)
	var count := int(cfg.get_value(SAVE_SECTION, "count", 0))
	for i in count:
		var p := "n%d_" % i
		var kind := str(cfg.get_value(SAVE_SECTION, p + "kind", "cube"))
		var node: Node3D
		match kind:
			"omni":
				node = _make_dressing_light("omni")
			"spot":
				node = _make_dressing_light("spot")
			"napkin":
				node = _make_dressing_napkin()
			"sphere":
				node = _make_dressing_primitive("sphere")
			"cylinder":
				node = _make_dressing_primitive("cylinder")
			"plane":
				node = _make_dressing_primitive("plane")
			_:
				node = _make_dressing_primitive("cube")
		if node == null:
			continue
		node.name = str(cfg.get_value(SAVE_SECTION, p + "name", node.name))
		node.position = Vector3(
			float(cfg.get_value(SAVE_SECTION, p + "x", node.position.x)),
			float(cfg.get_value(SAVE_SECTION, p + "y", node.position.y)),
			float(cfg.get_value(SAVE_SECTION, p + "z", node.position.z))
		)
		node.rotation_degrees = Vector3(
			float(cfg.get_value(SAVE_SECTION, p + "rx", 0.0)),
			float(cfg.get_value(SAVE_SECTION, p + "ry", 0.0)),
			float(cfg.get_value(SAVE_SECTION, p + "rz", 0.0))
		)
		var sc := float(cfg.get_value(SAVE_SECTION, p + "sx", 1.0))
		node.scale = Vector3.ONE * sc
		node.visible = bool(cfg.get_value(SAVE_SECTION, p + "vis", true))
		if node is Light3D:
			var L := node as Light3D
			L.light_energy = float(cfg.get_value(SAVE_SECTION, p + "energy", L.light_energy))
			L.light_specular = float(cfg.get_value(SAVE_SECTION, p + "specular", L.light_specular))
			L.light_size = float(cfg.get_value(SAVE_SECTION, p + "size", L.light_size))
			L.light_color = Color(
				float(cfg.get_value(SAVE_SECTION, p + "cr", L.light_color.r)),
				float(cfg.get_value(SAVE_SECTION, p + "cg", L.light_color.g)),
				float(cfg.get_value(SAVE_SECTION, p + "cb", L.light_color.b))
			)
			if L is OmniLight3D:
				(L as OmniLight3D).omni_range = float(cfg.get_value(SAVE_SECTION, p + "range", 2.8))
			elif L is SpotLight3D:
				(L as SpotLight3D).spot_range = float(cfg.get_value(SAVE_SECTION, p + "range", 3.2))
				(L as SpotLight3D).spot_angle = float(cfg.get_value(SAVE_SECTION, p + "angle", 40.0))
			L.shadow_enabled = bool(cfg.get_value(SAVE_SECTION, p + "shadow", L.shadow_enabled))
			L.shadow_blur = float(cfg.get_value(SAVE_SECTION, p + "sblur", L.shadow_blur))
			L.shadow_bias = float(cfg.get_value(SAVE_SECTION, p + "sbias", L.shadow_bias))
			L.shadow_normal_bias = float(cfg.get_value(SAVE_SECTION, p + "snbias", L.shadow_normal_bias))
			L.shadow_opacity = float(cfg.get_value(SAVE_SECTION, p + "sopacity", L.shadow_opacity))
			L.shadow_reverse_cull_face = bool(cfg.get_value(SAVE_SECTION, p + "srev", L.shadow_reverse_cull_face))
			if L is OmniLight3D:
				(L as OmniLight3D).omni_shadow_mode = (
					OmniLight3D.SHADOW_CUBE
					if bool(cfg.get_value(SAVE_SECTION, p + "scube", true))
					else OmniLight3D.SHADOW_DUAL_PARABOLOID
				)
			if L is DirectionalLight3D:
				var sun := L as DirectionalLight3D
				sun.directional_shadow_max_distance = float(cfg.get_value(SAVE_SECTION, p + "smax", sun.directional_shadow_max_distance))
				sun.directional_shadow_fade_start = float(cfg.get_value(SAVE_SECTION, p + "sfade", sun.directional_shadow_fade_start))
		if node is MeshInstance3D and kind == "napkin":
			var napkin := node as MeshInstance3D
			_apply_napkin_darkness(
				napkin,
				float(cfg.get_value(SAVE_SECTION, p + "dark", _napkin_darkness_default))
			)
			_apply_napkin_pattern_scale(
				napkin,
				float(cfg.get_value(SAVE_SECTION, p + "pattern", _napkin_pattern_scale_default))
			)
		_dressing.add_child(node)
	_select(null)
	_refresh_outliner()


func _set_status(text: String) -> void:
	if _status:
		_status.text = text
