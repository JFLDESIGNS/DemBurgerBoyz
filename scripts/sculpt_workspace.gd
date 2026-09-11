extends Control

signal closed

const SAVE_ROOT := "user://sculpted_items"
const MANIFEST_PATH := "user://sculpted_items/manifest.json"
const MAX_HISTORY := 32

var _vertices := PackedVector3Array()
var _normals := PackedVector3Array()
var _colors := PackedColorArray()
var _mask_weights := PackedFloat32Array()
var _indices := PackedInt32Array()
var _mesh_instance: MeshInstance3D
var _points_instance: MultiMeshInstance3D
var _brush_cursor: MeshInstance3D
var _reference_body: Node3D
var _reference_source: Node3D
var _key_light: DirectionalLight3D
var _environment: Environment
var _camera: Camera3D
var _viewport: SubViewport
var _view: SubViewportContainer
var _status: Label
var _tool_select: OptionButton
var _category_select: OptionButton
var _name_edit: LineEdit
var _library_select: OptionButton
var _color_button: ColorPickerButton
var _radius := 0.22
var _strength := 0.45
var _thickness := 0.12
var _subdivisions := 24
var _next_subdivisions := 24
var _symmetry := true
var _show_points := true
var _show_reference := true
var _move_reference := false
var _reference_scale := 1.0
var _reference_opacity := 0.35
var _key_energy := 1.25
var _ambient_energy := 0.75
var _light_yaw := -35.0
var _light_pitch := -37.0
var _base_kind := "sphere"
var _is_solid := false
var _primitive_count := 1
var _topology_dirty := true
var _orbit := Vector2(-0.30, 0.16)
var _distance := 3.0
var _target := Vector3.ZERO
var _sculpting := false
var _orbiting := false
var _panning := false
var _dragging_reference := false
var _active_vertex := -1
var _last_mouse := Vector2.ZERO
var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []
var _saved_items: Array[Dictionary] = []
var _material: StandardMaterial3D
var _neighbors: Array[PackedInt32Array] = []


func set_reference_source(source: Node3D) -> void:
	_reference_source = source
	if _viewport != null:
		_create_reference_body()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_interface()
	_load_manifest()
	_new_sphere()


