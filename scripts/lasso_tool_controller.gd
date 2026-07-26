## Lasso shape tool — draw freeform colored planes, select, transform, manage.
extends Node

const LassoShapeScript := preload("res://scripts/lasso_shape.gd")
const LassoToolUIScript := preload("res://scripts/lasso_tool_ui.gd")

enum ToolMode {
	LASSO,
	MOVE,
	SCALE,
	ROTATE,
}

signal active_changed(active: bool)
signal selection_changed
signal shapes_changed
signal tool_changed(mode: int)

var active: bool = false
var tool_mode: int = ToolMode.LASSO
var brush_color: Color = Color(0.95, 0.35, 0.2, 0.85)
var brush_material: int = 0
var brush_z_order: int = 0

var shapes: Array = [] ## LassoShape nodes
var selected: Node3D = null

var _game: Node = null
var _world_root: Node3D = null
var _ui: Control = null
var _preview: MeshInstance3D = null
var _preview_mat: StandardMaterial3D = null

var _drawing: bool = false
var _draw_pts: PackedVector3Array = PackedVector3Array()
var _draw_min_dist: float = 0.018

var _transforming: bool = false
var _grab_world: Vector3 = Vector3.ZERO
var _grab_pos: Vector3 = Vector3.ZERO
var _grab_scale: float = 1.0
var _grab_yaw: float = 0.0
var _grab_mouse: Vector2 = Vector2.ZERO
var _shape_counter: int = 0


func setup(game: Node, world_parent: Node3D, ui_parent: Control) -> void:
	_game = game
	_world_root = Node3D.new()
	_world_root.name = "LassoShapes"
	world_parent.add_child(_world_root)
	_ui = LassoToolUIScript.new()
	_ui.name = "LassoToolPanel"
	ui_parent.add_child(_ui)
	_ui.bind(self)
	_ui.visible = false
	_ensure_preview()


func is_active() -> bool:
	return active


func is_pointer_over_ui(screen_pos: Vector2) -> bool:
	if _ui == null or not _ui.visible:
		return false
	return _ui.get_global_rect().has_point(screen_pos)


func toggle_active() -> void:
	set_active(not active)


func set_active(on: bool) -> void:
	if active == on:
		return
	active = on
	if _ui:
		_ui.visible = on
		if on:
			_ui.refresh_all()
	if not on:
		_cancel_draw()
		_transforming = false
		_hide_preview()
	active_changed.emit(active)


func set_tool_mode(mode: int) -> void:
	tool_mode = clampi(mode, 0, 3)
	_cancel_draw()
	_transforming = false
	tool_changed.emit(tool_mode)
	if _ui:
		_ui.refresh_tool_buttons()


func select_shape(shape: Node3D) -> void:
	if selected == shape:
		return
	if selected != null and is_instance_valid(selected):
		selected.selected = false
	selected = shape
	if selected != null and is_instance_valid(selected):
		selected.selected = true
	selection_changed.emit()
	if _ui:
		_ui.refresh_selection()


func clear_selection() -> void:
	select_shape(null)


func delete_selected() -> void:
	if selected == null or not is_instance_valid(selected):
		return
	var doomed := selected
	select_shape(null)
	shapes.erase(doomed)
	doomed.queue_free()
	shapes_changed.emit()
	if _ui:
		_ui.refresh_shape_list()


func delete_shape(shape: Node3D) -> void:
	if shape == null or not is_instance_valid(shape):
		return
	if selected == shape:
		select_shape(null)
	shapes.erase(shape)
	shape.queue_free()
	shapes_changed.emit()
	if _ui:
		_ui.refresh_shape_list()


func bring_selected_forward() -> void:
	if selected == null:
		return
	selected.z_order = selected.z_order + 1
	selection_changed.emit()


func send_selected_backward() -> void:
	if selected == null:
		return
	selected.z_order = selected.z_order - 1
	selection_changed.emit()


func apply_brush_color(c: Color) -> void:
	brush_color = c
	if selected != null and is_instance_valid(selected):
		selected.opacity = c.a
		selected.set_fill_color(c)


