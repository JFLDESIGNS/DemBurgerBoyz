## Shape manager + tool chrome for the lasso system.
extends PanelContainer

const UiFontsScript := preload("res://scripts/ui_fonts.gd")
const HsbColorPickerScript := preload("res://scripts/hsb_color_picker.gd")
const LassoShapeScript := preload("res://scripts/lasso_shape.gd")

var _ctrl = null
var _tool_btns: Array[Button] = []
var _shape_list: VBoxContainer
var _picker
var _mat_option: OptionButton
var _z_spin: SpinBox
var _pos_x: SpinBox
var _pos_z: SpinBox
var _scale_spin: SpinBox
var _yaw_spin: SpinBox
var _name_label: Label
var _suppress: bool = false


func bind(controller) -> void:
	_ctrl = controller
	_build()
	controller.selection_changed.connect(refresh_selection)
	controller.shapes_changed.connect(refresh_shape_list)
	controller.tool_changed.connect(func(_m): refresh_tool_buttons())
	refresh_all()


func refresh_all() -> void:
	refresh_tool_buttons()
	refresh_shape_list()
	refresh_selection()


func _build() -> void:
	z_index = 120
	custom_minimum_size = Vector2(300, 520)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	offset_left = 12
	offset_top = 72
	offset_right = 312
	offset_bottom = 600

	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.07, 0.09, 0.11, 0.96)
	psb.border_color = Color(0.5, 0.62, 0.72, 0.95)
	psb.set_border_width_all(2)
	psb.set_corner_radius_all(10)
	psb.content_margin_left = 10
	psb.content_margin_right = 10
	psb.content_margin_top = 8
	psb.content_margin_bottom = 8
	add_theme_stylebox_override("panel", psb)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var title := Label.new()
	title.text = "SHAPE MANAGER"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiFontsScript.apply_label(title, true, 14)
	title.add_theme_color_override("font_color", Color(0.9, 0.96, 1.0))
	header.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(28, 24)
	UiFontsScript.apply_button(close_btn, true, 11)
	close_btn.pressed.connect(func():
		if _ctrl:
			_ctrl.set_active(false)
	)
	header.add_child(close_btn)

	var hint := Label.new()
	hint.text = "= toggles · 1 Lasso  2 Move  3 Scale  4 Rotate"
	UiFontsScript.apply_label(hint, false, 9)
	hint.add_theme_color_override("font_color", Color(0.65, 0.72, 0.78))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(hint)

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 4)
	root.add_child(tools)
	_tool_btns.clear()
	var tool_group := ButtonGroup.new()
	for item in [["Lasso", 0], ["Move", 1], ["Scale", 2], ["Rotate", 3]]:
		var b := Button.new()
		b.text = str(item[0])
		b.toggle_mode = true
		b.button_group = tool_group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 26)
		UiFontsScript.apply_button(b, true, 10)
		var mode: int = int(item[1])
		b.pressed.connect(func():
			if _ctrl:
				_ctrl.set_tool_mode(mode)
		)
		tools.add_child(b)
		_tool_btns.append(b)

	_section(root, "COLOR / OPACITY")
	_picker = HsbColorPickerScript.new()
	root.add_child(_picker)
	_picker.color_changed.connect(_on_picker_color)

	_section(root, "MATERIAL / Z-ORDER")
	var mat_row := HBoxContainer.new()
	mat_row.add_theme_constant_override("separation", 6)
	root.add_child(mat_row)
	var mat_lab := Label.new()
	mat_lab.text = "Mat"
	UiFontsScript.apply_label(mat_lab, false, 10)
	mat_lab.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	mat_row.add_child(mat_lab)
	_mat_option = OptionButton.new()
	_mat_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for lab in LassoShapeScript.MATERIAL_LABELS:
		_mat_option.add_item(lab)
	_mat_option.item_selected.connect(_on_mat_selected)
	mat_row.add_child(_mat_option)

	var z_row := HBoxContainer.new()
	z_row.add_theme_constant_override("separation", 6)
	root.add_child(z_row)
	var z_lab := Label.new()
	z_lab.text = "Z"
	UiFontsScript.apply_label(z_lab, false, 10)
	z_lab.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	z_row.add_child(z_lab)
	_z_spin = _make_spin(-64, 64, 1, 0)
	_z_spin.value_changed.connect(_on_z_changed)
	z_row.add_child(_z_spin)
	var fwd := Button.new()
	fwd.text = "Front"
	UiFontsScript.apply_button(fwd, true, 9)
	fwd.pressed.connect(func():
		if _ctrl:
			_ctrl.bring_selected_forward()
			refresh_selection()
	)
	z_row.add_child(fwd)
	var back := Button.new()
	back.text = "Back"
	UiFontsScript.apply_button(back, true, 9)
	back.pressed.connect(func():
		if _ctrl:
			_ctrl.send_selected_backward()
			refresh_selection()
	)
	z_row.add_child(back)

	_section(root, "TRANSFORM")
	_name_label = Label.new()
	_name_label.text = "No selection"
	UiFontsScript.apply_label(_name_label, false, 11)
	_name_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	root.add_child(_name_label)

	var xz := HBoxContainer.new()
	xz.add_theme_constant_override("separation", 4)
	root.add_child(xz)
	xz.add_child(_tiny("X"))
	_pos_x = _make_spin(-8.0, 8.0, 0.01, 0.0)
	_pos_x.value_changed.connect(_on_pos_changed)
	xz.add_child(_pos_x)
	xz.add_child(_tiny("Z"))
	_pos_z = _make_spin(-8.0, 8.0, 0.01, 0.0)
	_pos_z.value_changed.connect(_on_pos_changed)
	xz.add_child(_pos_z)

	var sr := HBoxContainer.new()
	sr.add_theme_constant_override("separation", 4)
	root.add_child(sr)
	sr.add_child(_tiny("S"))
	_scale_spin = _make_spin(0.05, 12.0, 0.01, 1.0)
	_scale_spin.value_changed.connect(_on_scale_changed)
	sr.add_child(_scale_spin)
	sr.add_child(_tiny("Y°"))
	_yaw_spin = _make_spin(-180.0, 180.0, 1.0, 0.0)
	_yaw_spin.value_changed.connect(_on_yaw_changed)
	sr.add_child(_yaw_spin)

	var del_row := HBoxContainer.new()
	del_row.add_theme_constant_override("separation", 6)
	root.add_child(del_row)
	var del_btn := Button.new()
	del_btn.text = "Delete Selected"
	del_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiFontsScript.apply_button(del_btn, true, 11)
	del_btn.pressed.connect(func():
		if _ctrl:
			_ctrl.delete_selected()
	)
	del_row.add_child(del_btn)

	_section(root, "SHAPES")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 110)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_shape_list = VBoxContainer.new()
	_shape_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shape_list.add_theme_constant_override("separation", 3)
	scroll.add_child(_shape_list)