func _build_interface() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("101521")
	add_child(backdrop)
	var columns := HBoxContainer.new()
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	columns.add_theme_constant_override("separation", 12)
	add_child(columns)
	var tools := _panel_column(columns, 286)
	_add_title(tools, "SCULPT MODE", 25, Color("ffc957"))
	_add_note(tools, "LMB sculpt  •  RMB orbit  •  MMB pan  •  Wheel zoom\nThe translucent character is a movable fitting reference.")
	var close_button := _add_button(tools, "← BACK TO CHARACTER", func() -> void: closed.emit())
	close_button.custom_minimum_size.y = 42
	_add_section(tools, "START MESH")
	var starts := HBoxContainer.new()
	tools.add_child(starts)
	_add_button(starts, "Sphere", _new_sphere)
	_add_button(starts, "Plane", _new_plane)
	var appends := HBoxContainer.new()
	tools.add_child(appends)
	_add_button(appends, "+ Sphere", _append_sphere)
	_add_button(appends, "+ Plane", _append_plane)
	var resolution := OptionButton.new()
	for label in ["16 × 16", "24 × 24", "32 × 32", "48 × 48", "64 × 64"]:
		resolution.add_item(label)
	resolution.select(1)
	resolution.item_selected.connect(func(index: int) -> void: _next_subdivisions = [16, 24, 32, 48, 64][index])
	tools.add_child(resolution)
	_add_section(tools, "SCULPT BRUSH")
	_tool_select = OptionButton.new()
	for label in ["Grab points", "Standard add", "Standard remove", "Smooth surface", "Crease", "Paint", "Mask paint", "Mask erase"]:
		_tool_select.add_item(label)
	tools.add_child(_tool_select)
	_add_slider(tools, "Brush radius", 0.02, 0.75, 0.01, _radius, func(v: float) -> void:
		_radius = v
		_update_brush_cursor_scale()
	)
	_add_slider(tools, "Strength", 0.02, 1.0, 0.01, _strength, func(v: float) -> void: _strength = v)
	_color_button = ColorPickerButton.new()
	_color_button.text = "Paint color"
	_color_button.color = Color("6e3f2f")
	_color_button.custom_minimum_size.y = 36
	tools.add_child(_color_button)
	var symmetry_toggle := CheckButton.new()
	symmetry_toggle.text = "X symmetry"
	symmetry_toggle.button_pressed = _symmetry
	symmetry_toggle.toggled.connect(func(on: bool) -> void: _symmetry = on)
	tools.add_child(symmetry_toggle)
	var points_toggle := CheckButton.new()
	points_toggle.text = "Show editable points"
	points_toggle.button_pressed = true
	points_toggle.toggled.connect(func(on: bool) -> void:
		_show_points = on
		if _points_instance != null: _points_instance.visible = on
	)
	tools.add_child(points_toggle)
	var mask_actions := HBoxContainer.new()
	tools.add_child(mask_actions)
	_add_button(mask_actions, "Clear mask", _clear_mask)
	_add_button(mask_actions, "Invert mask", _invert_mask)
	_add_section(tools, "REFERENCE BODY")
	var reference_toggle := CheckButton.new()
	reference_toggle.text = "Show character reference"
	reference_toggle.button_pressed = _show_reference
	reference_toggle.toggled.connect(func(on: bool) -> void:
		_show_reference = on
		if _reference_body != null: _reference_body.visible = on
	)
	tools.add_child(reference_toggle)
	var move_toggle := CheckButton.new()
	move_toggle.text = "Drag reference with LMB"
	move_toggle.button_pressed = _move_reference
	move_toggle.toggled.connect(func(on: bool) -> void:
		_move_reference = on
		_set_status("LMB now moves the reference body." if on else "LMB now sculpts the active object.")
	)
	tools.add_child(move_toggle)
	_add_slider(tools, "Reference X", -4.0, 4.0, 0.01, 0.0, func(v: float) -> void: _set_reference_axis(0, v))
	_add_slider(tools, "Reference Y", -5.0, 3.0, 0.01, -1.05, func(v: float) -> void: _set_reference_axis(1, v))
	_add_slider(tools, "Reference Z", -4.0, 4.0, 0.01, 0.0, func(v: float) -> void: _set_reference_axis(2, v))
	_add_slider(tools, "Reference scale", 0.35, 1.75, 0.01, _reference_scale, func(v: float) -> void:
		_reference_scale = v
		if _reference_body != null: _reference_body.scale = Vector3.ONE * v
	)
	_add_slider(tools, "Reference opacity", 0.05, 0.90, 0.01, _reference_opacity, func(v: float) -> void:
		_reference_opacity = v
		_apply_reference_ghost()
	)
	_add_section(tools, "PLANE THICKNESS")
	_add_slider(tools, "Thickness", 0.01, 0.50, 0.01, _thickness, func(v: float) -> void: _thickness = v)
	_add_button(tools, "Add sides + bottom", _solidify_plane)
	var history := HBoxContainer.new()
	tools.add_child(history)
	_add_button(history, "Undo", _undo_action)
	_add_button(history, "Redo", _redo_action)
	_status = Label.new()
	_status.text = "Ready"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color("aebbd0"))
	tools.add_child(_status)

	_view = SubViewportContainer.new()
	_view.stretch = true
	_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.custom_minimum_size = Vector2(500, 400)
	columns.add_child(_view)
	_view.gui_input.connect(_on_view_input)
	_build_3d_view()

	var library := _panel_column(columns, 270)
	_add_title(library, "SCULPTED ITEMS", 20, Color("ffc957"))
	_add_note(library, "Save editable, vertex-painted meshes into a category. Reload any item to keep sculpting it.")
	_add_section(library, "ITEM NAME")
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Example: Floppy sun hat"
	library.add_child(_name_edit)
	_category_select = OptionButton.new()
	for label in ["Hair", "Hat", "Jewelry", "Shoe"]:
		_category_select.add_item(label)
	library.add_child(_category_select)
	_add_button(library, "SAVE SCULPTED ITEM", _save_item)
	_add_section(library, "SAVED LIBRARY")
	_library_select = OptionButton.new()
	library.add_child(_library_select)
	_add_button(library, "Load selected for editing", _load_selected_item)
	_add_section(library, "SCULPT LIGHTING")
	_add_slider(library, "Key brightness", 0.0, 4.0, 0.05, _key_energy, func(v: float) -> void:
		_key_energy = v
		_apply_lighting()
	)
	_add_slider(library, "Ambient", 0.0, 2.0, 0.05, _ambient_energy, func(v: float) -> void:
		_ambient_energy = v
		_apply_lighting()
	)
	_add_slider(library, "Light yaw", -180.0, 180.0, 1.0, _light_yaw, func(v: float) -> void:
		_light_yaw = v
		_apply_lighting()
	)
	_add_slider(library, "Light pitch", -85.0, 20.0, 1.0, _light_pitch, func(v: float) -> void:
		_light_pitch = v
		_apply_lighting()
	)
	var help := Label.new()
	help.text = "Workflow\n\n1. Start or append primitives\n2. Fit them over the reference\n3. Add/remove, smooth, crease, mask, and paint\n4. Masked red areas resist sculpt brushes\n5. Add plane thickness when needed\n6. Name and save by item type"
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_color_override("font_color", Color("91a0b7"))
	library.add_child(help)