func apply_brush_material(kind: int) -> void:
	brush_material = kind
	if selected != null and is_instance_valid(selected):
		selected.material_kind = kind


func apply_brush_z(z: int) -> void:
	brush_z_order = z
	if selected != null and is_instance_valid(selected):
		selected.z_order = z


func handle_input(event: InputEvent) -> bool:
	if not active:
		return false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if is_pointer_over_ui(mb.position):
				return false
			if mb.pressed:
				return _on_lmb_down(mb.position)
			else:
				return _on_lmb_up(mb.position)
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if is_pointer_over_ui(mb.position):
				return false
			_cancel_draw()
			clear_selection()
			return true
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed and selected != null:
			if tool_mode == ToolMode.SCALE:
				selected.set_uniform_scale(selected.get_uniform_scale() * 1.08)
				selection_changed.emit()
				return true
			if tool_mode == ToolMode.ROTATE:
				selected.set_yaw_degrees(selected.get_yaw_degrees() + 8.0)
				selection_changed.emit()
				return true
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed and selected != null:
			if tool_mode == ToolMode.SCALE:
				selected.set_uniform_scale(selected.get_uniform_scale() / 1.08)
				selection_changed.emit()
				return true
			if tool_mode == ToolMode.ROTATE:
				selected.set_yaw_degrees(selected.get_yaw_degrees() - 8.0)
				selection_changed.emit()
				return true
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _drawing:
			_append_draw_point(mm.position)
			return true
		if _transforming and selected != null and is_instance_valid(selected):
			_update_transform(mm.position)
			return true
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_DELETE or event.keycode == KEY_X:
			if selected != null:
				delete_selected()
			return true
		if event.keycode == KEY_ESCAPE:
			if _drawing:
				_cancel_draw()
				return true
			if selected != null:
				clear_selection()
				return true
			set_active(false)
			return true
		## 1-4 quick tool switch while lasso mode is on.
		if event.keycode == KEY_1:
			set_tool_mode(ToolMode.LASSO)
			return true
		if event.keycode == KEY_2:
			set_tool_mode(ToolMode.MOVE)
			return true
		if event.keycode == KEY_3:
			set_tool_mode(ToolMode.SCALE)
			return true
		if event.keycode == KEY_4:
			set_tool_mode(ToolMode.ROTATE)
			return true
	return false


func _on_lmb_down(screen_pos: Vector2) -> bool:
	match tool_mode:
		ToolMode.LASSO:
			var hit := _plane_from_screen(screen_pos)
			if hit == Vector3.ZERO:
				return true
			_drawing = true
			_draw_pts = PackedVector3Array()
			_draw_pts.append(hit)
			_update_preview()
			return true
		ToolMode.MOVE, ToolMode.SCALE, ToolMode.ROTATE:
			var hit2 := _plane_from_screen(screen_pos)
			var picked := _pick_shape(hit2, screen_pos)
			if picked != null:
				select_shape(picked)
				_transforming = true
				_grab_world = hit2
				_grab_pos = selected.position
				_grab_scale = selected.get_uniform_scale()
				_grab_yaw = selected.get_yaw_degrees()
				_grab_mouse = screen_pos
				return true
			clear_selection()
			return true
	return true


func _on_lmb_up(_screen_pos: Vector2) -> bool:
	if _drawing:
		_finish_draw()
		return true
	if _transforming:
		_transforming = false
		selection_changed.emit()
		return true
	return false


func _append_draw_point(screen_pos: Vector2) -> void:
	var hit := _plane_from_screen(screen_pos)
	if hit == Vector3.ZERO:
		return
	if _draw_pts.is_empty() or _draw_pts[_draw_pts.size() - 1].distance_to(hit) >= _draw_min_dist:
		_draw_pts.append(hit)
		_update_preview()