func _section(parent: Control, text: String) -> void:
	var lab := Label.new()
	lab.text = text
	UiFontsScript.apply_label(lab, true, 10)
	lab.add_theme_color_override("font_color", Color(0.55, 0.75, 0.95))
	parent.add_child(lab)


func _tiny(t: String) -> Label:
	var lab := Label.new()
	lab.text = t
	UiFontsScript.apply_label(lab, true, 10)
	lab.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85))
	lab.custom_minimum_size = Vector2(18, 0)
	return lab


func _make_spin(mn: float, mx: float, step: float, val: float) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.value = val
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(70, 0)
	return s


func refresh_tool_buttons() -> void:
	if _ctrl == null:
		return
	for i in _tool_btns.size():
		_tool_btns[i].set_pressed_no_signal(i == _ctrl.tool_mode)


func refresh_shape_list() -> void:
	if _shape_list == null or _ctrl == null:
		return
	for c in _shape_list.get_children():
		c.queue_free()
	for s in _ctrl.shapes:
		if s == null or not is_instance_valid(s):
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(14, 14)
		swatch.color = s.get_display_color()
		row.add_child(swatch)
		var btn := Button.new()
		btn.text = s.shape_name
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.toggle_mode = true
		btn.button_pressed = (_ctrl.selected == s)
		UiFontsScript.apply_button(btn, false, 10)
		var shape_ref = s
		btn.pressed.connect(func():
			if _ctrl:
				_ctrl.select_shape(shape_ref)
				_ctrl.set_tool_mode(1) ## Move after pick from list
		)
		row.add_child(btn)
		var xbtn := Button.new()
		xbtn.text = "×"
		xbtn.custom_minimum_size = Vector2(24, 22)
		UiFontsScript.apply_button(xbtn, true, 12)
		xbtn.pressed.connect(func():
			if _ctrl:
				_ctrl.delete_shape(shape_ref)
		)
		row.add_child(xbtn)
		_shape_list.add_child(row)


func refresh_selection() -> void:
	if _ctrl == null:
		return
	_suppress = true
	var s = _ctrl.selected
	if s == null or not is_instance_valid(s):
		_name_label.text = "No selection — drawing uses brush color"
		if _picker:
			_picker.set_color(_ctrl.brush_color)
		_mat_option.select(_ctrl.brush_material)
		_z_spin.value = _ctrl.brush_z_order
		_suppress = false
		refresh_transform_fields()
		refresh_shape_list()
		return
	_name_label.text = s.shape_name
	if _picker:
		_picker.set_color(s.get_display_color())
	_mat_option.select(s.material_kind)
	_z_spin.value = s.z_order
	_suppress = false
	refresh_transform_fields()
	refresh_shape_list()


func refresh_transform_fields() -> void:
	if _ctrl == null:
		return
	_suppress = true
	var s = _ctrl.selected
	if s == null or not is_instance_valid(s):
		_pos_x.value = 0.0
		_pos_z.value = 0.0
		_scale_spin.value = 1.0
		_yaw_spin.value = 0.0
		_suppress = false
		return
	_pos_x.value = s.position.x
	_pos_z.value = s.position.z
	_scale_spin.value = s.get_uniform_scale()
	_yaw_spin.value = s.get_yaw_degrees()
	_suppress = false


func _on_picker_color(c: Color) -> void:
	if _suppress or _ctrl == null:
		return
	_ctrl.apply_brush_color(c)


func _on_mat_selected(idx: int) -> void:
	if _suppress or _ctrl == null:
		return
	_ctrl.apply_brush_material(idx)


func _on_z_changed(v: float) -> void:
	if _suppress or _ctrl == null:
		return
	_ctrl.apply_brush_z(int(v))


func _on_pos_changed(_v: float) -> void:
	if _suppress or _ctrl == null:
		return
	var s = _ctrl.selected
	if s == null or not is_instance_valid(s):
		return
	s.position.x = _pos_x.value
	s.position.z = _pos_z.value


func _on_scale_changed(v: float) -> void:
	if _suppress or _ctrl == null:
		return
	var s = _ctrl.selected
	if s == null or not is_instance_valid(s):
		return
	s.set_uniform_scale(v)


func _on_yaw_changed(v: float) -> void:
	if _suppress or _ctrl == null:
		return
	var s = _ctrl.selected
	if s == null or not is_instance_valid(s):
		return
	s.set_yaw_degrees(v)