func _panel_column(host: HBoxContainer, width: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = width
	var style := StyleBoxFlat.new()
	style.bg_color = Color("181f2e")
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	host.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = width
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	scroll.add_child(column)
	return column


func _add_title(parent: Control, text: String, size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)


func _add_section(parent: Control, text: String) -> void:
	var line := HSeparator.new()
	parent.add_child(line)
	_add_title(parent, text, 15, Color("e7edf8"))


func _add_note(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color("95a3ba"))
	parent.add_child(label)


func _add_button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 34
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _add_slider(parent: Control, text: String, minimum: float, maximum: float, step: float, value: float, callback: Callable) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 105
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(callback)
	row.add_child(slider)
	parent.add_child(row)


func _build_3d_view() -> void:
	call_deferred("_create_viewport")


func _create_viewport() -> void:
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.transparent_bg = false
	_view.add_child(_viewport)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	_environment = env
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("252d3d")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b9c8e2")
	env.ambient_light_energy = 0.75
	environment.environment = env
	_viewport.add_child(environment)
	_key_light = DirectionalLight3D.new()
	_key_light.shadow_enabled = true
	_viewport.add_child(_key_light)
	_apply_lighting()
	_mesh_instance = MeshInstance3D.new()
	_viewport.add_child(_mesh_instance)
	_points_instance = MultiMeshInstance3D.new()
	_viewport.add_child(_points_instance)
	_brush_cursor = MeshInstance3D.new()
	var cursor_mesh := SphereMesh.new()
	cursor_mesh.radius = 1.0
	cursor_mesh.height = 2.0
	cursor_mesh.radial_segments = 20
	cursor_mesh.rings = 10
	var cursor_material := StandardMaterial3D.new()
	cursor_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cursor_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cursor_material.albedo_color = Color(0.18, 0.82, 1.0, 0.14)
	cursor_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	cursor_mesh.material = cursor_material
	_brush_cursor.mesh = cursor_mesh
	_brush_cursor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_brush_cursor.visible = false
	_viewport.add_child(_brush_cursor)
	_camera = Camera3D.new()
	_camera.fov = 38.0
	_camera.current = true
	_viewport.add_child(_camera)
	_create_reference_body()
	_apply_camera()
	_rebuild_mesh()
	_view.mouse_exited.connect(func() -> void:
		if _brush_cursor != null: _brush_cursor.visible = false
	)


func _create_reference_body() -> void:
	if _viewport == null:
		return
	if _reference_body != null:
		_reference_body.queue_free()
		_reference_body = null
	if is_instance_valid(_reference_source):
		_reference_body = _reference_source.duplicate() as Node3D
	else:
		var scene_path := "res://scenes/character_creator/modular_character_base.tscn"
		if not ResourceLoader.exists(scene_path):
			scene_path = "res://scenes/modular_character_base.tscn"
		if not ResourceLoader.exists(scene_path):
			_set_status("Character reference scene was not found.")
			return
		var packed := load(scene_path) as PackedScene
		if packed == null:
			return
		_reference_body = packed.instantiate() as Node3D
	_reference_body.name = "SculptReferenceBody"
	_reference_body.position = Vector3(0.0, -1.05, 0.0)
	_reference_body.scale = Vector3.ONE * _reference_scale
	_reference_body.visible = _show_reference
	_viewport.add_child(_reference_body)
	_reference_body.process_mode = Node.PROCESS_MODE_DISABLED
	_apply_reference_ghost.call_deferred()


func _apply_reference_ghost() -> void:
	if _reference_body == null:
		return
	for child in _reference_body.find_children("*", "GeometryInstance3D", true, false):
		var geometry := child as GeometryInstance3D
		if geometry != null:
			geometry.transparency = 1.0 - _reference_opacity
			geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _apply_lighting() -> void:
	if _key_light != null:
		_key_light.light_energy = _key_energy
		_key_light.rotation_degrees = Vector3(_light_pitch, _light_yaw, 0.0)
	if _environment != null:
		_environment.ambient_light_energy = _ambient_energy


func _set_reference_axis(axis: int, value: float) -> void:
	if _reference_body == null:
		return
	var next := _reference_body.position
	if axis == 0: next.x = value
	elif axis == 1: next.y = value
	else: next.z = value
	_reference_body.position = next


func _move_reference_by(delta: Vector2) -> void:
	if _reference_body == null:
		return
	_reference_body.position += _camera.global_transform.basis.x * delta.x * 0.0025 * _distance
	_reference_body.position += _camera.global_transform.basis.y * -delta.y * 0.0025 * _distance


func _new_sphere() -> void:
	_push_history("Before new sphere")
	_subdivisions = _next_subdivisions
	_base_kind = "sphere"
	_is_solid = false
	_primitive_count = 0
	_vertices.clear(); _indices.clear(); _colors.clear(); _mask_weights.clear()
	_append_sphere_data(Vector3.ZERO, 0.42)
	_primitive_count = 1
	_topology_dirty = true
	_rebuild_mesh()
	_set_status("Subdivided sphere: %d editable points." % _vertices.size())


func _append_sphere_data(center: Vector3, radius: float) -> void:
	var first_vertex := _vertices.size()
	var rings := maxi(8, int(_subdivisions * 0.65))
	for y in range(rings + 1):
		var v := float(y) / float(rings)
		var phi := v * PI
		for x in range(_subdivisions + 1):
			var u := float(x) / float(_subdivisions)
			var theta := u * TAU
			_vertices.append(center + Vector3(sin(phi) * sin(theta), cos(phi), sin(phi) * cos(theta)) * radius)
			_colors.append(Color("6e3f2f"))
			_mask_weights.append(0.0)
	for y in range(rings):
		for x in range(_subdivisions):
			var a := first_vertex + y * (_subdivisions + 1) + x
			var b := a + 1
			var c := a + (_subdivisions + 1)
			var d := c + 1
			_indices.append_array(PackedInt32Array([a, c, b, b, c, d]))


func _append_sphere() -> void:
	_push_history("Before adding sphere")
	_subdivisions = _next_subdivisions
	var offset := Vector3(0.34 * float((_primitive_count % 3) - 1), 0.24 * float(_primitive_count / 3), 0.0)
	_append_sphere_data(offset, 0.28)
	_primitive_count += 1
	_base_kind = "multi"
	_is_solid = false
	_topology_dirty = true
	_rebuild_mesh()
	_set_status("Added sphere primitive. %d primitives now save as one object." % _primitive_count)


func _new_plane() -> void:
	_push_history("Before new plane")
	_subdivisions = _next_subdivisions
	_base_kind = "plane"
	_is_solid = false
	_primitive_count = 0
	_vertices.clear(); _indices.clear(); _colors.clear(); _mask_weights.clear()
	_append_plane_data(Vector3.ZERO, 1.5)
	_primitive_count = 1
	_topology_dirty = true
	_rebuild_mesh()
	_set_status("Subdivided plane: sculpt the front, then add sides + bottom.")


func _append_plane_data(center: Vector3, size: float) -> void:
	var first_vertex := _vertices.size()
	for y in range(_subdivisions + 1):
		for x in range(_subdivisions + 1):
			var px := (float(x) / _subdivisions - 0.5) * size
			var py := (0.5 - float(y) / _subdivisions) * size
			_vertices.append(center + Vector3(px, py, 0.0))
			_colors.append(Color("6e3f2f"))
			_mask_weights.append(0.0)
	for y in range(_subdivisions):
		for x in range(_subdivisions):
			var a := first_vertex + y * (_subdivisions + 1) + x
			var b := a + 1
			var c := a + (_subdivisions + 1)
			var d := c + 1
			_indices.append_array(PackedInt32Array([a, c, b, b, c, d]))


func _append_plane() -> void:
	_push_history("Before adding plane")
	_subdivisions = _next_subdivisions
	var offset := Vector3(0.30 * float((_primitive_count % 3) - 1), 0.22 * float(_primitive_count / 3), 0.18)
	_append_plane_data(offset, 0.85)
	_primitive_count += 1
	_base_kind = "multi"
	_is_solid = false
	_topology_dirty = true
	_rebuild_mesh()
	_set_status("Added plane primitive. %d primitives now save as one object." % _primitive_count)


func _solidify_plane() -> void:
	if _base_kind != "plane" or _is_solid:
		_set_status("Thickness is available once on a fresh plane.")
		return
	_push_history("Before adding thickness")
	var top_count := _vertices.size()
	for i in range(top_count):
		_vertices.append(_vertices[i] - Vector3(0, 0, _thickness))
		_colors.append(_colors[i])
		_mask_weights.append(_mask_weights[i] if i < _mask_weights.size() else 0.0)
	var top_indices := _indices.duplicate()
	for tri in range(0, top_indices.size(), 3):
		_indices.append_array(PackedInt32Array([top_indices[tri + 2] + top_count, top_indices[tri + 1] + top_count, top_indices[tri] + top_count]))
	var boundary := PackedInt32Array()
	for x in range(_subdivisions + 1): boundary.append(x)
	for y in range(1, _subdivisions + 1): boundary.append(y * (_subdivisions + 1) + _subdivisions)
	for x in range(_subdivisions - 1, -1, -1): boundary.append(_subdivisions * (_subdivisions + 1) + x)
	for y in range(_subdivisions - 1, 0, -1): boundary.append(y * (_subdivisions + 1))
	for i in range(boundary.size()):
		var a := boundary[i]
		var b := boundary[(i + 1) % boundary.size()]
		_indices.append_array(PackedInt32Array([a, b, b + top_count, a, b + top_count, a + top_count]))
	_is_solid = true
	_topology_dirty = true
	_rebuild_mesh()
	_set_status("Plane solidified with sides and bottom. Every point remains sculptable.")


func _rebuild_mesh() -> void:
	if _mesh_instance == null:
		return
	_recalculate_normals()
	_ensure_mask_size()
	var display_colors := _colors.duplicate()
	for i in range(mini(display_colors.size(), _mask_weights.size())):
		if _mask_weights[i] > 0.001:
			display_colors[i] = display_colors[i].lerp(Color(0.92, 0.12, 0.32, 1.0), _mask_weights[i] * 0.78)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_COLOR] = display_colors
	arrays[Mesh.ARRAY_INDEX] = _indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.roughness = 0.82
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, _material)
	_mesh_instance.mesh = mesh
	if _topology_dirty:
		_build_neighbors()
		_topology_dirty = false
	_rebuild_points()