func _finish_draw() -> void:
	_drawing = false
	_hide_preview()
	if _draw_pts.size() < 3:
		_draw_pts = PackedVector3Array()
		return
	## Close if ends are near.
	var first: Vector3 = _draw_pts[0]
	var last: Vector3 = _draw_pts[_draw_pts.size() - 1]
	if first.distance_to(last) > _draw_min_dist * 2.0:
		_draw_pts.append(first)
	var shape: Node3D = LassoShapeScript.new()
	_shape_counter += 1
	shape.shape_name = "Blob %d" % _shape_counter
	shape.setup(_draw_pts, _surface_y(), brush_color)
	shape.material_kind = brush_material
	shape.z_order = brush_z_order
	shape.opacity = brush_color.a
	_world_root.add_child(shape)
	shapes.append(shape)
	_draw_pts = PackedVector3Array()
	select_shape(shape)
	shapes_changed.emit()
	if _ui:
		_ui.refresh_shape_list()
		_ui.refresh_selection()


func _cancel_draw() -> void:
	_drawing = false
	_draw_pts = PackedVector3Array()
	_hide_preview()


func _update_transform(screen_pos: Vector2) -> void:
	if selected == null or not is_instance_valid(selected):
		return
	match tool_mode:
		ToolMode.MOVE:
			var hit := _plane_from_screen(screen_pos)
			if hit == Vector3.ZERO:
				return
			var delta := hit - _grab_world
			selected.position = Vector3(
				_grab_pos.x + delta.x,
				selected.position.y,
				_grab_pos.z + delta.z
			)
		ToolMode.SCALE:
			var dx := screen_pos.x - _grab_mouse.x
			var mul := pow(1.01, dx * 0.35)
			selected.set_uniform_scale(_grab_scale * mul)
		ToolMode.ROTATE:
			var dx2 := screen_pos.x - _grab_mouse.x
			selected.set_yaw_degrees(_grab_yaw + dx2 * 0.45)
	if _ui:
		_ui.refresh_transform_fields()


func _pick_shape(world: Vector3, screen_pos: Vector2) -> Node3D:
	## Prefer top z_order hit under cursor.
	var best: Node3D = null
	var best_z := -999999
	for s in shapes:
		if s == null or not is_instance_valid(s):
			continue
		if world != Vector3.ZERO and s.contains_world_xz(world):
			if s.z_order >= best_z:
				best_z = s.z_order
				best = s
	if best != null:
		return best
	## Fallback: nearest by screen distance to centroid.
	var cam: Camera3D = _camera()
	if cam == null:
		return null
	var nearest: Node3D = null
	var nearest_d := 48.0
	for s2 in shapes:
		if s2 == null or not is_instance_valid(s2):
			continue
		var sp := cam.unproject_position(s2.global_position)
		var d := sp.distance_to(screen_pos)
		if d < nearest_d:
			nearest_d = d
			nearest = s2
	return nearest


func _plane_from_screen(screen_pos: Vector2) -> Vector3:
	if _game != null and _game.has_method("_grill_plane_from_screen"):
		return _game._grill_plane_from_screen(screen_pos)
	var cam := _camera()
	if cam == null:
		return Vector3.ZERO
	var from := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.001:
		return Vector3.ZERO
	var y := _surface_y()
	var t := (y - from.y) / dir.y
	if t <= 0.0:
		return Vector3.ZERO
	return from + dir * t


func _surface_y() -> float:
	## Slightly above grill steel so shapes don't z-fight.
	return 1.159


func _camera() -> Camera3D:
	if _game != null and _game.get("camera") != null:
		return _game.camera
	return null


func _ensure_preview() -> void:
	if _preview != null:
		return
	_preview = MeshInstance3D.new()
	_preview.name = "LassoPreview"
	_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_preview_mat = StandardMaterial3D.new()
	_preview_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_preview_mat.albedo_color = Color(1.0, 0.95, 0.4, 0.95)
	_preview_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_preview.material_override = _preview_mat
	_preview.visible = false
	if _world_root:
		_world_root.add_child(_preview)


func _update_preview() -> void:
	_ensure_preview()
	if _draw_pts.size() < 2:
		_preview.visible = false
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINE_STRIP)
	var y := _surface_y() + 0.002
	for p in _draw_pts:
		st.add_vertex(Vector3(p.x, y, p.z))
	_preview.mesh = st.commit()
	_preview.visible = true


func _hide_preview() -> void:
	if _preview:
		_preview.visible = false
		_preview.mesh = null