func _ensure_mask_size() -> void:
	var old_size := _mask_weights.size()
	_mask_weights.resize(_vertices.size())
	for i in range(old_size, _mask_weights.size()):
		_mask_weights[i] = 0.0


func _clear_mask() -> void:
	if _mask_weights.is_empty():
		return
	_push_history("Before clearing mask")
	_mask_weights.fill(0.0)
	_rebuild_mesh()
	_set_status("Sculpt mask cleared.")


func _invert_mask() -> void:
	_ensure_mask_size()
	_push_history("Before inverting mask")
	for i in range(_mask_weights.size()):
		_mask_weights[i] = 1.0 - _mask_weights[i]
	_rebuild_mesh()
	_set_status("Sculpt mask inverted. Red areas are protected.")


func _clean_mesh_for_save() -> ArrayMesh:
	_recalculate_normals()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_INDEX] = _indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _material)
	return mesh


func _build_neighbors() -> void:
	_neighbors.clear()
	_neighbors.resize(_vertices.size())
	var sets: Array[Dictionary] = []
	sets.resize(_vertices.size())
	for i in range(sets.size()): sets[i] = {}
	for i in range(0, _indices.size(), 3):
		var a := _indices[i]; var b := _indices[i + 1]; var c := _indices[i + 2]
		sets[a][b] = true; sets[a][c] = true
		sets[b][a] = true; sets[b][c] = true
		sets[c][a] = true; sets[c][b] = true
	for i in range(sets.size()):
		var packed := PackedInt32Array()
		for key in sets[i]: packed.append(int(key))
		_neighbors[i] = packed


func _recalculate_normals() -> void:
	_normals.resize(_vertices.size())
	_normals.fill(Vector3.ZERO)
	for i in range(0, _indices.size(), 3):
		var a := _indices[i]; var b := _indices[i + 1]; var c := _indices[i + 2]
		var normal := (_vertices[b] - _vertices[a]).cross(_vertices[c] - _vertices[a])
		_normals[a] += normal; _normals[b] += normal; _normals[c] += normal
	for i in range(_normals.size()):
		_normals[i] = _normals[i].normalized() if _normals[i].length_squared() > 0.000001 else Vector3.FORWARD


func _rebuild_points() -> void:
	if _points_instance == null:
		return
	if not _show_points:
		_points_instance.visible = false
		return
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.instance_count = _vertices.size()
	var dot := SphereMesh.new()
	dot.radius = 0.009
	dot.height = 0.018
	dot.radial_segments = 6
	dot.rings = 3
	var dot_material := StandardMaterial3D.new()
	dot_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dot_material.vertex_color_use_as_albedo = true
	dot.material = dot_material
	multi.mesh = dot
	for i in range(_vertices.size()):
		multi.set_instance_transform(i, Transform3D(Basis.IDENTITY, _vertices[i] + _normals[i] * 0.012))
		var point_color := Color("ffdb72") if i == _active_vertex else Color(0.42, 0.78, 1.0, 0.72)
		if i < _mask_weights.size() and _mask_weights[i] > 0.05:
			point_color = Color(1.0, 0.12, 0.30, 0.35 + _mask_weights[i] * 0.65)
		multi.set_instance_color(i, point_color)
	_points_instance.multimesh = multi
	_points_instance.visible = _show_points


func _update_brush_cursor(mouse := Vector2(-10000, -10000)) -> void:
	if _brush_cursor == null or _camera == null or _move_reference:
		if _brush_cursor != null: _brush_cursor.visible = false
		return
	var hovered := _pick_vertex(mouse)
	if hovered < 0:
		_brush_cursor.visible = false
		return
	_brush_cursor.position = _vertices[hovered]
	_update_brush_cursor_scale()
	_brush_cursor.visible = true


func _update_brush_cursor_scale() -> void:
	if _brush_cursor != null:
		_brush_cursor.scale = Vector3.ONE * _radius


func _on_view_input(event: InputEvent) -> void:
	if _camera == null:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_distance = maxf(1.1, _distance - 0.2); _apply_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_distance = minf(7.0, _distance + 0.2); _apply_camera()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_orbiting = event.pressed; _last_mouse = event.position
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed; _last_mouse = event.position
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if _move_reference:
				_dragging_reference = event.pressed
				_last_mouse = event.position
			else:
				if event.pressed: _begin_sculpt(event.position)
				else: _sculpting = false; _active_vertex = -1; _rebuild_points()
	elif event is InputEventMouseMotion:
		if _orbiting:
			_orbit.x -= event.relative.x * 0.008
			_orbit.y = clampf(_orbit.y - event.relative.y * 0.006, -1.35, 1.35)
			_apply_camera()
		elif _panning:
			_target += _camera.global_transform.basis.x * (-event.relative.x * 0.002 * _distance)
			_target += _camera.global_transform.basis.y * (event.relative.y * 0.002 * _distance)
			_apply_camera()
		elif _dragging_reference:
			_move_reference_by(event.relative)
		elif _sculpting:
			_apply_brush(event.position, event.relative)
		else:
			_update_brush_cursor(event.position)
	_view.accept_event()


func _begin_sculpt(mouse: Vector2) -> void:
	_active_vertex = _pick_vertex(mouse)
	if _active_vertex < 0:
		_set_status("No point under brush. Orbit or increase brush radius.")
		return
	_push_history("Sculpt stroke")
	_redo.clear()
	_sculpting = true
	_last_mouse = mouse
	_update_brush_cursor(mouse)
	_apply_brush(mouse, Vector2.ZERO)


func _pick_vertex(mouse: Vector2) -> int:
	var best := -1
	var best_distance := 42.0
	for i in range(_vertices.size()):
		var world := _mesh_instance.to_global(_vertices[i])
		if _camera.is_position_behind(world): continue
		var screen := _camera.unproject_position(world)
		var distance := screen.distance_to(mouse)
		if distance < best_distance:
			best_distance = distance
			best = i
	return best


func _apply_brush(_mouse: Vector2, delta: Vector2) -> void:
	if _active_vertex < 0:
		return
	_ensure_mask_size()
	var centers := [_vertices[_active_vertex]]
	if _symmetry:
		centers.append(Vector3(-centers[0].x, centers[0].y, centers[0].z))
	var affected := 0
	var original := _vertices.duplicate()
	for i in range(_vertices.size()):
		var falloff := 0.0
		var mirrored_grab := false
		for center_index in range(centers.size()):
			var center: Vector3 = centers[center_index]
			var d := original[i].distance_to(center)
			var candidate := pow(1.0 - d / _radius, 2.0) if d <= _radius else 0.0
			if candidate > falloff:
				falloff = candidate
				mirrored_grab = center_index == 1
		if falloff <= 0.0: continue
		affected += 1
		var tool := _tool_select.selected
		var sculpt_falloff := falloff
		if tool <= 5:
			sculpt_falloff *= 1.0 - _mask_weights[i]
		match tool:
			0:
				var move := _camera.global_transform.basis.x * delta.x * 0.0025 * _strength
				move += _camera.global_transform.basis.y * -delta.y * 0.0025 * _strength
				if mirrored_grab: move.x *= -1.0
				_vertices[i] += move * sculpt_falloff
			1:
				var add_force := maxf(delta.length() * 0.0012, 0.0035) * _strength
				_vertices[i] += _normals[i] * add_force * sculpt_falloff
			2:
				var remove_force := maxf(delta.length() * 0.0012, 0.0035) * _strength
				_vertices[i] -= _normals[i] * remove_force * sculpt_falloff
			3:
				if delta.length_squared() <= 0.0 or _neighbors[i].is_empty():
					continue
				var average := original[i]
				var count := 1
				var average_edge := 0.0
				for j in _neighbors[i]:
					average += original[j]
					average_edge += original[i].distance_to(original[j])
					count += 1
				average /= float(count)
				average_edge /= float(maxi(count - 1, 1))
				var laplacian := average - original[i]
				var inward := laplacian.dot(_normals[i])
				if inward < 0.0:
					laplacian -= _normals[i] * inward * 0.88
				var max_step := average_edge * 0.12 * _strength * sculpt_falloff
				_vertices[i] += laplacian.limit_length(max_step)
			4:
				var center: Vector3 = centers[1] if mirrored_grab else centers[0]
				var toward_center: Vector3 = center - original[i]
				var tangent: Vector3 = toward_center - _normals[i] * toward_center.dot(_normals[i])
				var crease_force := maxf(delta.length() * 0.0018, 0.003) * _strength * sculpt_falloff
				if tangent.length_squared() > 0.000001:
					_vertices[i] += tangent.normalized() * crease_force
				_vertices[i] -= _normals[i] * crease_force * 0.42
			5:
				_colors[i] = _colors[i].lerp(_color_button.color, _strength * sculpt_falloff)
			6:
				_mask_weights[i] = clampf(_mask_weights[i] + _strength * falloff * 0.18, 0.0, 1.0)
			7:
				_mask_weights[i] = clampf(_mask_weights[i] - _strength * falloff * 0.24, 0.0, 1.0)
	_rebuild_mesh()
	if _active_vertex >= 0:
		_brush_cursor.position = _vertices[_active_vertex]
		_update_brush_cursor_scale()
		_brush_cursor.visible = true
	_set_status("%s stroke • %d points affected" % [_tool_select.get_item_text(_tool_select.selected), affected])


func _apply_camera() -> void:
	if _camera == null: return
	var direction := Vector3(sin(_orbit.x) * cos(_orbit.y), sin(_orbit.y), cos(_orbit.x) * cos(_orbit.y))
	_camera.position = _target + direction * _distance
	_camera.look_at(_target, Vector3.UP)


func _push_history(label: String) -> void:
	if _vertices.is_empty(): return
	_undo.append({"label": label, "vertices": _vertices.duplicate(), "colors": _colors.duplicate(), "mask": _mask_weights.duplicate(), "indices": _indices.duplicate(), "kind": _base_kind, "solid": _is_solid, "subdivisions": _subdivisions, "primitive_count": _primitive_count})
	if _undo.size() > MAX_HISTORY: _undo.pop_front()


func _undo_action() -> void:
	if _undo.is_empty(): _set_status("Nothing to undo."); return
	_redo.append(_snapshot("Redo"))
	_restore_snapshot(_undo.pop_back())


func _redo_action() -> void:
	if _redo.is_empty(): _set_status("Nothing to redo."); return
	_undo.append(_snapshot("Undo"))
	_restore_snapshot(_redo.pop_back())


func _snapshot(label: String) -> Dictionary:
	return {"label": label, "vertices": _vertices.duplicate(), "colors": _colors.duplicate(), "mask": _mask_weights.duplicate(), "indices": _indices.duplicate(), "kind": _base_kind, "solid": _is_solid, "subdivisions": _subdivisions, "primitive_count": _primitive_count}


func _restore_snapshot(data: Dictionary) -> void:
	_vertices = data.vertices; _colors = data.colors; _indices = data.indices
	_mask_weights = data.get("mask", PackedFloat32Array())
	_base_kind = data.kind; _is_solid = data.solid; _subdivisions = data.subdivisions
	_primitive_count = int(data.get("primitive_count", 1))
	_topology_dirty = true
	_rebuild_mesh(); _set_status("History restored.")


func _save_item() -> void:
	var item_name := _name_edit.text.strip_edges()
	if item_name.is_empty(): _set_status("Give the sculpted item a name first."); return
	var category := _category_select.get_item_text(_category_select.selected).to_lower()
	var slug := item_name.to_lower().replace(" ", "_").validate_filename()
	var folder := SAVE_ROOT.path_join(category)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var resource_path := folder.path_join(slug + ".res")
	var result := ResourceSaver.save(_clean_mesh_for_save(), resource_path)
	if result != OK: _set_status("Could not save mesh (%s)." % error_string(result)); return
	var record := {"name": item_name, "category": category, "path": resource_path, "kind": _base_kind, "solid": _is_solid, "subdivisions": _subdivisions, "primitive_count": _primitive_count, "saved_at": Time.get_datetime_string_from_system()}
	var replaced := false
	for i in range(_saved_items.size()):
		if _saved_items[i].path == resource_path: _saved_items[i] = record; replaced = true; break
	if not replaced: _saved_items.append(record)
	_write_manifest(); _refresh_library(); _set_status("Saved %s as %s." % [item_name, category.capitalize()])


func _load_manifest() -> void:
	_saved_items.clear()
	if FileAccess.file_exists(MANIFEST_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
		if parsed is Array:
			for item in parsed:
				if item is Dictionary: _saved_items.append(item)
	_refresh_library()


func _write_manifest() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_ROOT))
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(_saved_items, "  "))


func _refresh_library() -> void:
	if _library_select == null: return
	_library_select.clear()
	for item in _saved_items:
		_library_select.add_item("%s • %s" % [str(item.category).capitalize(), item.name])
	if _saved_items.is_empty(): _library_select.add_item("No saved sculpted items")


func _load_selected_item() -> void:
	if _saved_items.is_empty() or _library_select.selected < 0: return
	var record := _saved_items[_library_select.selected]
	var mesh := load(str(record.path)) as ArrayMesh
	if mesh == null or mesh.get_surface_count() == 0: _set_status("Saved mesh could not be loaded."); return
	_push_history("Before loading item")
	var arrays := mesh.surface_get_arrays(0)
	_vertices = arrays[Mesh.ARRAY_VERTEX]
	_normals = arrays[Mesh.ARRAY_NORMAL]
	_colors = arrays[Mesh.ARRAY_COLOR]
	_indices = arrays[Mesh.ARRAY_INDEX]
	_mask_weights = PackedFloat32Array()
	_mask_weights.resize(_vertices.size())
	_mask_weights.fill(0.0)
	if _colors.size() != _vertices.size():
		_colors.resize(_vertices.size()); _colors.fill(Color("6e3f2f"))
	_base_kind = str(record.get("kind", "sphere")); _is_solid = bool(record.get("solid", false)); _subdivisions = int(record.get("subdivisions", 24))
	_primitive_count = int(record.get("primitive_count", 1))
	_next_subdivisions = _subdivisions
	_name_edit.text = str(record.name)
	_topology_dirty = true
	_rebuild_mesh(); _set_status("Loaded %s for continued sculpting." % record.name)


func _set_status(text: String) -> void:
	if _status != null: _status.text = text


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if _name_edit != null and _name_edit.has_focus():
		return
	if event.ctrl_pressed and event.keycode == KEY_Z:
		if event.shift_pressed: _redo_action()
		else: _undo_action()
		get_viewport().set_input_as_handled()
	elif event.ctrl_pressed and event.keycode == KEY_Y:
		_redo_action(); get_viewport().set_input_as_handled()
	elif event.keycode == KEY_BRACKETLEFT:
		_radius = maxf(0.02, _radius - 0.02); _update_brush_cursor_scale(); _set_status("Brush radius %.2f" % _radius); get_viewport().set_input_as_handled()
	elif event.keycode == KEY_BRACKETRIGHT:
		_radius = minf(0.75, _radius + 0.02); _update_brush_cursor_scale(); _set_status("Brush radius %.2f" % _radius); get_viewport().set_input_as_handled()
	elif event.keycode >= KEY_1 and event.keycode <= KEY_8:
		_tool_select.select(int(event.keycode - KEY_1)); _set_status(_tool_select.get_item_text(_tool_select.selected)); get_viewport().set_input_as_handled()
