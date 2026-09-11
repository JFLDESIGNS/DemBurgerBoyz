extends Node

const SKIN_TONES: Array[Color] = [
	Color("f2c6a0"),
	Color("e6aa7a"),
	Color("cf895f"),
	Color("b86e47"),
	Color("925035"),
	Color("6d3828"),
	Color("45251e"),
	Color("d99a83"),
]
const LAST_PRESET_PATH := "user://last_character.json"
const ACCESSORY_FITS_PATH := "user://accessory_fits.json"
const LEGACY_CREATOR_FOLDER := "Burger Character Creator"
const SCULPT_WORKSPACE_SCRIPT := preload("res://scripts/sculpt_workspace.gd")

@onready var character: ModularCharacterBase = $World/Character
@onready var camera_rig: Node3D = $World/CameraRig
@onready var camera: Camera3D = $World/CameraRig/Camera3D
@onready var body_select: OptionButton = $UI/Sidebar/Margin/Controls/BodySelect
@onready var swatches: GridContainer = $UI/Sidebar/Margin/Controls/SkinSwatches
@onready var custom_color: ColorPickerButton = $UI/Sidebar/Margin/Controls/CustomColor
@onready var character_name: LineEdit = $UI/Sidebar/Margin/Controls/CharacterName
@onready var randomize_button: Button = $UI/Sidebar/Margin/Controls/RandomizeButton
@onready var modules_randomize_button: Button = $UI/ModulesPanel/Margin/Controls/ModulesRandomizeButton
@onready var save_button: Button = $UI/Sidebar/Margin/Controls/SaveButton
@onready var load_button: Button = $UI/Sidebar/Margin/Controls/LoadButton
@onready var reset_view_button: Button = $UI/Sidebar/Margin/Controls/ResetViewButton
@onready var animation_select: OptionButton = $UI/Sidebar/Margin/Controls/AnimationSelect
@onready var animation_button: Button = $UI/Sidebar/Margin/Controls/AnimationButton
@onready var pose_adjustments: VBoxContainer = $UI/Sidebar/Margin/Controls/PoseAdjustments
@onready var control_rig_toggle: CheckButton = $UI/Sidebar/Margin/Controls/ControlRigToggle
@onready var reset_pose_button: Button = $UI/Sidebar/Margin/Controls/ResetPoseButton
@onready var status_label: Label = $UI/Sidebar/Margin/Controls/Status
@onready var sidebar_margin: MarginContainer = $UI/Sidebar/Margin
@onready var sidebar_controls: VBoxContainer = $UI/Sidebar/Margin/Controls
@onready var saved_customers: VBoxContainer = $UI/Sidebar/Margin/Controls/SavedCustomers
@onready var module_margin: MarginContainer = $UI/ModulesPanel/Margin
@onready var module_controls: VBoxContainer = $UI/ModulesPanel/Margin/Controls
@onready var eyes_select: OptionButton = $UI/ModulesPanel/Margin/Controls/EyesSelect
@onready var eye_adjustments: VBoxContainer = $UI/ModulesPanel/Margin/Controls/EyeAdjustments
@onready var eye_specular_adjustments: VBoxContainer = $UI/ModulesPanel/Margin/Controls/EyeSpecularAdjustments
@onready var eye_rotation_adjustments: VBoxContainer = $UI/ModulesPanel/Margin/Controls/EyeRotationAdjustments
@onready var lash_select: OptionButton = $UI/ModulesPanel/Margin/Controls/LashSelect
@onready var lash_color: ColorPickerButton = $UI/ModulesPanel/Margin/Controls/LashColor
@onready var lash_adjustments: VBoxContainer = $UI/ModulesPanel/Margin/Controls/LashAdjustments
@onready var eyebrow_select: OptionButton = $UI/ModulesPanel/Margin/Controls/EyebrowSelect
@onready var eyebrow_color: ColorPickerButton = $UI/ModulesPanel/Margin/Controls/EyebrowColor
@onready var eyebrow_adjustments: VBoxContainer = $UI/ModulesPanel/Margin/Controls/EyebrowAdjustments
@onready var nose_select: OptionButton = $UI/ModulesPanel/Margin/Controls/NoseSelect
@onready var nose_color: ColorPickerButton = $UI/ModulesPanel/Margin/Controls/NoseColor
@onready var nose_adjustments: VBoxContainer = $UI/ModulesPanel/Margin/Controls/NoseAdjustments
@onready var mouth_select: OptionButton = $UI/ModulesPanel/Margin/Controls/MouthSelect
@onready var mouth_color: ColorPickerButton = $UI/ModulesPanel/Margin/Controls/MouthColor
@onready var mouth_adjustments: VBoxContainer = $UI/ModulesPanel/Margin/Controls/MouthAdjustments
@onready var cheek_select: OptionButton = $UI/ModulesPanel/Margin/Controls/CheekSelect
@onready var cheek_color: ColorPickerButton = $UI/ModulesPanel/Margin/Controls/CheekColor
@onready var cheek_adjustments: VBoxContainer = $UI/ModulesPanel/Margin/Controls/CheekAdjustments
@onready var ear_color: ColorPickerButton = $UI/ModulesPanel/Margin/Controls/EarColor
@onready var ear_adjustments: VBoxContainer = $UI/ModulesPanel/Margin/Controls/EarAdjustments
@onready var hair_select: OptionButton = $UI/ModulesPanel/Margin/Controls/HairSelect
@onready var hair_color: ColorPickerButton = $UI/ModulesPanel/Margin/Controls/HairColor
@onready var hair_adjustments: VBoxContainer = $UI/ModulesPanel/Margin/Controls/HairAdjustments
@onready var facial_hair_select: OptionButton = $UI/ModulesPanel/Margin/Controls/FacialHairSelect
@onready var facial_hair_color: ColorPickerButton = $UI/ModulesPanel/Margin/Controls/FacialHairColor
@onready var facial_hair_adjustments: VBoxContainer = $UI/ModulesPanel/Margin/Controls/FacialHairAdjustments
@onready var hat_select: OptionButton = $UI/ModulesPanel/Margin/Controls/HatSelect
@onready var hat_color: ColorPickerButton = $UI/ModulesPanel/Margin/Controls/HatColor
@onready var hat_adjustments: VBoxContainer = $UI/ModulesPanel/Margin/Controls/HatAdjustments
@onready var glasses_select: OptionButton = $UI/ModulesPanel/Margin/Controls/GlassesSelect
@onready var glasses_color: ColorPickerButton = $UI/ModulesPanel/Margin/Controls/GlassesColor
@onready var glasses_adjustments: VBoxContainer = $UI/ModulesPanel/Margin/Controls/GlassesAdjustments
@onready var makeup_select: OptionButton = $UI/ModulesPanel/Margin/Controls/MakeupSelect
@onready var makeup_color: ColorPickerButton = $UI/ModulesPanel/Margin/Controls/MakeupColor
@onready var makeup_adjustments: VBoxContainer = $UI/ModulesPanel/Margin/Controls/MakeupAdjustments
@onready var jewelry_select: OptionButton = $UI/ModulesPanel/Margin/Controls/JewelrySelect
@onready var jewelry_color: ColorPickerButton = $UI/ModulesPanel/Margin/Controls/JewelryColor
@onready var jewelry_adjustments: VBoxContainer = $UI/ModulesPanel/Margin/Controls/JewelryAdjustments
@onready var top_select: OptionButton = $UI/ModulesPanel/Margin/Controls/TopSelect
@onready var top_color: ColorPickerButton = $UI/ModulesPanel/Margin/Controls/TopColor
@onready var top_adjustments: VBoxContainer = $UI/ModulesPanel/Margin/Controls/TopAdjustments
@onready var graphic_select: OptionButton = $UI/ModulesPanel/Margin/Controls/GraphicSelect
@onready var graphic_color: ColorPickerButton = $UI/ModulesPanel/Margin/Controls/GraphicColor
@onready var graphic_adjustments: VBoxContainer = $UI/ModulesPanel/Margin/Controls/GraphicAdjustments
@onready var bottom_select: OptionButton = $UI/ModulesPanel/Margin/Controls/BottomSelect
@onready var bottom_color: ColorPickerButton = $UI/ModulesPanel/Margin/Controls/BottomColor
@onready var bottom_adjustments: VBoxContainer = $UI/ModulesPanel/Margin/Controls/BottomAdjustments
@onready var shoe_select: OptionButton = $UI/ModulesPanel/Margin/Controls/ShoeSelect
@onready var shoe_color: ColorPickerButton = $UI/ModulesPanel/Margin/Controls/ShoeColor
@onready var shoe_adjustments: VBoxContainer = $UI/ModulesPanel/Margin/Controls/ShoeAdjustments

var _orbit_y := 0.0
var _orbit_x := -0.08
var _camera_distance := 3.35
var _camera_pan := Vector3.ZERO
var _adjustment_sliders: Dictionary[String, HSlider] = {}
var _adjustment_colors: Dictionary[String, ColorPickerButton] = {}
var _adjustment_toggles: Dictionary[String, CheckBox] = {}
var _host_game: Node = null
var _module_scroll: ScrollContainer
var _feature_hotspots: Dictionary = {}
var _feature_pulse := 0.0
var _pointer_press_pos := Vector2.ZERO
var _pointer_dragged := false
var _feature_click_pending := false
var _fit_room_open := false
var _fit_room_panel: PanelContainer = null
var _fit_room_status: Label = null
var _fit_hair_status: Label = null
var _fit_hat_status: Label = null
var _fit_hair_select: OptionButton = null
var _fit_hat_select: OptionButton = null
var _fit_hair_block: CheckBox = null
var _fit_hat_block: CheckBox = null
var _fit_snapshot: Dictionary = {}
var _accessory_fits: Dictionary = {}
var _paint_mode := false
var _paint_tool := "soft"
var _paint_brush_size := 18.0
var _paint_opacity := 1.0
var _paint_color := Color(0.55, 0.18, 0.22, 1.0)
var _paint_panel: PanelContainer = null
var _paint_hud: Control = null
var _paint_status: Label = null
var _paint_tool_buttons: Dictionary = {}
var _paint_lasso: PackedVector2Array = PackedVector2Array()
var _paint_dragging := false
var _paint_last_uv := Vector2(-1.0, -1.0)
var _paint_size_slider: HSlider = null
var _paint_opacity_slider: HSlider = null
var _paint_color_button: ColorPickerButton = null
var _paint_history_select: OptionButton = null
var _paint_history: Array[Dictionary] = []
var _paint_stroke_snapshot: Dictionary = {}
var _paint_stroke_changed := false
var _flat_paint_panel: PanelContainer = null
var _flat_paint_canvas: Control = null
var _flat_paint_mode := false
var _paint_unlit_preview := false
var _paint_unlit_toggle: CheckButton = null
var _paint_saved_ambient_energy := 0.72
var _sculpt_layer: CanvasLayer = null
var _sculpt_workspace: Control = null


func configure_as_game_overlay(host: Node) -> void:
	_host_game = host


func _ready() -> void:
	if _host_game != null:
		var creator_ui := $UI as CanvasLayer
		if creator_ui != null:
			creator_ui.layer = 128
	_migrate_standalone_creator_presets()
	_setup_return_to_game_button()
	body_select.add_item("Classic chunky toon")
	body_select.disabled = true
	_make_module_panel_scrollable()
	_make_sidebar_scrollable()
	_style_randomize_button(randomize_button)
	_style_randomize_button(modules_randomize_button)
	_setup_feature_hotspots()
	_setup_module_controls()
	_setup_pose_rig_controls()
	_load_accessory_fits()
	_setup_fit_room()
	_setup_paint_mode()
	_setup_sculpt_mode()
	custom_color.color = character.skin_color
	custom_color.color_changed.connect(_on_skin_color_changed)
	randomize_button.pressed.connect(_randomize_character)
	modules_randomize_button.pressed.connect(_randomize_character)
	save_button.pressed.connect(_save_character)
	load_button.pressed.connect(_load_last_character)
	reset_view_button.pressed.connect(_reset_view)
	animation_button.pressed.connect(_toggle_animation_preview)
	animation_select.item_selected.connect(_on_preview_animation_selected)
	reset_pose_button.pressed.connect(_reset_character_pose)
	control_rig_toggle.toggled.connect(_on_control_rig_toggled)
	_build_skin_swatches()
	for label in ["Wave", "Walk in place", "Celebrate"]:
		animation_select.add_item(label)
	_refresh_saved_customers()
	_apply_camera()
	if FileAccess.file_exists(LAST_PRESET_PATH):
		_load_last_character()
	else:
		character.rebuild_appearance()
		_set_status("Build a modular toon with face, hair, clothes, and shoes. Click the markers on the character to jump to those sliders.")


func _setup_sculpt_mode() -> void:
	var button := Button.new()
	button.name = "SculptModeButton"
	button.text = "✦ OPEN SCULPT MODE"
	button.custom_minimum_size = Vector2(0, 44)
	button.tooltip_text = "Create and vertex-paint custom hair, hats, jewelry, and shoes"
	button.pressed.connect(_open_sculpt_mode)
	sidebar_controls.add_child(button)
	sidebar_controls.move_child(button, mini(4, sidebar_controls.get_child_count() - 1))


func _open_sculpt_mode() -> void:
	if _sculpt_layer != null:
		return
	_sculpt_layer = CanvasLayer.new()
	_sculpt_layer.layer = 300
	add_child(_sculpt_layer)
	_sculpt_workspace = SCULPT_WORKSPACE_SCRIPT.new() as Control
	_sculpt_workspace.call("set_reference_source", character)
	_sculpt_layer.add_child(_sculpt_workspace)
	_sculpt_workspace.connect("closed", _close_sculpt_mode)
	_set_status("Sculpt Mode opened.")


func _close_sculpt_mode() -> void:
	if _sculpt_layer != null:
		_sculpt_layer.queue_free()
	_sculpt_layer = null
	_sculpt_workspace = null
	_set_status("Sculpt saved items remain available in the Sculpt Mode library.")


func _migrate_standalone_creator_presets() -> void:
	var current_data_dir := OS.get_user_data_dir()
	var legacy_data_dir := current_data_dir.get_base_dir().path_join(LEGACY_CREATOR_FOLDER)
	if not DirAccess.dir_exists_absolute(legacy_data_dir):
		return
	var current_characters := current_data_dir.path_join("characters")
	var legacy_characters := legacy_data_dir.path_join("characters")
	if DirAccess.dir_exists_absolute(legacy_characters):
		DirAccess.make_dir_recursive_absolute(current_characters)
		var legacy_dir := DirAccess.open(legacy_characters)
		if legacy_dir != null:
			for file_name in legacy_dir.get_files():
				if file_name.get_extension().to_lower() not in ["json", "png"]:
					continue
				var destination := current_characters.path_join(file_name)
				if not FileAccess.file_exists(destination):
					DirAccess.copy_absolute(legacy_characters.path_join(file_name), destination)
	var legacy_last := legacy_data_dir.path_join("last_character.json")
	var current_last := current_data_dir.path_join("last_character.json")
	if FileAccess.file_exists(legacy_last) and not FileAccess.file_exists(current_last):
		DirAccess.copy_absolute(legacy_last, current_last)
	var legacy_fits := legacy_data_dir.path_join("accessory_fits.json")
	var current_fits := current_data_dir.path_join("accessory_fits.json")
	if FileAccess.file_exists(legacy_fits) and not FileAccess.file_exists(current_fits):
		DirAccess.copy_absolute(legacy_fits, current_fits)


func _setup_return_to_game_button() -> void:
	var back_button := Button.new()
	back_button.name = "ExitCreatorButton"
	back_button.text = "EXIT CHARACTER CREATOR"
	back_button.custom_minimum_size = Vector2(0.0, 44.0)
	back_button.tooltip_text = "Close the standalone character creator"
	back_button.pressed.connect(_return_to_game)
	sidebar_controls.add_child(back_button)
	sidebar_controls.move_child(back_button, 0)


func _return_to_game() -> void:
	if _host_game != null and is_instance_valid(_host_game) and _host_game.has_method("close_character_creator_overlay"):
		_host_game.close_character_creator_overlay(self)
		return
	get_tree().quit()


func _input(event: InputEvent) -> void:
	if not _paint_mode:
		return
	if event is InputEventKey and character_name.has_focus():
		return
	if event is InputEventKey:
		_handle_paint_input(event)


func _unhandled_input(event: InputEvent) -> void:
	if _paint_mode and _handle_paint_input(event):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pointer_press_pos = event.position
			_pointer_dragged = false
			_feature_click_pending = get_viewport().gui_get_hovered_control() == null
			if _feature_click_pending and character.begin_control_rig_drag(camera, event.position):
				_feature_click_pending = false
				_set_status("Dragging IK target. Elbow/knee limits are active.")
				get_viewport().set_input_as_handled()
		else:
			if character.is_control_rig_dragging():
				character.end_control_rig_drag()
				_set_status("3D pose target placed.")
				get_viewport().set_input_as_handled()
			elif _feature_click_pending and not _pointer_dragged:
				if _try_select_character_feature(event.position):
					get_viewport().set_input_as_handled()
			_feature_click_pending = false
	elif event is InputEventMouseMotion and character.is_control_rig_dragging():
		character.drag_control_rig(camera, event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if get_viewport().gui_get_hovered_control() != null:
			return
		if event.position.distance_to(_pointer_press_pos) > 7.0:
			_pointer_dragged = true
			_feature_click_pending = false
		if not _pointer_dragged:
			return
		_orbit_y -= event.relative.x * 0.008
		_orbit_x = clampf(_orbit_x - event.relative.y * 0.006, -0.48, 0.35)
		_apply_camera()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		if get_viewport().gui_get_hovered_control() != null:
			return
		var pan_speed := 0.0015 * _camera_distance
		var camera_right := camera.global_transform.basis.x.normalized()
		var camera_up := camera.global_transform.basis.y.normalized()
		_camera_pan += camera_right * (-event.relative.x * pan_speed)
		_camera_pan += camera_up * (event.relative.y * pan_speed)
		_apply_camera()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera_distance = maxf(1.8, _camera_distance - 0.2)
			_apply_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_distance = minf(5.5, _camera_distance + 0.2)
			_apply_camera()


func _on_control_rig_toggled(visible: bool) -> void:
	character.set_control_rig_visible(visible)
	_set_status("3D controls shown: hands/feet, joint bends, hips, ankles, toes, and body grab points." if visible else "3D controls hidden; precision sliders remain active.")


func _build_skin_swatches() -> void:
	for color in SKIN_TONES:
		var button := Button.new()
		button.custom_minimum_size = Vector2(54.0, 38.0)
		button.tooltip_text = "Skin %s" % color.to_html(false)
		button.add_theme_stylebox_override("normal", _swatch_style(color, 7.0))
		button.add_theme_stylebox_override("hover", _swatch_style(color.lightened(0.12), 7.0))
		button.add_theme_stylebox_override("pressed", _swatch_style(color.darkened(0.12), 7.0))
		button.pressed.connect(_on_skin_color_changed.bind(color))
		swatches.add_child(button)


func _swatch_style(color: Color, radius: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(1.0, 1.0, 1.0, 0.32)
	style.set_border_width_all(2)
	style.set_corner_radius_all(int(radius))
	return style


func _on_skin_color_changed(color: Color) -> void:
	character.set_skin_tone(color)
	custom_color.color = color
	if _paint_mode:
		_paint_color = color
	_set_status("Skin tone %s" % color.to_html(false).to_upper())


func _setup_paint_mode() -> void:
	var toggle := Button.new()
	toggle.name = "PaintModeButton"
	toggle.text = "PAINT SKIN"
	toggle.custom_minimum_size = Vector2(0.0, 42.0)
	toggle.tooltip_text = "Paint tattoos and markings directly on the character's skin. Clothes stay visible."
	toggle.pressed.connect(_toggle_paint_mode)
	var skin_label := sidebar_controls.get_node_or_null("SkinLabel")
	var insert_at := 0
	if skin_label != null:
		insert_at = skin_label.get_index()
	sidebar_controls.add_child(toggle)
	sidebar_controls.move_child(toggle, insert_at)

	_paint_panel = PanelContainer.new()
	_paint_panel.name = "PaintPanel"
	_paint_panel.visible = false
	_paint_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.06, 0.09, 0.94)
	panel_style.set_corner_radius_all(10)
	panel_style.set_border_width_all(1)
	panel_style.border_color = Color(0.35, 0.4, 0.52, 0.5)
	panel_style.content_margin_left = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_top = 10
	panel_style.content_margin_bottom = 10
	_paint_panel.add_theme_stylebox_override("panel", panel_style)
	_paint_panel.anchor_left = 0.5
	_paint_panel.anchor_right = 0.5
	_paint_panel.offset_left = -310.0
	_paint_panel.offset_right = 310.0
	_paint_panel.offset_top = 16.0
	_paint_panel.offset_bottom = 228.0
	$UI.add_child(_paint_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_paint_panel.add_child(column)
	var title := Label.new()
	title.text = "SKIN PAINT"
	title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.32, 1.0))
	title.add_theme_font_size_override("font_size", 16)
	column.add_child(title)

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	column.add_child(tools)
	for spec in [["soft", "Soft brush"], ["hard", "Hard brush"], ["erase", "Eraser"], ["blur", "Blur"], ["lasso", "Lasso"]]:
		var btn := Button.new()
		btn.text = str(spec[1])
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(0.0, 32.0)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_set_paint_tool.bind(str(spec[0])))
		tools.add_child(btn)
		_paint_tool_buttons[str(spec[0])] = btn

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)
	var size_label := Label.new()
	size_label.text = "Size"
	row.add_child(size_label)
	_paint_size_slider = HSlider.new()
	_paint_size_slider.min_value = 0.75
	_paint_size_slider.max_value = 96.0
	_paint_size_slider.step = 0.25
	_paint_size_slider.value = _paint_brush_size
	_paint_size_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_paint_size_slider.custom_minimum_size = Vector2(105.0, 22.0)
	_paint_size_slider.value_changed.connect(func(v: float):
		_paint_brush_size = v
		_queue_paint_canvas_redraw()
	)
	row.add_child(_paint_size_slider)
	var opacity_label := Label.new()
	opacity_label.text = "Opacity"
	row.add_child(opacity_label)
	_paint_opacity_slider = HSlider.new()
	_paint_opacity_slider.min_value = 0.01
	_paint_opacity_slider.max_value = 1.0
	_paint_opacity_slider.step = 0.01
	_paint_opacity_slider.value = _paint_opacity
	_paint_opacity_slider.custom_minimum_size = Vector2(90.0, 22.0)
	_paint_opacity_slider.value_changed.connect(func(v: float): _paint_opacity = v)
	row.add_child(_paint_opacity_slider)
	_paint_color_button = ColorPickerButton.new()
	_paint_color_button.custom_minimum_size = Vector2(106.0, 32.0)
	_paint_color_button.text = "Color (Space)"
	_paint_color_button.color = _paint_color
	_paint_color_button.color_changed.connect(func(c: Color): _paint_color = c)
	row.add_child(_paint_color_button)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	column.add_child(action_row)
	var flat_btn := CheckButton.new()
	flat_btn.text = "Flat UV canvas"
	flat_btn.tooltip_text = "Paint directly on the diffuse map with UV polygons ghosted over it."
	flat_btn.toggled.connect(_set_flat_paint_mode)
	action_row.add_child(flat_btn)
	_paint_unlit_toggle = CheckButton.new()
	_paint_unlit_toggle.text = "Unlit diffuse colors"
	_paint_unlit_toggle.tooltip_text = "Disable preview lights and show skin/paint at its direct diffuse color."
	_paint_unlit_toggle.toggled.connect(_set_paint_unlit_preview)
	action_row.add_child(_paint_unlit_toggle)
	var undo_btn := Button.new()
	undo_btn.text = "Undo (Ctrl+Z)"
	undo_btn.pressed.connect(_undo_paint_stroke)
	action_row.add_child(undo_btn)
	var clear_btn := Button.new()
	clear_btn.text = "Clear paint"
	clear_btn.pressed.connect(_clear_skin_paint)
	action_row.add_child(clear_btn)
	var done_btn := Button.new()
	done_btn.text = "Done"
	done_btn.pressed.connect(_toggle_paint_mode)
	action_row.add_child(done_btn)

	var history_row := HBoxContainer.new()
	history_row.add_theme_constant_override("separation", 8)
	column.add_child(history_row)
	var history_label := Label.new()
	history_label.text = "Stroke history"
	history_row.add_child(history_label)
	_paint_history_select = OptionButton.new()
	_paint_history_select.custom_minimum_size = Vector2(260.0, 30.0)
	_paint_history_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history_row.add_child(_paint_history_select)
	var remove_history_btn := Button.new()
	remove_history_btn.text = "Remove selected + newer"
	remove_history_btn.tooltip_text = "Roll back to before the selected stroke. Later strokes are also removed."
	remove_history_btn.pressed.connect(_remove_selected_paint_history)
	history_row.add_child(remove_history_btn)

	_paint_status = Label.new()
	_paint_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_paint_status.add_theme_color_override("font_color", Color(0.68, 0.73, 0.8, 1.0))
	_paint_status.text = "[ ] size · Space color · Ctrl+Z undo · left paint · right orbit · middle pan"
	column.add_child(_paint_status)

	_build_flat_paint_canvas()

	_paint_hud = Control.new()
	_paint_hud.name = "PaintHud"
	_paint_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_paint_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paint_hud.draw.connect(_draw_paint_hud)
	$UI.add_child(_paint_hud)
	_set_paint_tool("soft")


func _build_flat_paint_canvas() -> void:
	_flat_paint_panel = PanelContainer.new()
	_flat_paint_panel.name = "FlatSkinPaintPanel"
	_flat_paint_panel.visible = false
	_flat_paint_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_flat_paint_panel.anchor_left = 0.5
	_flat_paint_panel.anchor_right = 0.5
	_flat_paint_panel.anchor_top = 0.5
	_flat_paint_panel.anchor_bottom = 0.5
	_flat_paint_panel.offset_left = -250.0
	_flat_paint_panel.offset_right = 250.0
	## Keep the flat canvas below the 228 px paint toolbar, including the
	## standalone creator's 720 px window.
	_flat_paint_panel.offset_top = -105.0
	_flat_paint_panel.offset_bottom = 350.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.045, 0.065, 0.97)
	panel_style.border_color = Color(0.35, 0.44, 0.58, 0.75)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.content_margin_left = 10
	panel_style.content_margin_right = 10
	panel_style.content_margin_top = 8
	panel_style.content_margin_bottom = 10
	_flat_paint_panel.add_theme_stylebox_override("panel", panel_style)
	$UI.add_child(_flat_paint_panel)
	var flat_column := VBoxContainer.new()
	flat_column.add_theme_constant_override("separation", 6)
	_flat_paint_panel.add_child(flat_column)
	var title := Label.new()
	title.text = "FLAT SKIN DIFFUSE — ghost lines show UV polygon folds"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.38))
	flat_column.add_child(title)
	_flat_paint_canvas = Control.new()
	_flat_paint_canvas.name = "FlatSkinCanvas"
	_flat_paint_canvas.custom_minimum_size = Vector2(390, 390)
	_flat_paint_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_flat_paint_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_flat_paint_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_flat_paint_canvas.clip_contents = true
	_flat_paint_canvas.draw.connect(_draw_flat_paint_canvas)
	_flat_paint_canvas.gui_input.connect(_handle_flat_paint_canvas_input)
	flat_column.add_child(_flat_paint_canvas)
	var hint := Label.new()
	hint.text = "Paint directly here · [ ] size · Space color · Ctrl+Z undo"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.72, 0.78, 0.88))
	flat_column.add_child(hint)


func _set_flat_paint_mode(enabled: bool) -> void:
	_flat_paint_mode = enabled
	_paint_dragging = false
	_paint_last_uv = Vector2(-1.0, -1.0)
	_paint_lasso.clear()
	if _flat_paint_panel != null:
		_flat_paint_panel.visible = enabled and _paint_mode
	_queue_paint_canvas_redraw()
	_set_status("Flat diffuse canvas enabled; UV polygon folds are ghosted over the paint." if enabled else "Painting directly on the 3D character.")


func _set_paint_unlit_preview(enabled: bool) -> void:
	_paint_unlit_preview = enabled
	character.set_skin_paint_unlit_preview(enabled)
	var key_light := get_node_or_null("World/KeyLight") as Light3D
	var fill_light := get_node_or_null("World/FillLight") as Light3D
	if key_light != null:
		key_light.visible = not enabled
	if fill_light != null:
		fill_light.visible = not enabled
	var world_env := get_node_or_null("World/WorldEnvironment") as WorldEnvironment
	if world_env != null and world_env.environment != null:
		if enabled:
			_paint_saved_ambient_energy = world_env.environment.ambient_light_energy
			world_env.environment.ambient_light_energy = 0.0
		else:
			world_env.environment.ambient_light_energy = _paint_saved_ambient_energy
	_set_status("Unlit diffuse preview: paint and skin colors display without scene lighting." if enabled else "Character lighting restored.")


func _draw_flat_paint_canvas() -> void:
	if _flat_paint_canvas == null:
		return
	var rect := Rect2(Vector2.ZERO, _flat_paint_canvas.size)
	_flat_paint_canvas.draw_rect(rect, Color(0.11, 0.12, 0.15))
	var checker := 24.0
	for y in range(int(ceil(rect.size.y / checker))):
		for x in range(int(ceil(rect.size.x / checker))):
			if (x + y) % 2 == 0:
				_flat_paint_canvas.draw_rect(Rect2(x * checker, y * checker, checker, checker), Color(0.15, 0.16, 0.19))
	_flat_paint_canvas.draw_rect(rect, character.skin_color)
	var paint_tex := character.get_skin_paint_texture()
	if paint_tex != null:
		_flat_paint_canvas.draw_texture_rect(paint_tex, rect, false)
	var guide_lines: PackedVector2Array = character.get_skin_uv_guide_lines()
	if not guide_lines.is_empty():
		var resolution := maxf(float(character.get_skin_paint_resolution() - 1), 1.0)
		_flat_paint_canvas.draw_set_transform(Vector2.ZERO, 0.0, rect.size / Vector2(resolution, resolution))
		_flat_paint_canvas.draw_multiline(guide_lines, Color(0.82, 0.9, 1.0, 0.19), 1.0, true)
		_flat_paint_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _paint_tool != "lasso":
		var resolution := maxf(float(character.get_skin_paint_resolution()), 1.0)
		var radius := _paint_brush_size * rect.size.x / resolution
		_flat_paint_canvas.draw_arc(_flat_paint_canvas.get_local_mouse_position(), maxf(radius, 1.0), 0.0, TAU, 40, Color(1.0, 0.9, 0.35), 1.4, true)
	if _paint_lasso.size() > 0:
		for i in _paint_lasso.size():
			var a := _paint_lasso[i]
			var b := _paint_lasso[i + 1] if i < _paint_lasso.size() - 1 else _flat_paint_canvas.get_local_mouse_position()
			_flat_paint_canvas.draw_line(a, b, Color(1.0, 0.78, 0.25, 0.95), 2.0, true)


func _flat_canvas_uv(local_pos: Vector2) -> Vector2:
	if _flat_paint_canvas == null or _flat_paint_canvas.size.x <= 1.0 or _flat_paint_canvas.size.y <= 1.0:
		return Vector2(-1.0, -1.0)
	return Vector2(
		clampf(local_pos.x / _flat_paint_canvas.size.x, 0.0, 1.0),
		clampf(local_pos.y / _flat_paint_canvas.size.y, 0.0, 1.0)
	)


func _handle_flat_paint_canvas_input(event: InputEvent) -> void:
	if not _paint_mode or not _flat_paint_mode:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _paint_tool == "lasso":
				if event.double_click:
					_commit_paint_lasso()
				else:
					_paint_lasso.append(event.position)
			else:
				_begin_paint_stroke(_paint_tool.capitalize() + " stroke")
				_paint_dragging = true
				_paint_last_uv = Vector2(-1.0, -1.0)
				_apply_paint_uv(_flat_canvas_uv(event.position))
		else:
			_paint_dragging = false
			_paint_last_uv = Vector2(-1.0, -1.0)
			_end_paint_stroke()
		_flat_paint_canvas.accept_event()
	elif event is InputEventMouseMotion:
		if _paint_dragging and _paint_tool != "lasso":
			_apply_paint_uv(_flat_canvas_uv(event.position))
		_queue_paint_canvas_redraw()
		_flat_paint_canvas.accept_event()


func _queue_paint_canvas_redraw() -> void:
	if _paint_hud != null:
		_paint_hud.queue_redraw()
	if _flat_paint_canvas != null:
		_flat_paint_canvas.queue_redraw()


func _set_paint_brush_size(value: float) -> void:
	_paint_brush_size = clampf(value, 0.75, 96.0)
	if _paint_size_slider != null:
		_paint_size_slider.set_value_no_signal(_paint_brush_size)
	if _paint_status != null:
		_paint_status.text = "Brush %.2f px at 1024 resolution · [ ] resize · Space color" % _paint_brush_size
	_queue_paint_canvas_redraw()


func _open_paint_color_picker() -> void:
	if _paint_color_button == null:
		return
	var popup := _paint_color_button.get_popup()
	if popup != null:
		popup.popup_centered_clamped(Vector2i(470, 520), 0.88)


func _begin_paint_stroke(label: String) -> void:
	if not _paint_stroke_snapshot.is_empty():
		return
	_paint_stroke_snapshot = {
		"label": label,
		"png": character.get_skin_paint_snapshot_png(),
		"has_marks": character.has_skin_paint(),
	}
	_paint_stroke_changed = false


func _end_paint_stroke() -> void:
	if _paint_stroke_snapshot.is_empty():
		return
	if _paint_stroke_changed:
		_paint_history.append(_paint_stroke_snapshot.duplicate())
		if _paint_history.size() > 24:
			_paint_history.pop_front()
	_paint_stroke_snapshot.clear()
	_paint_stroke_changed = false
	_refresh_paint_history_ui()


func _undo_paint_stroke() -> void:
	_end_paint_stroke()
	if _paint_history.is_empty():
		_set_status("No paint stroke to undo.")
		return
	var entry: Dictionary = _paint_history.pop_back()
	character.restore_skin_paint_snapshot_png(entry.get("png", PackedByteArray()), bool(entry.get("has_marks", false)))
	_refresh_paint_history_ui()
	_queue_paint_canvas_redraw()
	_set_status("Undid %s." % str(entry.get("label", "paint stroke")))


func _remove_selected_paint_history() -> void:
	_end_paint_stroke()
	if _paint_history_select == null or _paint_history.is_empty():
		return
	var index := clampi(_paint_history_select.selected, 0, _paint_history.size() - 1)
	var entry: Dictionary = _paint_history[index]
	character.restore_skin_paint_snapshot_png(entry.get("png", PackedByteArray()), bool(entry.get("has_marks", false)))
	_paint_history.resize(index)
	_refresh_paint_history_ui()
	_queue_paint_canvas_redraw()
	_set_status("Removed selected stroke and all strokes after it.")


func _reset_paint_history() -> void:
	_paint_history.clear()
	_paint_stroke_snapshot.clear()
	_paint_stroke_changed = false
	_refresh_paint_history_ui()


func _refresh_paint_history_ui() -> void:
	if _paint_history_select == null:
		return
	_paint_history_select.clear()
	for i in _paint_history.size():
		var label := str(_paint_history[i].get("label", "Stroke"))
		_paint_history_select.add_item("%02d  %s" % [i + 1, label])
	if _paint_history.is_empty():
		_paint_history_select.add_item("No strokes yet")
		_paint_history_select.disabled = true
	else:
		_paint_history_select.disabled = false
		_paint_history_select.select(_paint_history.size() - 1)


func _toggle_paint_mode() -> void:
	_paint_mode = not _paint_mode
	if _fit_room_open and _paint_mode:
		_paint_mode = false
		_set_status("Leave Fit Room before painting skin.", true)
		return
	_paint_lasso.clear()
	_paint_dragging = false
	if _paint_panel != null:
		_paint_panel.visible = _paint_mode
	if _flat_paint_panel != null:
		_flat_paint_panel.visible = _paint_mode and _flat_paint_mode
	character.set_paint_mode_preview(_paint_mode)
	if _paint_mode:
		character.set_control_rig_visible(false)
		if control_rig_toggle != null:
			control_rig_toggle.set_pressed_no_signal(false)
		_set_status("Paint mode: paint exposed skin directly; clothes stay visible.")
	else:
		_end_paint_stroke()
		if _paint_unlit_preview:
			if _paint_unlit_toggle != null:
				_paint_unlit_toggle.set_pressed_no_signal(false)
			_set_paint_unlit_preview(false)
		character.set_control_rig_visible(control_rig_toggle.button_pressed)
		_set_status("Left paint mode.")


func _set_paint_tool(tool_id: String) -> void:
	_paint_tool = tool_id
	_paint_lasso.clear()
	for id in _paint_tool_buttons.keys():
		var btn: Button = _paint_tool_buttons[id] as Button
		if btn != null:
			btn.set_pressed_no_signal(id == tool_id)
	if _paint_status == null:
		return
	match tool_id:
		"hard":
			_paint_status.text = "Hard brush: crisp tattoo edges. [ ] changes size; Space opens color."
		"soft":
			_paint_status.text = "Soft brush: feathered edge. [ ] changes size; Space opens color."
		"blur":
			_paint_status.text = "Blur brush: drag on the model to soften painted marks."
		"erase":
			_paint_status.text = "Eraser: removes paint to reveal the original skin. Opacity controls erase strength."
		"lasso":
			_paint_status.text = "Polygon lasso: click points on the body, Enter or double-click to fill, Esc to cancel."
		_:
			_paint_status.text = "Paint directly on skin. Right-drag orbits; middle-drag pans."


func _clear_skin_paint() -> void:
	_begin_paint_stroke("Clear paint")
	character.clear_skin_paint()
	_paint_stroke_changed = true
	_end_paint_stroke()
	_queue_paint_canvas_redraw()
	_set_status("Cleared skin paint.")


func _handle_paint_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.ctrl_pressed and (event.keycode == KEY_Z or event.physical_keycode == KEY_Z):
			_undo_paint_stroke()
			get_viewport().set_input_as_handled()
			return true
		if event.keycode == KEY_BRACKETLEFT:
			_set_paint_brush_size(_paint_brush_size / 1.2)
			get_viewport().set_input_as_handled()
			return true
		if event.keycode == KEY_BRACKETRIGHT:
			_set_paint_brush_size(_paint_brush_size * 1.2)
			get_viewport().set_input_as_handled()
			return true
		if event.keycode == KEY_SPACE:
			_open_paint_color_picker()
			get_viewport().set_input_as_handled()
			return true
		if event.keycode == KEY_ESCAPE:
			if _paint_lasso.size() > 0:
				_paint_lasso.clear()
				_set_status("Cancelled lasso.")
				get_viewport().set_input_as_handled()
				return true
			_toggle_paint_mode()
			get_viewport().set_input_as_handled()
			return true
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_commit_paint_lasso()
			get_viewport().set_input_as_handled()
			return true
		if event.keycode == KEY_BACKSPACE and _paint_lasso.size() > 0:
			_paint_lasso.remove_at(_paint_lasso.size() - 1)
			get_viewport().set_input_as_handled()
			return true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			_pointer_press_pos = event.position
			_pointer_dragged = false
		get_viewport().set_input_as_handled()
		return true
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		if get_viewport().gui_get_hovered_control() != null and get_viewport().gui_get_hovered_control() != _paint_hud:
			if _paint_panel != null and _paint_panel.get_global_rect().has_point(event.position):
				return false
		_orbit_y -= event.relative.x * 0.008
		_orbit_x = clampf(_orbit_x - event.relative.y * 0.006, -0.48, 0.35)
		_apply_camera()
		get_viewport().set_input_as_handled()
		return true
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		if get_viewport().gui_get_hovered_control() != null:
			return false
		var pan_speed := 0.0015 * _camera_distance
		var camera_right := camera.global_transform.basis.x.normalized()
		var camera_up := camera.global_transform.basis.y.normalized()
		_camera_pan += camera_right * (-event.relative.x * pan_speed)
		_camera_pan += camera_up * (event.relative.y * pan_speed)
		_apply_camera()
		get_viewport().set_input_as_handled()
		return true
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera_distance = maxf(1.8, _camera_distance - 0.2)
			_apply_camera()
			get_viewport().set_input_as_handled()
			return true
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_distance = minf(5.5, _camera_distance + 0.2)
			_apply_camera()
			get_viewport().set_input_as_handled()
			return true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if get_viewport().gui_get_hovered_control() != null:
			return false
		if event.pressed:
			_paint_dragging = true
			_paint_last_uv = Vector2(-1.0, -1.0)
			if _paint_tool == "lasso":
				if event.double_click:
					_commit_paint_lasso()
				else:
					_paint_lasso.append(event.position)
					_set_status("Lasso point %d. Enter or double-click to fill." % _paint_lasso.size())
			else:
				_begin_paint_stroke(_paint_tool.capitalize() + " stroke")
				_apply_paint_at(event.position)
		else:
			_paint_dragging = false
			_paint_last_uv = Vector2(-1.0, -1.0)
			_end_paint_stroke()
		get_viewport().set_input_as_handled()
		return true
	if event is InputEventMouseMotion and _paint_dragging and _paint_tool != "lasso":
		if get_viewport().gui_get_hovered_control() != null:
			return false
		_apply_paint_at(event.position)
		get_viewport().set_input_as_handled()
		return true
	return false


func _apply_paint_at(screen_pos: Vector2) -> void:
	var uv := character.pick_skin_uv(camera, screen_pos)
	if uv.x < 0.0:
		return
	_apply_paint_uv(uv)


func _apply_paint_uv(uv: Vector2) -> void:
	if uv.x < 0.0:
		return
	var resolution := float(character.get_skin_paint_resolution())
	## Blur snapshots a local source image per dab, so one dab per pointer event
	## avoids duplicating the 1024 canvas dozens of times during interpolation.
	if _paint_tool == "blur":
		_stamp_paint(uv, false)
	elif _paint_last_uv.x >= 0.0:
		var distance_px := _paint_last_uv.distance_to(uv) * resolution
		var spacing_px := maxf(0.6, _paint_brush_size * 0.32)
		var steps := clampi(int(ceil(distance_px / spacing_px)), 1, 160)
		for i in range(1, steps + 1):
			var t := float(i) / float(steps)
			_stamp_paint(_paint_last_uv.lerp(uv, t), false)
	else:
		_stamp_paint(uv, false)
	character.commit_skin_paint()
	_paint_stroke_changed = true
	_paint_last_uv = uv
	_queue_paint_canvas_redraw()


func _stamp_paint(uv: Vector2, commit: bool = true) -> void:
	if _paint_tool == "blur":
		character.blur_skin_stamp(uv, _paint_brush_size, commit)
	elif _paint_tool == "erase":
		character.erase_skin_stamp(uv, _paint_brush_size, _paint_opacity, commit)
	else:
		var stroke_color := _paint_color
		stroke_color.a = _paint_opacity
		character.paint_skin_stamp(uv, _paint_brush_size, stroke_color, _paint_tool == "hard", commit)


func _commit_paint_lasso() -> void:
	if _paint_lasso.size() < 3:
		_set_status("Need at least 3 lasso points.", true)
		return
	_begin_paint_stroke("Lasso fill")
	var fill_color := _paint_color
	fill_color.a = _paint_opacity
	if _flat_paint_mode and _flat_paint_canvas != null:
		var polygon_uv := PackedVector2Array()
		for point in _paint_lasso:
			polygon_uv.append(_flat_canvas_uv(point))
		character.fill_skin_uv_lasso(polygon_uv, fill_color, _paint_tool == "hard")
	else:
		character.fill_skin_lasso(camera, _paint_lasso, fill_color)
	_paint_stroke_changed = true
	_end_paint_stroke()
	_paint_lasso.clear()
	_queue_paint_canvas_redraw()
	_set_status("Filled lasso on the skin.")


func _draw_paint_hud() -> void:
	if _paint_hud == null or not _paint_mode:
		return
	var mouse := get_viewport().get_mouse_position()
	if _paint_tool != "lasso":
		var radius := maxf(1.0, _paint_brush_size * 0.45)
		_paint_hud.draw_arc(mouse, radius, 0.0, TAU, 36, Color(1.0, 0.92, 0.45, 0.85), 1.5, true)
	if _paint_lasso.size() > 0:
		for i in _paint_lasso.size():
			var a := _paint_lasso[i]
			var b := _paint_lasso[(i + 1) % _paint_lasso.size()] if i < _paint_lasso.size() - 1 or _paint_lasso.size() > 2 else mouse
			_paint_hud.draw_line(a, b, Color(1.0, 0.82, 0.22, 0.95), 2.0, true)
			_paint_hud.draw_circle(a, 4.0, Color(1.0, 0.9, 0.3, 1.0))
		if not _paint_lasso.is_empty():
			_paint_hud.draw_line(_paint_lasso[_paint_lasso.size() - 1], mouse, Color(1.0, 0.82, 0.22, 0.55), 1.5, true)


func _rand_style(count: int, none_chance: float) -> int:
	if count <= 1:
		return 0
	if none_chance > 0.0 and randf() < none_chance:
		return 0
	if none_chance <= 0.0:
		return randi() % count
	return 1 + randi() % (count - 1)


func _rand_hsv(sat_min: float, sat_max: float, val_min: float, val_max: float) -> Color:
	return Color.from_hsv(randf(), randf_range(sat_min, sat_max), randf_range(val_min, val_max))


func _apply_canonical_face_layout() -> void:
	character.eye_width = 1.0
	character.eye_height = 0.6
	character.eye_vertical = -0.04
	character.eye_spacing = 1.0
	character.eye_depth = -0.18
	character.eye_pupil_size = 0.64
	character.eye_pupil_inward = 0.22
	character.eye_sclera_brightness = 1.0
	character.eye_specular_scale = 0.75
	character.eye_specular_horizontal = -0.025
	character.eye_specular_vertical = 0.04
	character.eye_specular_depth = 0.0
	character.left_eye_yaw = -0.6
	character.right_eye_yaw = 0.6
	character.eyelid_enabled = true
	character.eyelid_scale = 1.0
	character.eyelid_width = 1.0
	character.eyelid_height = 1.0
	character.eyelid_depth = 1.0
	character.eyelid_vertical = 0.0
	character.eyelid_forward = 0.0
	character.eyelid_mask_height = 0.42
	character.eyelid_mask_width = 0.88
	character.nose_style = ModularCharacterBase.NoseStyle.BUTTON
	character.nose_width = 1.0
	character.nose_height = 1.0
	character.nose_vertical = 0.04
	character.nose_depth = -0.14
	character.mouth_style = ModularCharacterBase.MouthStyle.SMILE
	character.mouth_width = 0.7
	character.mouth_height = 0.45
	character.mouth_vertical = 0.05
	character.mouth_depth = -0.12
	character.mouth_curve = 0.10
	character.mouth_shadow_size = 0.20
	character.mouth_shadow_position = 0.0
	character.mouth_shadow_softness = 0.10
	character.mouth_shadow_width = 1.0
	character.brow_vertical = -0.02
	character.brow_depth = -0.03
	character.left_brow_yaw = -0.72
	character.right_brow_yaw = 0.67


func _randomize_character() -> void:
	if _fit_room_open:
		_set_status("Leave Fit Room before randomizing.", true)
		return
	## A randomized character is a new customer design, never a continuation of
	## the previous customer's tattoo/paint texture.
	character.clear_skin_paint()
	_reset_paint_history()
	character.begin_appearance_batch()
	var skin: Color = SKIN_TONES[randi() % SKIN_TONES.size()]
	character.set_skin_tone(skin)
	_apply_canonical_face_layout()
	character.nose_color = skin.lerp(Color("e84242"), randf_range(0.15, 0.85))
	character.mouth_color = Color.from_hsv(randf_range(0.96, 1.02), randf_range(0.45, 0.82), randf_range(0.28, 0.62))
	character.mouth_shadow_color = Color(0.02, 0.01, 0.02, randf_range(0.7, 0.9))
	character.lash_style = ModularCharacterBase.LashStyle.NONE
	character.lash_rim_width = 0.035
	character.brow_style = _rand_style(ModularCharacterBase.BrowStyle.size(), 0.12) as ModularCharacterBase.BrowStyle
	character.brow_color = _rand_hsv(0.02, 0.12, 0.08, 0.32)
	character.brow_scale = randf_range(0.75, 1.4)
	character.brow_width = randf_range(0.75, 1.4)
	character.brow_height = randf_range(0.7, 1.35)
	character.cheek_style = _rand_style(ModularCharacterBase.CheekStyle.size(), 0.5) as ModularCharacterBase.CheekStyle
	character.cheek_color = Color.from_hsv(randf_range(0.96, 1.04), randf_range(0.35, 0.7), randf_range(0.55, 0.9), randf_range(0.28, 0.7))
	character.ear_color = skin
	character.ear_scale = randf_range(0.8, 1.25)
	character.ear_spacing = randf_range(0.85, 1.2)
	character.hair_style = _random_hair_style()
	if randf() < 0.22:
		character.hair_color = Color.from_hsv(0.08, randf_range(0.0, 0.12), randf_range(0.12, 0.92))
	else:
		character.hair_color = _rand_hsv(0.15, 0.85, 0.12, 0.55)
	_apply_hair_fit(int(character.hair_style))
	character.facial_hair_style = ModularCharacterBase.FacialHairStyle.NONE
	character.facial_hair_scale_xyz = Vector3.ONE
	character.facial_hair_offset = Vector3.ZERO
	character.hat_style = ModularCharacterBase.HatStyle.NONE
	character.hat_scale = 1.0
	character.hat_offset = Vector3.ZERO
	character.hat_rotation = Vector3.ZERO
	var fitted_hats := _fitted_hat_ids()
	if not fitted_hats.is_empty() and randf() < 0.28:
		var hat_id: int = fitted_hats[randi() % fitted_hats.size()]
		character.hat_style = hat_id as ModularCharacterBase.HatStyle
		character.hat_color = _rand_hsv(0.35, 0.85, 0.2, 0.75)
		_apply_hat_fit(hat_id)
	character.glasses_style = _rand_style(ModularCharacterBase.GlassesStyle.size(), 0.78) as ModularCharacterBase.GlassesStyle
	character.glasses_color = _rand_hsv(0.2, 0.8, 0.08, 0.45)
	character.glasses_scale = randf_range(0.9, 1.2)
	character.glasses_offset = Vector3(0.0, 0.28, 0.43)
	character.makeup_style = ModularCharacterBase.MakeupStyle.NONE
	character.makeup_offset = Vector3.ZERO
	character.jewelry_style = _rand_style(ModularCharacterBase.JewelryStyle.size(), 0.65) as ModularCharacterBase.JewelryStyle
	character.jewelry_color = Color.from_hsv(randf_range(0.08, 0.18), randf_range(0.35, 0.8), randf_range(0.55, 0.95))
	character.jewelry_scale = randf_range(0.85, 1.3)
	character.jewelry_offset = Vector3.ZERO
	character.top_style = _rand_style(ModularCharacterBase.TopStyle.size(), 0.0) as ModularCharacterBase.TopStyle
	character.top_color = _rand_hsv(0.4, 0.9, 0.25, 0.85)
	character.top_scale = randf_range(0.96, 1.08)
	if character.top_style == ModularCharacterBase.TopStyle.NONE:
		character.shirt_graphic = ModularCharacterBase.ShirtGraphic.NONE
	else:
		character.shirt_graphic = _rand_style(ModularCharacterBase.ShirtGraphic.size(), 0.55) as ModularCharacterBase.ShirtGraphic
	character.shirt_graphic_color = _rand_hsv(0.45, 0.95, 0.35, 1.0)
	character.shirt_graphic_scale = randf_range(0.7, 1.4)
	character.bottom_style = _rand_style(ModularCharacterBase.BottomStyle.size(), 0.0) as ModularCharacterBase.BottomStyle
	character.bottom_color = _rand_hsv(0.35, 0.8, 0.18, 0.7)
	character.bottom_scale = randf_range(0.96, 1.08)
	character.shoe_style = _rand_style(ModularCharacterBase.ShoeStyle.size(), 0.12) as ModularCharacterBase.ShoeStyle
	character.shoe_color = _rand_hsv(0.25, 0.75, 0.12, 0.55)
	character.shoe_scale = randf_range(0.98, 1.12)
	character.end_appearance_batch()
	_refresh_appearance_controls()
	_set_status("Randomized a new look. Kept the saved eye, nose, and mouth layout.")


func _refresh_appearance_controls() -> void:
	custom_color.color = character.skin_color
	nose_select.select(character.nose_style)
	nose_color.color = character.nose_color
	mouth_select.select(character.mouth_style)
	mouth_color.color = character.mouth_color
	lash_select.select(character.lash_style)
	lash_color.color = character.lash_color
	cheek_select.select(character.cheek_style)
	cheek_color.color = character.cheek_color
	ear_color.color = character.ear_color
	hair_select.select(character.hair_style)
	hair_color.color = character.hair_color
	facial_hair_select.select(character.facial_hair_style)
	facial_hair_color.color = character.facial_hair_color
	hat_select.select(character.hat_style)
	hat_color.color = character.hat_color
	top_select.select(character.top_style)
	top_color.color = character.top_color
	graphic_select.select(character.shirt_graphic)
	graphic_color.color = character.shirt_graphic_color
	glasses_select.select(character.glasses_style)
	glasses_color.color = character.glasses_color
	makeup_select.select(character.makeup_style)
	makeup_color.color = character.makeup_color
	jewelry_select.select(character.jewelry_style)
	jewelry_color.color = character.jewelry_color
	bottom_select.select(character.bottom_style)
	bottom_color.color = character.bottom_color
	shoe_select.select(character.shoe_style)
	shoe_color.color = character.shoe_color
	eyebrow_select.select(character.brow_style)
	eyebrow_color.color = character.brow_color
	_sync_adjustment_controls()


func _reset_view() -> void:
	_orbit_y = 0.0
	_orbit_x = -0.08
	if _fit_room_open:
		_apply_fit_room_camera()
		return
	_camera_distance = 3.35
	_camera_pan = Vector3.ZERO
	_apply_camera()


func _toggle_animation_preview() -> void:
	if character.is_preview_animation_playing():
		character.stop_preview_animation()
		animation_button.text = "Play animation"
		_set_status("Animation preview stopped.")
	else:
		character.start_preview_animation(animation_select.selected)
		animation_button.text = "Stop animation"
		_set_status("Previewing %s." % animation_select.get_item_text(animation_select.selected))


func _on_preview_animation_selected(index: int) -> void:
	if character.is_preview_animation_playing():
		character.start_preview_animation(index)
		_set_status("Previewing %s." % animation_select.get_item_text(index))


func _on_pose_control_changed(control_name: String, value: float) -> void:
	var was_previewing := character.is_preview_animation_playing()
	character.set_pose_control(control_name, value)
	if was_previewing:
		animation_button.text = "Play animation"
	_set_status("Pose rig: %s %.0f degrees" % [control_name.replace("_", " ").capitalize(), value])


func _reset_character_pose() -> void:
	character.reset_pose_controls()
	animation_button.text = "Play animation"
	_sync_adjustment_controls()
	_set_status("Pose reset to the character's clean rest pose.")


func _apply_camera() -> void:
	camera_rig.position = Vector3(0.0, 1.05, 0.0) + _camera_pan
	camera_rig.rotation = Vector3(_orbit_x, _orbit_y, 0.0)
	camera.position.z = _camera_distance


func _save_character() -> void:
	if _fit_room_open:
		_set_status("Leave Fit Room before saving a character.", true)
		return
	var display_name := character_name.text.strip_edges()
	if display_name.is_empty():
		display_name = "New Customer"
		character_name.text = display_name
	var safe_name := _safe_file_name(display_name)
	var folder := ProjectSettings.globalize_path("user://characters")
	DirAccess.make_dir_recursive_absolute(folder)
	var data := {
		"format_version": 12,
		"name": display_name,
		"body_type": "kenney_chunky_toon",
		"skin_color": character.skin_color.to_html(true),
		"skin_paint": character.get_skin_paint_png_base64(),
		"eyes": "procedural_masked_spheres",
		"eye_width": character.eye_width,
		"eye_height": character.eye_height,
		"eye_vertical": character.eye_vertical,
		"eye_spacing": character.eye_spacing,
		"eye_depth": character.eye_depth,
		"eye_pupil_size": character.eye_pupil_size,
		"eye_pupil_inward": character.eye_pupil_inward,
		"eye_sclera_brightness": character.eye_sclera_brightness,
		"left_eye_yaw": character.left_eye_yaw,
		"right_eye_yaw": character.right_eye_yaw,
		"eye_specular_scale": character.eye_specular_scale,
		"eye_specular_horizontal": character.eye_specular_horizontal,
		"eye_specular_vertical": character.eye_specular_vertical,
		"eye_specular_depth": character.eye_specular_depth,
		"eyelid_enabled": character.eyelid_enabled,
		"eyelid_scale": character.eyelid_scale,
		"eyelid_width": character.eyelid_width,
		"eyelid_height": character.eyelid_height,
		"eyelid_depth": character.eyelid_depth,
		"eyelid_vertical": character.eyelid_vertical,
		"eyelid_forward": character.eyelid_forward,
		"eyelid_mask_height": character.eyelid_mask_height,
		"eyelid_mask_width": character.eyelid_mask_width,
		"lash_style": int(character.lash_style),
		"eye_opening_version": 1,
		"lash_color": character.lash_color.to_html(true),
		"lash_rim_width": character.lash_rim_width,
		"brow_style": int(character.brow_style),
		"brow_color": character.brow_color.to_html(true),
		"brow_scale": character.brow_scale,
		"brow_width": character.brow_width,
		"brow_height": character.brow_height,
		"brow_vertical": character.brow_vertical,
		"brow_spacing": character.brow_spacing,
		"brow_depth": character.brow_depth,
		"left_brow_yaw": character.left_brow_yaw,
		"right_brow_yaw": character.right_brow_yaw,
		"nose_style": int(character.nose_style),
		"nose_color": character.nose_color.to_html(true),
		"nose_width": character.nose_width,
		"nose_height": character.nose_height,
		"nose_depth": character.nose_depth,
		"nose_vertical": character.nose_vertical,
		"mouth_style": int(character.mouth_style),
		"mouth_color": character.mouth_color.to_html(true),
		"mouth_width": character.mouth_width,
		"mouth_height": character.mouth_height,
		"mouth_depth": character.mouth_depth,
		"mouth_vertical": character.mouth_vertical,
		"mouth_curve": character.mouth_curve,
		"mouth_shadow_color": character.mouth_shadow_color.to_html(true),
		"mouth_shadow_size": character.mouth_shadow_size,
		"mouth_shadow_position": character.mouth_shadow_position,
		"mouth_shadow_softness": character.mouth_shadow_softness,
		"mouth_shadow_width": character.mouth_shadow_width,
		"cheek_style": int(character.cheek_style),
		"cheek_color": character.cheek_color.to_html(true),
		"cheek_scale": character.cheek_scale,
		"cheek_width": character.cheek_width,
		"cheek_height": character.cheek_height,
		"cheek_vertical": character.cheek_vertical,
		"cheek_spacing": character.cheek_spacing,
		"cheek_depth": character.cheek_depth,
		"ear_color": character.ear_color.to_html(true),
		"ear_scale": character.ear_scale,
		"ear_spacing": character.ear_spacing,
		"ear_depth": character.ear_depth,
		"hair_style": int(character.hair_style),
		"hair_color": character.hair_color.to_html(true),
		"hair_scale": character.hair_scale,
		"hair_scale_xyz": [character.hair_scale_xyz.x, character.hair_scale_xyz.y, character.hair_scale_xyz.z],
		"hair_offset": [character.hair_offset.x, character.hair_offset.y, character.hair_offset.z],
		"facial_hair_style": int(character.facial_hair_style),
		"facial_hair_color": character.facial_hair_color.to_html(true),
		"facial_hair_scale": character.facial_hair_scale,
		"facial_hair_scale_xyz": [character.facial_hair_scale_xyz.x, character.facial_hair_scale_xyz.y, character.facial_hair_scale_xyz.z],
		"facial_hair_offset": [character.facial_hair_offset.x, character.facial_hair_offset.y, character.facial_hair_offset.z],
		"hat_style": int(character.hat_style),
		"hat_color": character.hat_color.to_html(true),
		"hat_scale": character.hat_scale,
		"hat_offset": [character.hat_offset.x, character.hat_offset.y, character.hat_offset.z],
		"hat_rotation": [character.hat_rotation.x, character.hat_rotation.y, character.hat_rotation.z],
		"glasses_style": int(character.glasses_style),
		"glasses_color": character.glasses_color.to_html(true),
		"glasses_scale": character.glasses_scale,
		"glasses_offset": [character.glasses_offset.x, character.glasses_offset.y, character.glasses_offset.z],
		"makeup_style": int(character.makeup_style),
		"makeup_color": character.makeup_color.to_html(true),
		"makeup_scale": character.makeup_scale,
		"makeup_offset": [character.makeup_offset.x, character.makeup_offset.y, character.makeup_offset.z],
		"jewelry_style": int(character.jewelry_style),
		"jewelry_color": character.jewelry_color.to_html(true),
		"jewelry_scale": character.jewelry_scale,
		"jewelry_offset": [character.jewelry_offset.x, character.jewelry_offset.y, character.jewelry_offset.z],
		"top_style": int(character.top_style),
		"top_color": character.top_color.to_html(true),
		"top_scale": character.top_scale,
		"shirt_graphic": int(character.shirt_graphic),
		"shirt_graphic_color": character.shirt_graphic_color.to_html(true),
		"shirt_graphic_scale": character.shirt_graphic_scale,
		"shirt_graphic_horizontal": character.shirt_graphic_horizontal,
		"shirt_graphic_vertical": character.shirt_graphic_vertical,
		"shirt_graphic_depth": character.shirt_graphic_depth,
		"bottom_style": int(character.bottom_style),
		"bottom_color": character.bottom_color.to_html(true),
		"bottom_scale": character.bottom_scale,
		"shoe_style": int(character.shoe_style),
		"shoe_color": character.shoe_color.to_html(true),
		"shoe_scale": character.shoe_scale,
		"pose_controls": character.get_pose_controls(),
		"control_rig_targets": character.get_control_rig_targets(),
		"saved_at": Time.get_datetime_string_from_system(),
	}
	var json := JSON.stringify(data, "\t")
	var preset_path := "user://characters/%s.json" % safe_name
	if not _write_text(preset_path, json) or not _write_text(LAST_PRESET_PATH, json):
		_set_status("Could not save the character preset.", true)
		return
	_capture_customer_thumbnail(safe_name)
	_set_status("Saved %s — this customer can now visit the truck." % display_name)


func _load_last_character() -> void:
	_load_character_file(LAST_PRESET_PATH)


func _load_character_file(preset_path: String) -> void:
	if _fit_room_open:
		_set_status("Leave Fit Room before loading a character.", true)
		return
	if not FileAccess.file_exists(preset_path):
		_set_status("No saved character yet.", true)
		return
	var file := FileAccess.open(preset_path, FileAccess.READ)
	if file == null:
		_set_status("Could not open the saved character.", true)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_set_status("The saved character file is invalid.", true)
		return
	var data := parsed as Dictionary
	ModularCharacterBase.migrate_legacy_hair_fields(data)
	character_name.text = str(data.get("name", "New Customer"))
	character.begin_appearance_batch()
	var loaded_color := Color.from_string(str(data.get("skin_color", "b86e47ff")), Color("b86e47"))
	character.set_skin_tone(loaded_color)
	custom_color.color = loaded_color
	character.set_skin_paint_png_base64(str(data.get("skin_paint", "")))
	if int(data.get("format_version", 1)) < 11:
		character.migrate_legacy_skin_paint_v_flip()
	_reset_paint_history()
	var legacy_eye_size := float(data.get("eye_size", 1.0))
	character.eye_width = clampf(float(data.get("eye_width", legacy_eye_size)), 0.4, 2.0)
	character.eye_height = clampf(float(data.get("eye_height", 0.6)), 0.4, 2.0)
	character.eye_vertical = clampf(float(data.get("eye_vertical", -0.04)), -0.12, 0.14)
	character.eye_spacing = clampf(float(data.get("eye_spacing", 1.0)), 0.45, 1.8)
	character.eye_depth = clampf(float(data.get("eye_depth", -0.18)), -0.35, 0.25)
	character.eye_pupil_size = clampf(float(data.get("eye_pupil_size", 0.64)), 0.12, 0.92)
	character.eye_pupil_inward = clampf(float(data.get("eye_pupil_inward", 0.22)), -0.55, 0.55)
	character.eye_sclera_brightness = clampf(float(data.get("eye_sclera_brightness", 1.0)), 0.15, 1.0)
	character.left_eye_yaw = clampf(float(data.get("left_eye_yaw", -0.6)), -0.8, 0.8)
	character.right_eye_yaw = clampf(float(data.get("right_eye_yaw", 0.6)), -0.8, 0.8)
	character.eye_specular_scale = clampf(float(data.get("eye_specular_scale", 0.75)), 0.3, 2.0)
	character.eye_specular_horizontal = clampf(float(data.get("eye_specular_horizontal", -0.025)), -0.08, 0.08)
	character.eye_specular_vertical = clampf(float(data.get("eye_specular_vertical", 0.04)), -0.10, 0.10)
	character.eye_specular_depth = clampf(float(data.get("eye_specular_depth", 0.0)), -0.05, 0.08)
	character.eyelid_enabled = true
	character.eyelid_scale = clampf(float(data.get("eyelid_scale", 1.0)), 0.5, 2.2)
	character.eyelid_width = clampf(float(data.get("eyelid_width", 1.0)), 0.4, 2.0)
	character.eyelid_height = clampf(float(data.get("eyelid_height", 1.0)), 0.4, 2.0)
	character.eyelid_depth = clampf(float(data.get("eyelid_depth", 1.0)), 0.4, 2.0)
	character.eyelid_vertical = clampf(float(data.get("eyelid_vertical", 0.0)), -0.12, 0.12)
	character.eyelid_forward = clampf(float(data.get("eyelid_forward", 0.0)), -0.12, 0.12)
	character.eyelid_mask_height = clampf(float(data.get("eyelid_mask_height", 0.42)), 0.0, 1.0)
	character.eyelid_mask_width = clampf(float(data.get("eyelid_mask_width", 0.88)), 0.0, 1.5)
	var saved_lash_style := int(data.get("lash_style", 0))
	if int(data.get("eye_opening_version", 0)) >= 1:
		character.lash_style = clampi(saved_lash_style, 0, 3) as ModularCharacterBase.LashStyle
	else:
		character.lash_style = ModularCharacterBase.LashStyle.NONE
	character.lash_color = Color.from_string(str(data.get("lash_color", "241817ff")), Color("241817"))
	character.lash_rim_width = clampf(float(data.get("lash_rim_width", 0.035)), 0.01, 0.36)
	character.brow_style = clampi(int(data.get("brow_style", 1)), 0, 4) as ModularCharacterBase.BrowStyle
	character.brow_color = Color.from_string(str(data.get("brow_color", "35231dff")), Color("35231d"))
	character.brow_scale = clampf(float(data.get("brow_scale", 1.0)), 0.5, 2.0)
	character.brow_width = clampf(float(data.get("brow_width", 1.0)), 0.5, 2.0)
	character.brow_height = clampf(float(data.get("brow_height", 1.0)), 0.5, 2.0)
	character.brow_vertical = clampf(float(data.get("brow_vertical", -0.02)), -0.12, 0.14)
	character.brow_spacing = clampf(float(data.get("brow_spacing", 1.0)), 0.6, 1.6)
	character.brow_depth = clampf(float(data.get("brow_depth", -0.03)), -0.10, 0.10)
	character.left_brow_yaw = clampf(float(data.get("left_brow_yaw", -0.72)), -0.8, 0.8)
	character.right_brow_yaw = clampf(float(data.get("right_brow_yaw", 0.67)), -0.8, 0.8)
	character.nose_style = clampi(int(data.get("nose_style", 1)), 0, 2) as ModularCharacterBase.NoseStyle
	character.nose_color = Color.from_string(str(data.get("nose_color", "e84242ff")), Color("e84242"))
	character.nose_width = clampf(float(data.get("nose_width", 1.0)), 0.4, 2.0)
	character.nose_height = clampf(float(data.get("nose_height", 1.0)), 0.4, 2.0)
	character.nose_depth = clampf(float(data.get("nose_depth", -0.14)), -0.35, 0.25)
	character.nose_vertical = clampf(float(data.get("nose_vertical", 0.04)), -0.18, 0.18)
	character.mouth_style = clampi(int(data.get("mouth_style", 0)), 0, 2) as ModularCharacterBase.MouthStyle
	character.mouth_color = Color.from_string(str(data.get("mouth_color", "791f26ff")), Color("791f26"))
	character.mouth_width = clampf(float(data.get("mouth_width", 0.7)), 0.4, 2.0)
	character.mouth_height = clampf(float(data.get("mouth_height", 0.45)), 0.4, 2.0)
	character.mouth_depth = clampf(float(data.get("mouth_depth", -0.12)), -0.35, 0.25)
	character.mouth_vertical = clampf(float(data.get("mouth_vertical", 0.05)), -0.18, 0.18)
	character.mouth_curve = clampf(float(data.get("mouth_curve", 0.10)), 0.0, 0.45)
	character.mouth_shadow_color = Color.from_string(str(data.get("mouth_shadow_color", "050203d1")), Color(0.02, 0.01, 0.02, 0.82))
	character.mouth_shadow_size = clampf(float(data.get("mouth_shadow_size", 0.20)), 0.0, 1.0)
	character.mouth_shadow_position = clampf(float(data.get("mouth_shadow_position", 0.0)), -0.40, 0.60)
	character.mouth_shadow_softness = clampf(float(data.get("mouth_shadow_softness", 0.10)), 0.0, 0.45)
	character.mouth_shadow_width = clampf(float(data.get("mouth_shadow_width", 1.0)), 0.15, 1.0)
	character.cheek_style = clampi(int(data.get("cheek_style", 0)), 0, 1) as ModularCharacterBase.CheekStyle
	character.cheek_color = Color.from_string(str(data.get("cheek_color", "f21f2eb8")), Color(0.95, 0.12, 0.18, 0.72))
	character.cheek_scale = clampf(float(data.get("cheek_scale", 1.0)), 0.4, 2.0)
	character.cheek_width = clampf(float(data.get("cheek_width", 1.0)), 0.4, 2.0)
	character.cheek_height = clampf(float(data.get("cheek_height", 1.0)), 0.4, 2.0)
	character.cheek_vertical = clampf(float(data.get("cheek_vertical", 0.0)), -0.18, 0.18)
	character.cheek_spacing = clampf(float(data.get("cheek_spacing", 1.0)), 0.5, 1.8)
	character.cheek_depth = clampf(float(data.get("cheek_depth", 0.0)), -0.50, 0.35)
	character.ear_color = Color.from_string(str(data.get("ear_color", "d88b5fff")), Color("d88b5f"))
	character.ear_scale = clampf(float(data.get("ear_scale", 1.0)), 0.4, 2.0)
	character.ear_spacing = clampf(float(data.get("ear_spacing", 1.0)), 0.6, 1.8)
	character.ear_depth = clampf(float(data.get("ear_depth", 0.0)), -0.35, 0.25)
	character.hair_style = clampi(int(data.get("hair_style", 0)), 0, ModularCharacterBase.HairStyle.size() - 1) as ModularCharacterBase.HairStyle
	character.hair_color = Color.from_string(str(data.get("hair_color", "35231dff")), Color("35231d"))
	character.hair_scale = clampf(float(data.get("hair_scale", 1.3)), 0.3, 3.0)
	character.hair_scale_xyz = _clamped_scale_xyz(data.get("hair_scale_xyz", [1.0, 1.0, 1.0]))
	character.hair_offset = _vector3_from_array(data.get("hair_offset", [0.0, 0.3, 0.0]))
	character.facial_hair_style = clampi(int(data.get("facial_hair_style", 0)), 0, ModularCharacterBase.FacialHairStyle.size() - 1) as ModularCharacterBase.FacialHairStyle
	character.facial_hair_color = Color.from_string(str(data.get("facial_hair_color", "35231dff")), Color("35231d"))
	character.facial_hair_scale = clampf(float(data.get("facial_hair_scale", 1.0)), 0.3, 3.0)
	character.facial_hair_scale_xyz = _clamped_scale_xyz(data.get("facial_hair_scale_xyz", [1.0, 1.0, 1.0]))
	character.facial_hair_offset = _vector3_from_array(data.get("facial_hair_offset", [0.0, 0.0, 0.0]))
	character.hat_style = clampi(int(data.get("hat_style", 0)), 0, ModularCharacterBase.HatStyle.size() - 1) as ModularCharacterBase.HatStyle
	character.hat_color = Color.from_string(str(data.get("hat_color", "d94b3dff")), Color("d94b3d"))
	character.hat_scale = clampf(float(data.get("hat_scale", 1.0)), 0.5, 2.0)
	character.hat_offset = _vector3_from_array(data.get("hat_offset", [0.0, 0.0, 0.0]))
	character.hat_rotation = _vector3_from_array(data.get("hat_rotation", [0.0, 0.0, 0.0]))
	character.glasses_style = clampi(int(data.get("glasses_style", 0)), 0, ModularCharacterBase.GlassesStyle.size() - 1) as ModularCharacterBase.GlassesStyle
	character.glasses_color = Color.from_string(str(data.get("glasses_color", "20242bff")), Color("20242b"))
	character.glasses_scale = clampf(float(data.get("glasses_scale", 1.0)), 0.5, 2.0)
	character.glasses_offset = _vector3_from_array(data.get("glasses_offset", [0.0, 0.28, 0.43]))
	character.makeup_style = clampi(int(data.get("makeup_style", 0)), 0, ModularCharacterBase.MakeupStyle.size() - 1) as ModularCharacterBase.MakeupStyle
	character.makeup_color = Color.from_string(str(data.get("makeup_color", "8c2e73b8")), Color(0.55, 0.18, 0.45, 0.72))
	character.makeup_scale = clampf(float(data.get("makeup_scale", 1.0)), 0.5, 2.0)
	character.makeup_offset = _vector3_from_array(data.get("makeup_offset", [0.0, 0.0, 0.0]))
	character.jewelry_style = clampi(int(data.get("jewelry_style", 0)), 0, ModularCharacterBase.JewelryStyle.size() - 1) as ModularCharacterBase.JewelryStyle
	character.jewelry_color = Color.from_string(str(data.get("jewelry_color", "e8c84dff")), Color("e8c84d"))
	character.jewelry_scale = clampf(float(data.get("jewelry_scale", 1.0)), 0.5, 2.0)
	character.jewelry_offset = _vector3_from_array(data.get("jewelry_offset", [0.0, 0.0, 0.0]))
	if int(data.get("format_version", 1)) < 3:
		var legacy_clothing := clampi(int(data.get("clothing_style", 0)), 0, 5)
		if int(data.get("format_version", 1)) < 2 and legacy_clothing > 0:
			legacy_clothing += 3
		character.top_style = ModularCharacterBase.TopStyle.T_SHIRT if legacy_clothing == 1 or legacy_clothing == 3 else ModularCharacterBase.TopStyle.NONE
		character.bottom_style = ModularCharacterBase.BottomStyle.PANTS if legacy_clothing == 2 or legacy_clothing == 3 else ModularCharacterBase.BottomStyle.NONE
		character.top_color = Color.from_string(str(data.get("clothing_color", "3f6a45ff")), Color("3f6a45"))
		character.bottom_color = Color.from_string(str(data.get("pants_color", "334e68ff")), Color("334e68"))
	else:
		character.top_style = clampi(int(data.get("top_style", 0)), 0, ModularCharacterBase.TopStyle.size() - 1) as ModularCharacterBase.TopStyle
		character.bottom_style = clampi(int(data.get("bottom_style", 0)), 0, ModularCharacterBase.BottomStyle.size() - 1) as ModularCharacterBase.BottomStyle
		character.top_color = Color.from_string(str(data.get("top_color", "3f6a45ff")), Color("3f6a45"))
		character.bottom_color = Color.from_string(str(data.get("bottom_color", "334e68ff")), Color("334e68"))
	## Upgrade older naked defaults while preserving every selected garment.
	if character.top_style == ModularCharacterBase.TopStyle.NONE:
		character.top_style = ModularCharacterBase.TopStyle.T_SHIRT
	if character.bottom_style == ModularCharacterBase.BottomStyle.NONE:
		character.bottom_style = ModularCharacterBase.BottomStyle.SHORTS
	character.top_scale = clampf(float(data.get("top_scale", 1.0)), 0.9, 1.12)
	character.shirt_graphic = clampi(int(data.get("shirt_graphic", 0)), 0, ModularCharacterBase.ShirtGraphic.size() - 1) as ModularCharacterBase.ShirtGraphic
	character.shirt_graphic_color = Color.from_string(str(data.get("shirt_graphic_color", "ffffffff")), Color.WHITE)
	character.shirt_graphic_scale = clampf(float(data.get("shirt_graphic_scale", 1.0)), 0.4, 2.0)
	character.shirt_graphic_horizontal = clampf(float(data.get("shirt_graphic_horizontal", 0.0)), -0.18, 0.18)
	character.shirt_graphic_vertical = clampf(float(data.get("shirt_graphic_vertical", 0.0)), -0.40, 0.80)
	character.shirt_graphic_depth = clampf(float(data.get("shirt_graphic_depth", 0.0)), -0.40, 0.30)
	character.bottom_scale = clampf(float(data.get("bottom_scale", 1.0)), 0.9, 1.12)
	character.shoe_style = clampi(int(data.get("shoe_style", 0)), 0, 5) as ModularCharacterBase.ShoeStyle
	character.shoe_color = Color.from_string(str(data.get("shoe_color", "6b3f2aff")), Color("6b3f2a"))
	character.shoe_scale = clampf(float(data.get("shoe_scale", 1.03)), 0.9, 1.2)
	character.end_appearance_batch()
	character.load_pose_controls(data.get("pose_controls", {}))
	if int(data.get("format_version", 1)) >= 7:
		character.load_control_rig_targets(data.get("control_rig_targets", {}))
	animation_button.text = "Play animation"
	_refresh_appearance_controls()
	_set_status("Loaded %s" % character_name.text)


func _setup_module_controls() -> void:
	eyes_select.add_item("Two flattened spheres")
	eyes_select.disabled = true
	for label in ["Almond", "Almond + lash rim", "Classic (old eyes)", "No eyelids"]:
		lash_select.add_item(label)
	for label in ["None", "Rosy radial gradient"]:
		cheek_select.add_item(label)
	for label in ["None", "Straight", "Arched", "Angry", "Worried / shocked"]:
		eyebrow_select.add_item(label)
	for label in ["None", "Button", "Point"]:
		nose_select.add_item(label)
	for label in ["Half circle", "Flat", "Open"]:
		mouth_select.add_item(label)
	for label in ["None", "Simple parted", "Buzzed", "Long", "Twin buns", "Low-poly swept", "Low-poly short bob", "Low-poly ponytail", "Low-poly cropped", "Cap with hair", "Capsule long", "Capsule spiky"]:
		hair_select.add_item(label)
	for label in ["None", "Full beard", "Moustache", "Short beard", "Quaternius beard"]:
		facial_hair_select.add_item(label)
	for label in ["None", "Ranger hood", "Round hood", "Top hat", "Baseball cap", "Low-poly cap", "Cap with hair", "Low-poly round hat", "Capsule cap"]:
		hat_select.add_item(label)
	for label in ["None", "Sport shades", "Classic frames", "Cat-eye", "Round shades", "Shutter shades", "Aviator", "Pixel shades", "Retro round", "Slim frames", "Wayfarer"]:
		glasses_select.add_item(label)
	for label in ["None", "Eye shadow", "Winged liner", "Beauty mark", "Full glam"]:
		makeup_select.add_item(label)
	for label in ["None", "Stud earrings", "Hoop earrings", "Drop earrings", "Choker"]:
		jewelry_select.add_item(label)
	for label in ["None", "T-shirt", "Tank top", "Long-sleeve shirt", "Crop top", "Blouse", "Polo", "Hoodie", "Sweater", "Off-shoulder top", "Dress bodice", "Cardigan"]:
		top_select.add_item(label)
	for label in ["None", "Skull", "Heart", "Star", "Lightning", "Flame", "Flower", "Cat", "Moon", "Burger", "Crown"]:
		graphic_select.add_item(label)
	for label in ["None", "Pants", "Shorts", "Capri pants", "Leggings", "Mini skirt", "Long skirt", "Pleated skirt"]:
		bottom_select.add_item(label)
	for label in ["None", "Sneakers", "Ankle boots", "High tops", "Loafers", "Sandals"]:
		shoe_select.add_item(label)
	nose_select.select(character.nose_style)
	nose_color.color = character.nose_color
	mouth_select.select(character.mouth_style)
	mouth_color.color = character.mouth_color
	lash_select.select(character.lash_style)
	lash_color.color = character.lash_color
	cheek_select.select(character.cheek_style)
	cheek_color.color = character.cheek_color
	ear_color.color = character.ear_color
	hair_select.select(character.hair_style)
	facial_hair_select.select(character.facial_hair_style)
	hat_select.select(character.hat_style)
	glasses_select.select(character.glasses_style)
	glasses_color.color = character.glasses_color
	makeup_select.select(character.makeup_style)
	makeup_color.color = character.makeup_color
	jewelry_select.select(character.jewelry_style)
	jewelry_color.color = character.jewelry_color
	top_select.select(character.top_style)
	graphic_select.select(character.shirt_graphic)
	bottom_select.select(character.bottom_style)
	shoe_select.select(character.shoe_style)
	eyebrow_select.select(character.brow_style)
	hair_color.color = character.hair_color
	facial_hair_color.color = character.facial_hair_color
	hat_color.color = character.hat_color
	top_color.color = character.top_color
	graphic_color.color = character.shirt_graphic_color
	bottom_color.color = character.bottom_color
	shoe_color.color = character.shoe_color
	eyebrow_color.color = character.brow_color
	_add_adjustment_slider(eye_adjustments, "eye_width", "Width", 0.4, 2.0, 0.05, character.eye_width, func(value: float) -> void: character.eye_width = value)
	_add_adjustment_slider(eye_adjustments, "eye_height", "Height", 0.4, 2.0, 0.05, character.eye_height, func(value: float) -> void: character.eye_height = value)
	_add_adjustment_slider(eye_adjustments, "eye_vertical", "Up / down", -0.12, 0.14, 0.01, character.eye_vertical, func(value: float) -> void: character.eye_vertical = value)
	_add_adjustment_slider(eye_adjustments, "eye_spacing", "Spacing", 0.45, 1.8, 0.05, character.eye_spacing, func(value: float) -> void: character.eye_spacing = value)
	_add_adjustment_slider(eye_adjustments, "eye_depth", "Into / out", -0.35, 0.25, 0.01, character.eye_depth, func(value: float) -> void: character.eye_depth = value)
	_add_adjustment_slider(eye_adjustments, "eye_pupil_size", "Pupil size", 0.12, 0.92, 0.01, character.eye_pupil_size, func(value: float) -> void: character.eye_pupil_size = value)
	_add_adjustment_slider(eye_adjustments, "eye_pupil_inward", "Pupils in / out", -0.55, 0.55, 0.01, character.eye_pupil_inward, func(value: float) -> void: character.eye_pupil_inward = value)
	_add_adjustment_slider(eye_adjustments, "eye_sclera_brightness", "Whites brightness", 0.15, 1.0, 0.01, character.eye_sclera_brightness, func(value: float) -> void: character.eye_sclera_brightness = value)
	_add_adjustment_slider(eye_adjustments, "eyelid_scale", "Lid scale", 0.5, 2.2, 0.01, character.eyelid_scale, func(value: float) -> void: character.eyelid_scale = value)
	_add_adjustment_slider(eye_adjustments, "eyelid_width", "Lid width", 0.4, 2.0, 0.01, character.eyelid_width, func(value: float) -> void: character.eyelid_width = value)
	_add_adjustment_slider(eye_adjustments, "eyelid_height", "Lid height", 0.4, 2.0, 0.01, character.eyelid_height, func(value: float) -> void: character.eyelid_height = value)
	_add_adjustment_slider(eye_adjustments, "eyelid_depth", "Lid depth", 0.4, 2.0, 0.01, character.eyelid_depth, func(value: float) -> void: character.eyelid_depth = value)
	_add_adjustment_slider(eye_adjustments, "eyelid_vertical", "Lid up / down", -0.12, 0.12, 0.005, character.eyelid_vertical, func(value: float) -> void: character.eyelid_vertical = value)
	_add_adjustment_slider(eye_adjustments, "eyelid_forward", "Lid into / out", -0.12, 0.12, 0.005, character.eyelid_forward, func(value: float) -> void: character.eyelid_forward = value)
	_add_adjustment_slider(eye_adjustments, "eyelid_mask_height", "Open height", 0.0, 1.0, 0.01, character.eyelid_mask_height, func(value: float) -> void: character.eyelid_mask_height = value)
	_add_adjustment_slider(eye_adjustments, "eyelid_mask_width", "Open width", 0.0, 1.5, 0.01, character.eyelid_mask_width, func(value: float) -> void: character.eyelid_mask_width = value)
	_add_adjustment_slider(eye_specular_adjustments, "eye_specular_scale", "Size", 0.3, 2.0, 0.05, character.eye_specular_scale, func(value: float) -> void: character.eye_specular_scale = value)
	_add_adjustment_slider(eye_specular_adjustments, "eye_specular_horizontal", "Left / right", -0.08, 0.08, 0.005, character.eye_specular_horizontal, func(value: float) -> void: character.eye_specular_horizontal = value)
	_add_adjustment_slider(eye_specular_adjustments, "eye_specular_vertical", "Up / down", -0.10, 0.10, 0.005, character.eye_specular_vertical, func(value: float) -> void: character.eye_specular_vertical = value)
	_add_adjustment_slider(eye_specular_adjustments, "eye_specular_depth", "Into / out", -0.05, 0.08, 0.005, character.eye_specular_depth, func(value: float) -> void: character.eye_specular_depth = value)
	_add_adjustment_slider(eye_rotation_adjustments, "left_eye_yaw", "Left eye", -0.8, 0.8, 0.01, character.left_eye_yaw, func(value: float) -> void: character.left_eye_yaw = value)
	_add_adjustment_slider(eye_rotation_adjustments, "right_eye_yaw", "Right eye", -0.8, 0.8, 0.01, character.right_eye_yaw, func(value: float) -> void: character.right_eye_yaw = value)
	_add_adjustment_slider(lash_adjustments, "lash_rim_width", "Rim thickness", 0.01, 0.36, 0.005, character.lash_rim_width, func(value: float) -> void: character.lash_rim_width = value)
	_add_adjustment_slider(eyebrow_adjustments, "brow_scale", "Scale", 0.5, 2.0, 0.05, character.brow_scale, func(value: float) -> void: character.brow_scale = value)
	_add_adjustment_slider(eyebrow_adjustments, "brow_width", "Width", 0.5, 2.0, 0.05, character.brow_width, func(value: float) -> void: character.brow_width = value)
	_add_adjustment_slider(eyebrow_adjustments, "brow_height", "Thickness", 0.5, 2.0, 0.05, character.brow_height, func(value: float) -> void: character.brow_height = value)
	_add_adjustment_slider(eyebrow_adjustments, "brow_vertical", "Up / down", -0.12, 0.14, 0.01, character.brow_vertical, func(value: float) -> void: character.brow_vertical = value)
	_add_adjustment_slider(eyebrow_adjustments, "brow_spacing", "Spacing", 0.6, 1.6, 0.05, character.brow_spacing, func(value: float) -> void: character.brow_spacing = value)
	_add_adjustment_slider(eyebrow_adjustments, "brow_depth", "Into / out", -0.10, 0.10, 0.005, character.brow_depth, func(value: float) -> void: character.brow_depth = value)
	_add_adjustment_slider(eyebrow_adjustments, "left_brow_yaw", "Left yaw", -0.8, 0.8, 0.01, character.left_brow_yaw, func(value: float) -> void: character.left_brow_yaw = value)
	_add_adjustment_slider(eyebrow_adjustments, "right_brow_yaw", "Right yaw", -0.8, 0.8, 0.01, character.right_brow_yaw, func(value: float) -> void: character.right_brow_yaw = value)
	_add_adjustment_slider(nose_adjustments, "nose_width", "Width", 0.4, 2.0, 0.05, character.nose_width, func(value: float) -> void: character.nose_width = value)
	_add_adjustment_slider(nose_adjustments, "nose_height", "Height", 0.4, 2.0, 0.05, character.nose_height, func(value: float) -> void: character.nose_height = value)
	_add_adjustment_slider(nose_adjustments, "nose_vertical", "Up / down", -0.18, 0.18, 0.01, character.nose_vertical, func(value: float) -> void: character.nose_vertical = value)
	_add_adjustment_slider(nose_adjustments, "nose_depth", "Into / out", -0.35, 0.25, 0.01, character.nose_depth, func(value: float) -> void: character.nose_depth = value)
	_add_adjustment_slider(mouth_adjustments, "mouth_width", "Width", 0.4, 2.0, 0.05, character.mouth_width, func(value: float) -> void: character.mouth_width = value)
	_add_adjustment_slider(mouth_adjustments, "mouth_height", "Height", 0.4, 2.0, 0.05, character.mouth_height, func(value: float) -> void: character.mouth_height = value)
	_add_adjustment_slider(mouth_adjustments, "mouth_vertical", "Up / down", -0.18, 0.18, 0.01, character.mouth_vertical, func(value: float) -> void: character.mouth_vertical = value)
	_add_adjustment_slider(mouth_adjustments, "mouth_depth", "Into / out", -0.35, 0.25, 0.01, character.mouth_depth, func(value: float) -> void: character.mouth_depth = value)
	_add_adjustment_slider(mouth_adjustments, "mouth_curve", "Face curve", 0.0, 0.45, 0.01, character.mouth_curve, func(value: float) -> void: character.mouth_curve = value)
	_add_adjustment_color(mouth_adjustments, "mouth_shadow_color", "Shadow color", character.mouth_shadow_color, func(color: Color) -> void: character.mouth_shadow_color = color)
	_add_adjustment_slider(mouth_adjustments, "mouth_shadow_size", "Shadow size", 0.0, 1.0, 0.01, character.mouth_shadow_size, func(value: float) -> void: character.mouth_shadow_size = value)
	_add_adjustment_slider(mouth_adjustments, "mouth_shadow_position", "Shadow pos", -0.40, 0.60, 0.01, character.mouth_shadow_position, func(value: float) -> void: character.mouth_shadow_position = value)
	_add_adjustment_slider(mouth_adjustments, "mouth_shadow_softness", "Shadow soft", 0.0, 0.45, 0.01, character.mouth_shadow_softness, func(value: float) -> void: character.mouth_shadow_softness = value)
	_add_adjustment_slider(mouth_adjustments, "mouth_shadow_width", "Shadow width", 0.15, 1.0, 0.01, character.mouth_shadow_width, func(value: float) -> void: character.mouth_shadow_width = value)
	_add_adjustment_slider(cheek_adjustments, "cheek_scale", "Scale", 0.4, 2.0, 0.05, character.cheek_scale, func(value: float) -> void: character.cheek_scale = value)
	_add_adjustment_slider(cheek_adjustments, "cheek_width", "Width", 0.4, 2.0, 0.05, character.cheek_width, func(value: float) -> void: character.cheek_width = value)
	_add_adjustment_slider(cheek_adjustments, "cheek_height", "Height", 0.4, 2.0, 0.05, character.cheek_height, func(value: float) -> void: character.cheek_height = value)
	_add_adjustment_slider(cheek_adjustments, "cheek_vertical", "Up / down", -0.18, 0.18, 0.01, character.cheek_vertical, func(value: float) -> void: character.cheek_vertical = value)
	_add_adjustment_slider(cheek_adjustments, "cheek_spacing", "Spacing", 0.5, 1.8, 0.05, character.cheek_spacing, func(value: float) -> void: character.cheek_spacing = value)
	_add_adjustment_slider(cheek_adjustments, "cheek_depth", "Into / out", -0.50, 0.35, 0.01, character.cheek_depth, func(value: float) -> void: character.cheek_depth = value)
	_add_adjustment_slider(ear_adjustments, "ear_scale", "Scale", 0.4, 2.0, 0.05, character.ear_scale, func(value: float) -> void: character.ear_scale = value)
	_add_adjustment_slider(ear_adjustments, "ear_spacing", "Spacing", 0.6, 1.8, 0.05, character.ear_spacing, func(value: float) -> void: character.ear_spacing = value)
	_add_adjustment_slider(ear_adjustments, "ear_depth", "Into / out", -0.35, 0.25, 0.01, character.ear_depth, func(value: float) -> void: character.ear_depth = value)
	_add_adjustment_slider(hair_adjustments, "hair_scale", "All", 0.3, 3.0, 0.05, character.hair_scale, func(value: float) -> void: character.hair_scale = value)
	_add_adjustment_slider(hair_adjustments, "hair_scale_x", "Scale X", 0.3, 3.0, 0.05, character.hair_scale_xyz.x, func(value: float) -> void: _set_hair_scale_xyz_component(0, value))
	_add_adjustment_slider(hair_adjustments, "hair_scale_y", "Scale Y", 0.3, 3.0, 0.05, character.hair_scale_xyz.y, func(value: float) -> void: _set_hair_scale_xyz_component(1, value))
	_add_adjustment_slider(hair_adjustments, "hair_scale_z", "Scale Z", 0.3, 3.0, 0.05, character.hair_scale_xyz.z, func(value: float) -> void: _set_hair_scale_xyz_component(2, value))
	_add_adjustment_slider(hair_adjustments, "hair_x", "Pos X", -1.2, 1.2, 0.01, character.hair_offset.x, func(value: float) -> void: _set_hair_offset_component(0, value))
	_add_adjustment_slider(hair_adjustments, "hair_y", "Pos Y", -1.5, 1.8, 0.01, character.hair_offset.y, func(value: float) -> void: _set_hair_offset_component(1, value))
	_add_adjustment_slider(hair_adjustments, "hair_z", "Pos Z", -1.5, 1.5, 0.01, character.hair_offset.z, func(value: float) -> void: _set_hair_offset_component(2, value))
	_add_adjustment_slider(facial_hair_adjustments, "facial_hair_scale", "All", 0.3, 3.0, 0.05, character.facial_hair_scale, func(value: float) -> void: character.facial_hair_scale = value)
	_add_adjustment_slider(facial_hair_adjustments, "facial_hair_scale_x", "Scale X", 0.3, 3.0, 0.05, character.facial_hair_scale_xyz.x, func(value: float) -> void: _set_facial_hair_scale_xyz_component(0, value))
	_add_adjustment_slider(facial_hair_adjustments, "facial_hair_scale_y", "Scale Y", 0.3, 3.0, 0.05, character.facial_hair_scale_xyz.y, func(value: float) -> void: _set_facial_hair_scale_xyz_component(1, value))
	_add_adjustment_slider(facial_hair_adjustments, "facial_hair_scale_z", "Scale Z", 0.3, 3.0, 0.05, character.facial_hair_scale_xyz.z, func(value: float) -> void: _set_facial_hair_scale_xyz_component(2, value))
	_add_adjustment_slider(facial_hair_adjustments, "facial_hair_x", "Pos X", -1.2, 1.2, 0.01, character.facial_hair_offset.x, func(value: float) -> void: _set_facial_hair_offset_component(0, value))
	_add_adjustment_slider(facial_hair_adjustments, "facial_hair_y", "Pos Y", -1.5, 1.8, 0.01, character.facial_hair_offset.y, func(value: float) -> void: _set_facial_hair_offset_component(1, value))
	_add_adjustment_slider(facial_hair_adjustments, "facial_hair_z", "Pos Z", -1.5, 1.5, 0.01, character.facial_hair_offset.z, func(value: float) -> void: _set_facial_hair_offset_component(2, value))
	_add_adjustment_slider(hat_adjustments, "hat_scale", "Scale", 0.5, 2.0, 0.05, character.hat_scale, func(value: float) -> void: character.hat_scale = value)
	_add_adjustment_slider(hat_adjustments, "hat_x", "Left / right", -0.5, 0.5, 0.01, character.hat_offset.x, func(value: float) -> void: _set_hat_offset_component(0, value))
	_add_adjustment_slider(hat_adjustments, "hat_y", "Up / down", -0.5, 0.5, 0.01, character.hat_offset.y, func(value: float) -> void: _set_hat_offset_component(1, value))
	_add_adjustment_slider(hat_adjustments, "hat_z", "Into / out", -0.8, 0.8, 0.01, character.hat_offset.z, func(value: float) -> void: _set_hat_offset_component(2, value))
	_add_adjustment_slider(hat_adjustments, "hat_pitch", "Pitch", -180.0, 180.0, 1.0, character.hat_rotation.x, func(value: float) -> void: _set_hat_rotation_component(0, value))
	_add_adjustment_slider(hat_adjustments, "hat_yaw", "Yaw", -180.0, 180.0, 1.0, character.hat_rotation.y, func(value: float) -> void: _set_hat_rotation_component(1, value))
	_add_adjustment_slider(hat_adjustments, "hat_roll", "Roll", -180.0, 180.0, 1.0, character.hat_rotation.z, func(value: float) -> void: _set_hat_rotation_component(2, value))
	_add_adjustment_slider(glasses_adjustments, "glasses_scale", "Scale", 0.5, 2.0, 0.05, character.glasses_scale, func(value: float) -> void: character.glasses_scale = value)
	_add_adjustment_slider(glasses_adjustments, "glasses_x", "Left / right", -0.5, 0.5, 0.01, character.glasses_offset.x, func(value: float) -> void: _set_glasses_offset_component(0, value))
	_add_adjustment_slider(glasses_adjustments, "glasses_y", "Up / down", -0.5, 0.7, 0.01, character.glasses_offset.y, func(value: float) -> void: _set_glasses_offset_component(1, value))
	_add_adjustment_slider(glasses_adjustments, "glasses_z", "Into / out", -0.6, 0.8, 0.01, character.glasses_offset.z, func(value: float) -> void: _set_glasses_offset_component(2, value))
	_add_adjustment_slider(makeup_adjustments, "makeup_scale", "Scale", 0.5, 2.0, 0.05, character.makeup_scale, func(value: float) -> void: character.makeup_scale = value)
	_add_adjustment_slider(makeup_adjustments, "makeup_x", "Left / right", -0.4, 0.4, 0.01, character.makeup_offset.x, func(value: float) -> void: _set_makeup_offset_component(0, value))
	_add_adjustment_slider(makeup_adjustments, "makeup_y", "Up / down", -0.4, 0.4, 0.01, character.makeup_offset.y, func(value: float) -> void: _set_makeup_offset_component(1, value))
	_add_adjustment_slider(makeup_adjustments, "makeup_z", "Into / out", -0.6, 0.4, 0.01, character.makeup_offset.z, func(value: float) -> void: _set_makeup_offset_component(2, value))
	_add_adjustment_slider(jewelry_adjustments, "jewelry_scale", "Scale", 0.5, 2.0, 0.05, character.jewelry_scale, func(value: float) -> void: character.jewelry_scale = value)
	_add_adjustment_slider(jewelry_adjustments, "jewelry_x", "Left / right", -0.5, 0.5, 0.01, character.jewelry_offset.x, func(value: float) -> void: _set_jewelry_offset_component(0, value))
	_add_adjustment_slider(jewelry_adjustments, "jewelry_y", "Up / down", -0.5, 0.5, 0.01, character.jewelry_offset.y, func(value: float) -> void: _set_jewelry_offset_component(1, value))
	_add_adjustment_slider(jewelry_adjustments, "jewelry_z", "Into / out", -0.5, 0.5, 0.01, character.jewelry_offset.z, func(value: float) -> void: _set_jewelry_offset_component(2, value))
	_add_adjustment_slider(top_adjustments, "top_scale", "Fit", 0.9, 1.12, 0.01, character.top_scale, func(value: float) -> void: character.top_scale = value)
	_add_adjustment_slider(graphic_adjustments, "shirt_graphic_scale", "Scale", 0.4, 2.0, 0.05, character.shirt_graphic_scale, func(value: float) -> void: character.shirt_graphic_scale = value)
	_add_adjustment_slider(graphic_adjustments, "shirt_graphic_horizontal", "Left / right", -0.18, 0.18, 0.01, character.shirt_graphic_horizontal, func(value: float) -> void: character.shirt_graphic_horizontal = value)
	_add_adjustment_slider(graphic_adjustments, "shirt_graphic_vertical", "Up / down", -0.40, 0.80, 0.01, character.shirt_graphic_vertical, func(value: float) -> void: character.shirt_graphic_vertical = value)
	_add_adjustment_slider(graphic_adjustments, "shirt_graphic_depth", "Into / out", -0.40, 0.30, 0.005, character.shirt_graphic_depth, func(value: float) -> void: character.shirt_graphic_depth = value)
	_add_adjustment_slider(bottom_adjustments, "bottom_scale", "Fit", 0.9, 1.12, 0.01, character.bottom_scale, func(value: float) -> void: character.bottom_scale = value)
	_add_adjustment_slider(shoe_adjustments, "shoe_scale", "Fit", 0.9, 1.2, 0.01, character.shoe_scale, func(value: float) -> void: character.shoe_scale = value)
	nose_select.item_selected.connect(func(index: int) -> void: character.nose_style = index as ModularCharacterBase.NoseStyle)
	nose_color.color_changed.connect(func(color: Color) -> void: character.nose_color = color)
	mouth_select.item_selected.connect(func(index: int) -> void: character.mouth_style = index as ModularCharacterBase.MouthStyle)
	mouth_color.color_changed.connect(func(color: Color) -> void: character.mouth_color = color)
	lash_select.item_selected.connect(func(index: int) -> void: character.lash_style = index as ModularCharacterBase.LashStyle)
	lash_color.color_changed.connect(func(color: Color) -> void: character.lash_color = color)
	cheek_select.item_selected.connect(func(index: int) -> void: character.cheek_style = index as ModularCharacterBase.CheekStyle)
	cheek_color.color_changed.connect(func(color: Color) -> void: character.cheek_color = color)
	eyebrow_select.item_selected.connect(func(index: int) -> void: character.brow_style = index as ModularCharacterBase.BrowStyle)
	eyebrow_color.color_changed.connect(func(color: Color) -> void: character.brow_color = color)
	ear_color.color_changed.connect(func(color: Color) -> void: character.ear_color = color)
	hair_select.item_selected.connect(func(index: int) -> void: character.hair_style = index as ModularCharacterBase.HairStyle)
	facial_hair_select.item_selected.connect(func(index: int) -> void: character.facial_hair_style = index as ModularCharacterBase.FacialHairStyle)
	facial_hair_color.color_changed.connect(func(color: Color) -> void: character.facial_hair_color = color)
	hat_select.item_selected.connect(func(index: int) -> void: character.hat_style = index as ModularCharacterBase.HatStyle)
	glasses_select.item_selected.connect(func(index: int) -> void: character.glasses_style = index as ModularCharacterBase.GlassesStyle)
	glasses_color.color_changed.connect(func(color: Color) -> void: character.glasses_color = color)
	makeup_select.item_selected.connect(func(index: int) -> void: character.makeup_style = index as ModularCharacterBase.MakeupStyle)
	makeup_color.color_changed.connect(func(color: Color) -> void: character.makeup_color = color)
	jewelry_select.item_selected.connect(func(index: int) -> void: character.jewelry_style = index as ModularCharacterBase.JewelryStyle)
	jewelry_color.color_changed.connect(func(color: Color) -> void: character.jewelry_color = color)
	top_select.item_selected.connect(func(index: int) -> void: character.top_style = index as ModularCharacterBase.TopStyle)
	graphic_select.item_selected.connect(func(index: int) -> void: character.shirt_graphic = index as ModularCharacterBase.ShirtGraphic)
	graphic_color.color_changed.connect(func(color: Color) -> void: character.shirt_graphic_color = color)
	bottom_select.item_selected.connect(func(index: int) -> void: character.bottom_style = index as ModularCharacterBase.BottomStyle)
	shoe_select.item_selected.connect(func(index: int) -> void: character.shoe_style = index as ModularCharacterBase.ShoeStyle)
	hair_color.color_changed.connect(func(color: Color) -> void: character.hair_color = color)
	hat_color.color_changed.connect(func(color: Color) -> void: character.hat_color = color)
	top_color.color_changed.connect(func(color: Color) -> void: character.top_color = color)
	bottom_color.color_changed.connect(func(color: Color) -> void: character.bottom_color = color)
	shoe_color.color_changed.connect(func(color: Color) -> void: character.shoe_color = color)


func _setup_pose_rig_controls() -> void:
	_add_adjustment_slider(pose_adjustments, "pose_head_nod", "Head nod", -35.0, 35.0, 1.0, character.get_pose_control("head_nod"), func(value: float) -> void: _on_pose_control_changed("head_nod", value))
	_add_adjustment_slider(pose_adjustments, "pose_head_yaw", "Head yaw", -50.0, 50.0, 1.0, character.get_pose_control("head_yaw"), func(value: float) -> void: _on_pose_control_changed("head_yaw", value))
	_add_adjustment_slider(pose_adjustments, "pose_head_tilt", "Head tilt", -35.0, 35.0, 1.0, character.get_pose_control("head_tilt"), func(value: float) -> void: _on_pose_control_changed("head_tilt", value))
	_add_adjustment_slider(pose_adjustments, "pose_spine_lean", "Spine lean", -30.0, 30.0, 1.0, character.get_pose_control("spine_lean"), func(value: float) -> void: _on_pose_control_changed("spine_lean", value))
	_add_adjustment_slider(pose_adjustments, "pose_spine_twist", "Spine twist", -35.0, 35.0, 1.0, character.get_pose_control("spine_twist"), func(value: float) -> void: _on_pose_control_changed("spine_twist", value))
	_add_adjustment_slider(pose_adjustments, "pose_left_arm_raise", "L arm raise", -110.0, 110.0, 1.0, character.get_pose_control("left_arm_raise"), func(value: float) -> void: _on_pose_control_changed("left_arm_raise", value))
	_add_adjustment_slider(pose_adjustments, "pose_right_arm_raise", "R arm raise", -110.0, 110.0, 1.0, character.get_pose_control("right_arm_raise"), func(value: float) -> void: _on_pose_control_changed("right_arm_raise", value))
	_add_adjustment_slider(pose_adjustments, "pose_left_arm_forward", "L arm front", -85.0, 85.0, 1.0, character.get_pose_control("left_arm_forward"), func(value: float) -> void: _on_pose_control_changed("left_arm_forward", value))
	_add_adjustment_slider(pose_adjustments, "pose_right_arm_forward", "R arm front", -85.0, 85.0, 1.0, character.get_pose_control("right_arm_forward"), func(value: float) -> void: _on_pose_control_changed("right_arm_forward", value))
	_add_adjustment_slider(pose_adjustments, "pose_left_elbow_bend", "L elbow", 0.0, 130.0, 1.0, character.get_pose_control("left_elbow_bend"), func(value: float) -> void: _on_pose_control_changed("left_elbow_bend", value))
	_add_adjustment_slider(pose_adjustments, "pose_right_elbow_bend", "R elbow", 0.0, 130.0, 1.0, character.get_pose_control("right_elbow_bend"), func(value: float) -> void: _on_pose_control_changed("right_elbow_bend", value))
	_add_adjustment_slider(pose_adjustments, "pose_left_leg_forward", "L leg front", -60.0, 60.0, 1.0, character.get_pose_control("left_leg_forward"), func(value: float) -> void: _on_pose_control_changed("left_leg_forward", value))
	_add_adjustment_slider(pose_adjustments, "pose_right_leg_forward", "R leg front", -60.0, 60.0, 1.0, character.get_pose_control("right_leg_forward"), func(value: float) -> void: _on_pose_control_changed("right_leg_forward", value))
	_add_adjustment_slider(pose_adjustments, "pose_left_knee_bend", "L knee", 0.0, 100.0, 1.0, character.get_pose_control("left_knee_bend"), func(value: float) -> void: _on_pose_control_changed("left_knee_bend", value))
	_add_adjustment_slider(pose_adjustments, "pose_right_knee_bend", "R knee", 0.0, 100.0, 1.0, character.get_pose_control("right_knee_bend"), func(value: float) -> void: _on_pose_control_changed("right_knee_bend", value))


func _process(delta: float) -> void:
	_feature_pulse += delta * 2.4
	_update_feature_hotspot_positions()
	if _paint_hud != null:
		_paint_hud.queue_redraw()
	if _flat_paint_canvas != null and _flat_paint_mode:
		_flat_paint_canvas.queue_redraw()


func _style_randomize_button(button: Button) -> void:
	button.text = "RANDOMIZE CHARACTER"
	button.custom_minimum_size = Vector2(0.0, 52.0)
	button.tooltip_text = "Random face, hair, clothes, and colors. Keeps a half-circle mouth, button nose, and pupil eyes."
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.86, 0.42, 0.12, 1.0)
	normal.set_corner_radius_all(10)
	normal.set_border_width_all(2)
	normal.border_color = Color(1.0, 0.84, 0.32, 1.0)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.96, 0.52, 0.16, 1.0)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.72, 0.32, 0.08, 1.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color(1.0, 0.97, 0.88, 1.0))
	button.add_theme_font_size_override("font_size", 18)


func _feature_specs() -> Array:
	return [
		{"id": "hair", "label": "Hair", "icon": "H", "node": "HairLabel", "color": Color(0.98, 0.78, 0.28, 1.0), "offset": Vector2(16.0, -28.0)},
		{"id": "eyes", "label": "Eyes", "icon": "E", "node": "EyesLabel", "color": Color(0.42, 0.78, 1.0, 1.0), "offset": Vector2(36.0, -6.0)},
		{"id": "mouth", "label": "Mouth", "icon": "M", "node": "MouthLabel", "color": Color(1.0, 0.45, 0.52, 1.0), "offset": Vector2(32.0, 14.0)},
		{"id": "shirt", "label": "Shirt", "icon": "T", "node": "TopLabel", "color": Color(0.45, 0.88, 0.52, 1.0), "offset": Vector2(42.0, 0.0)},
		{"id": "pants", "label": "Pants", "icon": "P", "node": "BottomLabel", "color": Color(0.62, 0.55, 1.0, 1.0), "offset": Vector2(40.0, 4.0)},
		{"id": "shoes", "label": "Shoes", "icon": "S", "node": "ShoeLabel", "color": Color(0.95, 0.62, 0.28, 1.0), "offset": Vector2(34.0, 10.0)},
	]


func _setup_feature_hotspots() -> void:
	var layer := Control.new()
	layer.name = "FeatureHotspots"
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(layer)
	for spec in _feature_specs():
		var wrap := VBoxContainer.new()
		wrap.name = str(spec.id).capitalize() + "Hotspot"
		wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.custom_minimum_size = Vector2(44.0, 52.0)
		wrap.add_theme_constant_override("separation", 0)
		var button := Button.new()
		button.text = str(spec.icon)
		button.tooltip_text = "Jump to %s settings" % spec.label
		button.custom_minimum_size = Vector2(34.0, 34.0)
		button.size = Vector2(34.0, 34.0)
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_font_size_override("font_size", 15)
		var color: Color = spec.color
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(color.r, color.g, color.b, 0.92)
		normal.set_corner_radius_all(17)
		normal.set_border_width_all(2)
		normal.border_color = Color(1.0, 1.0, 1.0, 0.88)
		var hover := normal.duplicate() as StyleBoxFlat
		hover.bg_color = color.lightened(0.18)
		button.add_theme_stylebox_override("normal", normal)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", hover)
		button.add_theme_color_override("font_color", Color(0.08, 0.08, 0.1, 1.0))
		button.pressed.connect(_scroll_to_feature.bind(str(spec.id)))
		var caption := Label.new()
		caption.text = str(spec.label)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_font_size_override("font_size", 11)
		caption.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.92))
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(button)
		wrap.add_child(caption)
		layer.add_child(wrap)
		_feature_hotspots[str(spec.id)] = wrap
	_update_feature_hotspot_positions()


func _update_feature_hotspot_positions() -> void:
	if camera == null or character == null:
		return
	if _fit_room_open or _paint_mode:
		for spec in _feature_specs():
			var hotspot := _feature_hotspots.get(str(spec.id)) as Control
			if hotspot != null:
				hotspot.visible = false
		return
	var pulse := 1.0 + sin(_feature_pulse) * 0.06
	for spec in _feature_specs():
		var button := _feature_hotspots.get(str(spec.id)) as Control
		if button == null:
			continue
		var world := character.feature_world_position(str(spec.id))
		if camera.is_position_behind(world):
			button.visible = false
			continue
		button.visible = true
		var screen := camera.unproject_position(world)
		button.scale = Vector2.ONE * pulse
		var marker_offset: Vector2 = spec.get("offset", Vector2(22.0, -16.0))
		button.position = screen + marker_offset - button.size * 0.5


func _scroll_to_feature(feature_id: String) -> void:
	var node_name := ""
	var label := feature_id.capitalize()
	for spec in _feature_specs():
		if str(spec.id) == feature_id:
			node_name = str(spec.node)
			label = str(spec.label)
			break
	if node_name.is_empty() or _module_scroll == null:
		return
	var target := module_controls.get_node_or_null(node_name) as Control
	if target == null:
		return
	_module_scroll.ensure_control_visible(target)
	_set_status("Editing %s. Click another marker on the character to jump again." % label)


func _try_select_character_feature(screen_position: Vector2) -> bool:
	var closest_id := ""
	var closest_distance := 78.0
	for spec in _feature_specs():
		var world := character.feature_world_position(str(spec.id))
		if camera.is_position_behind(world):
			continue
		var distance := camera.unproject_position(world).distance_to(screen_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_id = str(spec.id)
	if closest_id.is_empty():
		return false
	_scroll_to_feature(closest_id)
	return true


func _make_module_panel_scrollable() -> void:
	module_margin.remove_child(module_controls)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	module_margin.add_child(scroll)
	scroll.add_child(module_controls)
	module_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_module_scroll = scroll


func _make_sidebar_scrollable() -> void:
	sidebar_margin.remove_child(sidebar_controls)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar_margin.add_child(scroll)
	scroll.add_child(sidebar_controls)
	sidebar_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _capture_customer_thumbnail(safe_name: String) -> void:
	await RenderingServer.frame_post_draw
	var full_image := get_viewport().get_texture().get_image()
	if full_image == null or full_image.is_empty():
		return
	var left_edge := mini(330, full_image.get_width() - 1)
	var right_edge := maxi(left_edge + 1, full_image.get_width() - 290)
	var preview := full_image.get_region(Rect2i(left_edge, 0, right_edge - left_edge, full_image.get_height()))
	preview.resize(84, 112, Image.INTERPOLATE_LANCZOS)
	preview.save_png(ProjectSettings.globalize_path("user://characters/%s_thumb.png" % safe_name))
	_refresh_saved_customers()


func _refresh_saved_customers() -> void:
	for child in saved_customers.get_children():
		child.free()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://characters"))
	var files := DirAccess.get_files_at("user://characters")
	files.sort()
	for file_name in files:
		if not file_name.ends_with(".json"):
			continue
		var preset_path := "user://characters/%s" % file_name
		var display_name := file_name.get_basename().replace("_", " ").capitalize()
		var file := FileAccess.open(preset_path, FileAccess.READ)
		if file != null:
			var data: Variant = JSON.parse_string(file.get_as_text())
			if data is Dictionary:
				display_name = str(data.get("name", display_name))
		var card := Button.new()
		card.custom_minimum_size = Vector2(0.0, 96.0)
		card.text = display_name
		card.tooltip_text = "Load %s" % display_name
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.expand_icon = true
		card.add_theme_constant_override("icon_max_width", 68)
		var thumb_path := "user://characters/%s_thumb.png" % file_name.get_basename()
		if FileAccess.file_exists(thumb_path):
			var image := Image.new()
			if image.load(ProjectSettings.globalize_path(thumb_path)) == OK:
				card.icon = ImageTexture.create_from_image(image)
		card.pressed.connect(_load_character_file.bind(preset_path))
		saved_customers.add_child(card)


func _add_adjustment_slider(parent: VBoxContainer, key: String, label_text: String, minimum: float, maximum: float, step: float, current: float, callback: Callable) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.custom_minimum_size.x = 82.0
	label.text = label_text
	var slider := HSlider.new()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = current
	slider.tooltip_text = "%s: %.2f" % [label_text, current]
	slider.value_changed.connect(func(value: float) -> void:
		slider.tooltip_text = "%s: %.2f" % [label_text, value]
		callback.call(value)
	)
	row.add_child(label)
	row.add_child(slider)
	parent.add_child(row)
	_adjustment_sliders[key] = slider


func _add_adjustment_toggle(parent: VBoxContainer, key: String, label_text: String, current: bool, callback: Callable) -> void:
	var box := CheckBox.new()
	box.text = label_text
	box.button_pressed = current
	box.toggled.connect(callback)
	parent.add_child(box)
	_adjustment_toggles[key] = box


func _add_adjustment_color(parent: VBoxContainer, key: String, label_text: String, current: Color, callback: Callable) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.custom_minimum_size.x = 82.0
	label.text = label_text
	var picker := ColorPickerButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.custom_minimum_size = Vector2(0, 28)
	picker.edit_alpha = true
	picker.color = current
	picker.text = label_text
	picker.color_changed.connect(callback)
	row.add_child(label)
	row.add_child(picker)
	parent.add_child(row)
	_adjustment_colors[key] = picker


func _sync_adjustment_controls() -> void:
	var values := {
		"eye_width": character.eye_width, "eye_height": character.eye_height, "eye_vertical": character.eye_vertical, "eye_spacing": character.eye_spacing, "eye_depth": character.eye_depth, "eye_pupil_size": character.eye_pupil_size, "eye_pupil_inward": character.eye_pupil_inward, "eye_sclera_brightness": character.eye_sclera_brightness,
		"eye_specular_scale": character.eye_specular_scale, "eye_specular_horizontal": character.eye_specular_horizontal, "eye_specular_vertical": character.eye_specular_vertical, "eye_specular_depth": character.eye_specular_depth,
		"left_eye_yaw": character.left_eye_yaw, "right_eye_yaw": character.right_eye_yaw,
		"eyelid_scale": character.eyelid_scale, "eyelid_width": character.eyelid_width, "eyelid_height": character.eyelid_height, "eyelid_depth": character.eyelid_depth, "eyelid_vertical": character.eyelid_vertical, "eyelid_forward": character.eyelid_forward, "eyelid_mask_height": character.eyelid_mask_height, "eyelid_mask_width": character.eyelid_mask_width,
		"lash_rim_width": character.lash_rim_width,
		"brow_scale": character.brow_scale, "brow_width": character.brow_width, "brow_height": character.brow_height, "brow_vertical": character.brow_vertical,
		"brow_spacing": character.brow_spacing, "brow_depth": character.brow_depth, "left_brow_yaw": character.left_brow_yaw, "right_brow_yaw": character.right_brow_yaw,
		"nose_width": character.nose_width, "nose_height": character.nose_height, "nose_vertical": character.nose_vertical, "nose_depth": character.nose_depth,
		"mouth_width": character.mouth_width, "mouth_height": character.mouth_height, "mouth_vertical": character.mouth_vertical, "mouth_depth": character.mouth_depth,
		"mouth_curve": character.mouth_curve, "mouth_shadow_size": character.mouth_shadow_size, "mouth_shadow_position": character.mouth_shadow_position, "mouth_shadow_softness": character.mouth_shadow_softness, "mouth_shadow_width": character.mouth_shadow_width,
		"cheek_scale": character.cheek_scale, "cheek_width": character.cheek_width, "cheek_height": character.cheek_height, "cheek_vertical": character.cheek_vertical, "cheek_spacing": character.cheek_spacing, "cheek_depth": character.cheek_depth,
		"ear_scale": character.ear_scale, "ear_spacing": character.ear_spacing, "ear_depth": character.ear_depth,
		"hair_scale": character.hair_scale, "hair_scale_x": character.hair_scale_xyz.x, "hair_scale_y": character.hair_scale_xyz.y, "hair_scale_z": character.hair_scale_xyz.z, "hair_x": character.hair_offset.x, "hair_y": character.hair_offset.y, "hair_z": character.hair_offset.z,
		"facial_hair_scale": character.facial_hair_scale, "facial_hair_scale_x": character.facial_hair_scale_xyz.x, "facial_hair_scale_y": character.facial_hair_scale_xyz.y, "facial_hair_scale_z": character.facial_hair_scale_xyz.z, "facial_hair_x": character.facial_hair_offset.x, "facial_hair_y": character.facial_hair_offset.y, "facial_hair_z": character.facial_hair_offset.z,
		"hat_scale": character.hat_scale, "hat_x": character.hat_offset.x, "hat_y": character.hat_offset.y, "hat_z": character.hat_offset.z, "hat_pitch": character.hat_rotation.x, "hat_yaw": character.hat_rotation.y, "hat_roll": character.hat_rotation.z,
		"glasses_scale": character.glasses_scale, "glasses_x": character.glasses_offset.x, "glasses_y": character.glasses_offset.y, "glasses_z": character.glasses_offset.z,
		"makeup_scale": character.makeup_scale, "makeup_x": character.makeup_offset.x, "makeup_y": character.makeup_offset.y, "makeup_z": character.makeup_offset.z,
		"jewelry_scale": character.jewelry_scale, "jewelry_x": character.jewelry_offset.x, "jewelry_y": character.jewelry_offset.y, "jewelry_z": character.jewelry_offset.z,
		"top_scale": character.top_scale, "shirt_graphic_scale": character.shirt_graphic_scale, "shirt_graphic_horizontal": character.shirt_graphic_horizontal, "shirt_graphic_vertical": character.shirt_graphic_vertical, "shirt_graphic_depth": character.shirt_graphic_depth,
		"bottom_scale": character.bottom_scale, "shoe_scale": character.shoe_scale,
	}
	for pose_key in character.get_pose_controls():
		values["pose_%s" % pose_key] = character.get_pose_control(pose_key)
	for key in values:
		if _adjustment_sliders.has(key):
			_adjustment_sliders[key].set_value_no_signal(values[key])
	if _adjustment_colors.has("mouth_shadow_color"):
		_adjustment_colors["mouth_shadow_color"].color = character.mouth_shadow_color
	if _adjustment_toggles.has("eyelid_enabled"):
		_adjustment_toggles["eyelid_enabled"].set_pressed_no_signal(character.eyelid_enabled)


func _set_hair_scale_xyz_component(axis: int, value: float) -> void:
	var scale_xyz := character.hair_scale_xyz
	scale_xyz[axis] = value
	character.hair_scale_xyz = scale_xyz


func _set_facial_hair_scale_xyz_component(axis: int, value: float) -> void:
	var scale_xyz := character.facial_hair_scale_xyz
	scale_xyz[axis] = value
	character.facial_hair_scale_xyz = scale_xyz


func _set_hair_offset_component(axis: int, value: float) -> void:
	var offset := character.hair_offset
	offset[axis] = value
	character.hair_offset = offset


func _set_facial_hair_offset_component(axis: int, value: float) -> void:
	var offset := character.facial_hair_offset
	offset[axis] = value
	character.facial_hair_offset = offset


func _set_hat_offset_component(axis: int, value: float) -> void:
	var offset := character.hat_offset
	offset[axis] = value
	character.hat_offset = offset


func _set_hat_rotation_component(axis: int, value: float) -> void:
	var rotation := character.hat_rotation
	rotation[axis] = value
	character.hat_rotation = rotation


func _set_glasses_offset_component(axis: int, value: float) -> void:
	var offset := character.glasses_offset
	offset[axis] = value
	character.glasses_offset = offset


func _set_makeup_offset_component(axis: int, value: float) -> void:
	var offset := character.makeup_offset
	offset[axis] = value
	character.makeup_offset = offset


func _set_jewelry_offset_component(axis: int, value: float) -> void:
	var offset := character.jewelry_offset
	offset[axis] = value
	character.jewelry_offset = offset


func _vector3_from_array(value: Variant) -> Vector3:
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO


func _clamped_scale_xyz(value: Variant) -> Vector3:
	var scale_xyz := _vector3_from_array(value)
	if not (value is Array) or (value as Array).size() < 3:
		scale_xyz = Vector3.ONE
	return Vector3(clampf(scale_xyz.x, 0.3, 3.0), clampf(scale_xyz.y, 0.3, 3.0), clampf(scale_xyz.z, 0.3, 3.0))


func _write_text(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	return true


func _safe_file_name(value: String) -> String:
	var result := ""
	for i in value.length():
		var character_code := value.unicode_at(i)
		var keep := (
			character_code >= 48 and character_code <= 57
			or character_code >= 65 and character_code <= 90
			or character_code >= 97 and character_code <= 122
			or character_code == 45
			or character_code == 95
		)
		if keep:
			result += value.substr(i, 1).to_lower()
		elif character_code == 32 and not result.ends_with("_"):
			result += "_"
	return result if not result.is_empty() else "character"


func _load_accessory_fits() -> void:
	_accessory_fits = {"hairs": {}, "hats": {}, "blocked_hairs": [], "blocked_hats": []}
	if not FileAccess.file_exists(ACCESSORY_FITS_PATH):
		return
	var file := FileAccess.open(ACCESSORY_FITS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		var data := parsed as Dictionary
		_accessory_fits["hairs"] = data.get("hairs", {})
		_accessory_fits["hats"] = data.get("hats", {})
		_accessory_fits["blocked_hairs"] = _normalize_id_list(data.get("blocked_hairs", []))
		_accessory_fits["blocked_hats"] = _normalize_id_list(data.get("blocked_hats", []))
		if not (_accessory_fits["hairs"] is Dictionary):
			_accessory_fits["hairs"] = {}
		if not (_accessory_fits["hats"] is Dictionary):
			_accessory_fits["hats"] = {}


func _save_accessory_fits() -> bool:
	var json := JSON.stringify(_accessory_fits, "\t")
	return _write_text(ACCESSORY_FITS_PATH, json)


func _hair_fits() -> Dictionary:
	return _accessory_fits.get("hairs", {}) as Dictionary


func _hat_fits() -> Dictionary:
	return _accessory_fits.get("hats", {}) as Dictionary


func _default_hair_fit() -> Dictionary:
	return {
		"scale": 1.3,
		"scale_xyz": [1.0, 1.0, 1.0],
		"offset": [0.0, 0.3, 0.0],
	}


func _default_hat_fit() -> Dictionary:
	return {
		"scale": 1.0,
		"offset": [0.0, 0.0, 0.0],
		"rotation": [0.0, 0.0, 0.0],
	}


func _get_hair_fit(style_id: int) -> Dictionary:
	var stored: Variant = _hair_fits().get(str(style_id), null)
	if stored is Dictionary:
		return stored
	return _default_hair_fit()


func _get_hat_fit(style_id: int) -> Dictionary:
	var stored: Variant = _hat_fits().get(str(style_id), null)
	if stored is Dictionary:
		return stored
	return _default_hat_fit()


func _has_hair_fit(style_id: int) -> bool:
	return _hair_fits().has(str(style_id))


func _has_hat_fit(style_id: int) -> bool:
	return _hat_fits().has(str(style_id))


func _normalize_id_list(value: Variant) -> Array:
	var ids: Array = []
	if not (value is Array):
		return ids
	for item in value:
		var style_id := int(item)
		if style_id > 0 and not ids.has(style_id):
			ids.append(style_id)
	return ids


func _is_hair_blocked(style_id: int) -> bool:
	return _normalize_id_list(_accessory_fits.get("blocked_hairs", [])).has(style_id)


func _is_hat_blocked(style_id: int) -> bool:
	return _normalize_id_list(_accessory_fits.get("blocked_hats", [])).has(style_id)


func _set_style_blocked(list_key: String, style_id: int, blocked: bool) -> void:
	if style_id <= 0:
		return
	var ids := _normalize_id_list(_accessory_fits.get(list_key, []))
	if blocked:
		if not ids.has(style_id):
			ids.append(style_id)
	else:
		ids.erase(style_id)
	_accessory_fits[list_key] = ids
	_save_accessory_fits()
	_refresh_fit_select_labels()
	_update_fit_status_labels()


func _allowed_random_hair_ids() -> Array[int]:
	var ids: Array[int] = []
	var count := ModularCharacterBase.HairStyle.size()
	for style_id in range(1, count):
		if not _is_hair_blocked(style_id):
			ids.append(style_id)
	return ids


func _random_hair_style() -> ModularCharacterBase.HairStyle:
	var allowed := _allowed_random_hair_ids()
	if allowed.is_empty():
		return ModularCharacterBase.HairStyle.NONE
	if randf() < 0.1:
		return ModularCharacterBase.HairStyle.NONE
	var pick: int = allowed[randi() % allowed.size()]
	return pick as ModularCharacterBase.HairStyle


func _fitted_hat_ids() -> Array[int]:
	var ids: Array[int] = []
	for key in _hat_fits():
		var style_id := int(str(key))
		if style_id > 0 and not _is_hat_blocked(style_id):
			ids.append(style_id)
	return ids


func _apply_hair_fit(style_id: int) -> void:
	var fit := _get_hair_fit(style_id)
	character.hair_scale = clampf(float(fit.get("scale", 1.3)), 0.3, 3.0)
	character.hair_scale_xyz = _clamped_scale_xyz(fit.get("scale_xyz", [1.0, 1.0, 1.0]))
	character.hair_offset = _vector3_from_array(fit.get("offset", [0.0, 0.3, 0.0]))


func _apply_hat_fit(style_id: int) -> void:
	var fit := _get_hat_fit(style_id)
	character.hat_scale = clampf(float(fit.get("scale", 1.0)), 0.5, 2.0)
	character.hat_offset = _vector3_from_array(fit.get("offset", [0.0, 0.0, 0.0]))
	character.hat_rotation = _vector3_from_array(fit.get("rotation", [0.0, 0.0, 0.0]))


func _current_hair_fit_dict() -> Dictionary:
	return {
		"scale": character.hair_scale,
		"scale_xyz": [character.hair_scale_xyz.x, character.hair_scale_xyz.y, character.hair_scale_xyz.z],
		"offset": [character.hair_offset.x, character.hair_offset.y, character.hair_offset.z],
	}


func _current_hat_fit_dict() -> Dictionary:
	return {
		"scale": character.hat_scale,
		"offset": [character.hat_offset.x, character.hat_offset.y, character.hat_offset.z],
		"rotation": [character.hat_rotation.x, character.hat_rotation.y, character.hat_rotation.z],
	}


func _setup_fit_room() -> void:
	var fit_button := Button.new()
	fit_button.name = "FitRoomButton"
	fit_button.text = "FIT ROOM"
	fit_button.custom_minimum_size = Vector2(0.0, 42.0)
	fit_button.tooltip_text = "Fit hairs and hats on this head. Saved fits are used when randomizing characters."
	fit_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.18, 0.32, 0.48, 1.0)
	normal.set_corner_radius_all(10)
	normal.set_border_width_all(2)
	normal.border_color = Color(0.62, 0.84, 1.0, 0.9)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.24, 0.42, 0.62, 1.0)
	fit_button.add_theme_stylebox_override("normal", normal)
	fit_button.add_theme_stylebox_override("hover", hover)
	fit_button.add_theme_stylebox_override("pressed", hover)
	fit_button.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0, 1.0))
	fit_button.pressed.connect(_toggle_fit_room)
	sidebar_controls.add_child(fit_button)
	sidebar_controls.move_child(fit_button, load_button.get_index() + 1)

	var panel := PanelContainer.new()
	panel.name = "FitRoomPanel"
	panel.visible = false
	panel.z_index = 20
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -360.0
	panel.offset_right = 0.0
	panel.offset_top = 0.0
	panel.offset_bottom = 0.0
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.045, 0.055, 0.085, 0.97)
	panel_sb.border_color = Color(0.62, 0.84, 1.0, 0.55)
	panel_sb.border_width_left = 2
	panel.add_theme_stylebox_override("panel", panel_sb)
	$UI.add_child(panel)
	_fit_room_panel = panel

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	scroll.add_child(col)

	var title := Label.new()
	title.text = "FIT ROOM"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.72, 0.90, 1.0, 1.0))
	col.add_child(title)
	var blurb := Label.new()
	blurb.text = "Fit each hair and hat on this head. Saved fits are used for randomized characters. Mark broken styles so Randomize never uses them."
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.add_theme_color_override("font_color", Color(0.70, 0.78, 0.90, 1.0))
	col.add_child(blurb)
	_fit_room_status = blurb

	var done := Button.new()
	done.text = "DONE — BACK TO CREATOR"
	done.custom_minimum_size = Vector2(0.0, 42.0)
	done.pressed.connect(_close_fit_room)
	col.add_child(done)
	col.add_child(HSeparator.new())

	var hair_title := Label.new()
	hair_title.text = "HAIR FITS"
	hair_title.add_theme_font_size_override("font_size", 16)
	hair_title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.38, 1.0))
	col.add_child(hair_title)
	var hair_row := HBoxContainer.new()
	hair_row.add_theme_constant_override("separation", 8)
	col.add_child(hair_row)
	var hair_prev := Button.new()
	hair_prev.text = "◀"
	hair_prev.custom_minimum_size = Vector2(40.0, 36.0)
	hair_prev.pressed.connect(func() -> void: _cycle_fit_hair(-1))
	hair_row.add_child(hair_prev)
	_fit_hair_select = OptionButton.new()
	_fit_hair_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fit_hair_select.custom_minimum_size = Vector2(0.0, 36.0)
	for i in hair_select.item_count:
		_fit_hair_select.add_item(hair_select.get_item_text(i))
	_fit_hair_select.item_selected.connect(_on_fit_hair_selected)
	hair_row.add_child(_fit_hair_select)
	var hair_next := Button.new()
	hair_next.text = "▶"
	hair_next.custom_minimum_size = Vector2(40.0, 36.0)
	hair_next.pressed.connect(func() -> void: _cycle_fit_hair(1))
	hair_row.add_child(hair_next)
	_fit_hair_status = Label.new()
	_fit_hair_status.add_theme_color_override("font_color", Color(0.70, 0.78, 0.90, 1.0))
	col.add_child(_fit_hair_status)
	_fit_hair_block = _make_fit_block_check("Don't use this hair on random characters")
	_fit_hair_block.toggled.connect(_on_fit_hair_block_toggled)
	col.add_child(_fit_hair_block)
	_add_adjustment_slider(col, "fit_hair_scale", "All", 0.3, 3.0, 0.05, character.hair_scale, func(value: float) -> void: character.hair_scale = value)
	_add_adjustment_slider(col, "fit_hair_scale_x", "Scale X", 0.3, 3.0, 0.05, character.hair_scale_xyz.x, func(value: float) -> void: _set_hair_scale_xyz_component(0, value))
	_add_adjustment_slider(col, "fit_hair_scale_y", "Scale Y", 0.3, 3.0, 0.05, character.hair_scale_xyz.y, func(value: float) -> void: _set_hair_scale_xyz_component(1, value))
	_add_adjustment_slider(col, "fit_hair_scale_z", "Scale Z", 0.3, 3.0, 0.05, character.hair_scale_xyz.z, func(value: float) -> void: _set_hair_scale_xyz_component(2, value))
	_add_adjustment_slider(col, "fit_hair_x", "Pos X", -1.2, 1.2, 0.01, character.hair_offset.x, func(value: float) -> void: _set_hair_offset_component(0, value))
	_add_adjustment_slider(col, "fit_hair_y", "Pos Y", -1.5, 1.8, 0.01, character.hair_offset.y, func(value: float) -> void: _set_hair_offset_component(1, value))
	_add_adjustment_slider(col, "fit_hair_z", "Pos Z", -1.5, 1.5, 0.01, character.hair_offset.z, func(value: float) -> void: _set_hair_offset_component(2, value))
	var save_hair := Button.new()
	save_hair.text = "SAVE THIS HAIR FIT"
	save_hair.custom_minimum_size = Vector2(0.0, 40.0)
	save_hair.pressed.connect(_save_current_hair_fit)
	col.add_child(save_hair)
	col.add_child(HSeparator.new())

	var hat_title := Label.new()
	hat_title.text = "HAT FITS"
	hat_title.add_theme_font_size_override("font_size", 16)
	hat_title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.38, 1.0))
	col.add_child(hat_title)
	var hat_row := HBoxContainer.new()
	hat_row.add_theme_constant_override("separation", 8)
	col.add_child(hat_row)
	var hat_prev := Button.new()
	hat_prev.text = "◀"
	hat_prev.custom_minimum_size = Vector2(40.0, 36.0)
	hat_prev.pressed.connect(func() -> void: _cycle_fit_hat(-1))
	hat_row.add_child(hat_prev)
	_fit_hat_select = OptionButton.new()
	_fit_hat_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fit_hat_select.custom_minimum_size = Vector2(0.0, 36.0)
	for i in hat_select.item_count:
		_fit_hat_select.add_item(hat_select.get_item_text(i))
	_fit_hat_select.item_selected.connect(_on_fit_hat_selected)
	hat_row.add_child(_fit_hat_select)
	var hat_next := Button.new()
	hat_next.text = "▶"
	hat_next.custom_minimum_size = Vector2(40.0, 36.0)
	hat_next.pressed.connect(func() -> void: _cycle_fit_hat(1))
	hat_row.add_child(hat_next)
	_fit_hat_status = Label.new()
	_fit_hat_status.add_theme_color_override("font_color", Color(0.70, 0.78, 0.90, 1.0))
	col.add_child(_fit_hat_status)
	_fit_hat_block = _make_fit_block_check("Don't use this hat on random characters")
	_fit_hat_block.toggled.connect(_on_fit_hat_block_toggled)
	col.add_child(_fit_hat_block)
	_add_adjustment_slider(col, "fit_hat_scale", "Scale", 0.5, 2.0, 0.05, character.hat_scale, func(value: float) -> void: character.hat_scale = value)
	_add_adjustment_slider(col, "fit_hat_x", "Left / right", -0.5, 0.5, 0.01, character.hat_offset.x, func(value: float) -> void: _set_hat_offset_component(0, value))
	_add_adjustment_slider(col, "fit_hat_y", "Up / down", -0.5, 0.5, 0.01, character.hat_offset.y, func(value: float) -> void: _set_hat_offset_component(1, value))
	_add_adjustment_slider(col, "fit_hat_z", "Into / out", -0.8, 0.8, 0.01, character.hat_offset.z, func(value: float) -> void: _set_hat_offset_component(2, value))
	_add_adjustment_slider(col, "fit_hat_pitch", "Pitch", -180.0, 180.0, 1.0, character.hat_rotation.x, func(value: float) -> void: _set_hat_rotation_component(0, value))
	_add_adjustment_slider(col, "fit_hat_yaw", "Yaw", -180.0, 180.0, 1.0, character.hat_rotation.y, func(value: float) -> void: _set_hat_rotation_component(1, value))
	_add_adjustment_slider(col, "fit_hat_roll", "Roll", -180.0, 180.0, 1.0, character.hat_rotation.z, func(value: float) -> void: _set_hat_rotation_component(2, value))
	var save_hat := Button.new()
	save_hat.text = "SAVE THIS HAT FIT"
	save_hat.custom_minimum_size = Vector2(0.0, 40.0)
	save_hat.pressed.connect(_save_current_hat_fit)
	col.add_child(save_hat)


func _toggle_fit_room() -> void:
	if _fit_room_open:
		_close_fit_room()
	else:
		_open_fit_room()


func _open_fit_room() -> void:
	_fit_snapshot = {
		"hair_style": character.hair_style,
		"hair_color": character.hair_color,
		"hair_scale": character.hair_scale,
		"hair_scale_xyz": character.hair_scale_xyz,
		"hair_offset": character.hair_offset,
		"hat_style": character.hat_style,
		"hat_color": character.hat_color,
		"hat_scale": character.hat_scale,
		"hat_offset": character.hat_offset,
		"hat_rotation": character.hat_rotation,
		"lash_style": character.lash_style,
		"makeup_style": character.makeup_style,
		"facial_hair_style": character.facial_hair_style,
		"glasses_style": character.glasses_style,
		"jewelry_style": character.jewelry_style,
	}
	_fit_room_open = true
	character.begin_appearance_batch()
	_apply_canonical_face_layout()
	character.lash_style = ModularCharacterBase.LashStyle.NONE
	character.makeup_style = ModularCharacterBase.MakeupStyle.NONE
	character.facial_hair_style = ModularCharacterBase.FacialHairStyle.NONE
	character.glasses_style = ModularCharacterBase.GlassesStyle.NONE
	character.jewelry_style = ModularCharacterBase.JewelryStyle.NONE
	if character.hair_style == ModularCharacterBase.HairStyle.NONE:
		character.hair_style = ModularCharacterBase.HairStyle.SIMPLE_PARTED
	_apply_hair_fit(int(character.hair_style))
	character.hat_style = ModularCharacterBase.HatStyle.NONE
	character.end_appearance_batch()
	if _fit_hair_select != null:
		_fit_hair_select.select(int(character.hair_style))
	if _fit_hat_select != null:
		_fit_hat_select.select(0)
	_sync_fit_room_sliders()
	_sync_fit_block_checks()
	_refresh_fit_select_labels()
	_update_fit_status_labels()
	if _fit_room_panel != null:
		_fit_room_panel.visible = true
	var modules := get_node_or_null("UI/ModulesPanel") as CanvasItem
	if modules != null:
		modules.visible = false
	_apply_fit_room_camera()
	_update_feature_hotspot_positions()
	_set_status("Fit Room open. Save a hair or hat fit, then hit Done.")


func _close_fit_room() -> void:
	if not _fit_room_open:
		return
	_fit_room_open = false
	character.begin_appearance_batch()
	character.hair_style = int(_fit_snapshot.get("hair_style", int(character.hair_style))) as ModularCharacterBase.HairStyle
	character.hair_color = _fit_snapshot.get("hair_color", character.hair_color) as Color
	character.hair_scale = float(_fit_snapshot.get("hair_scale", character.hair_scale))
	character.hair_scale_xyz = _fit_snapshot.get("hair_scale_xyz", character.hair_scale_xyz) as Vector3
	character.hair_offset = _fit_snapshot.get("hair_offset", character.hair_offset) as Vector3
	character.hat_style = int(_fit_snapshot.get("hat_style", int(character.hat_style))) as ModularCharacterBase.HatStyle
	character.hat_color = _fit_snapshot.get("hat_color", character.hat_color) as Color
	character.hat_scale = float(_fit_snapshot.get("hat_scale", character.hat_scale))
	character.hat_offset = _fit_snapshot.get("hat_offset", character.hat_offset) as Vector3
	character.hat_rotation = _fit_snapshot.get("hat_rotation", character.hat_rotation) as Vector3
	character.lash_style = int(_fit_snapshot.get("lash_style", int(character.lash_style))) as ModularCharacterBase.LashStyle
	character.makeup_style = int(_fit_snapshot.get("makeup_style", int(character.makeup_style))) as ModularCharacterBase.MakeupStyle
	character.facial_hair_style = int(_fit_snapshot.get("facial_hair_style", int(character.facial_hair_style))) as ModularCharacterBase.FacialHairStyle
	character.glasses_style = int(_fit_snapshot.get("glasses_style", int(character.glasses_style))) as ModularCharacterBase.GlassesStyle
	character.jewelry_style = int(_fit_snapshot.get("jewelry_style", int(character.jewelry_style))) as ModularCharacterBase.JewelryStyle
	character.end_appearance_batch()
	_fit_snapshot.clear()
	if _fit_room_panel != null:
		_fit_room_panel.visible = false
	var modules := get_node_or_null("UI/ModulesPanel") as CanvasItem
	if modules != null:
		modules.visible = true
	_camera_distance = 3.35
	_camera_pan = Vector3.ZERO
	_orbit_x = -0.08
	_apply_camera()
	_refresh_appearance_controls()
	_update_feature_hotspot_positions()
	_set_status("Left Fit Room. Randomized characters will use any fits you saved.")


func _apply_fit_room_camera() -> void:
	_camera_distance = 2.15
	_camera_pan = Vector3(0.0, 0.58, 0.0)
	_orbit_x = -0.04
	_apply_camera()


func _on_fit_hair_selected(index: int) -> void:
	character.begin_appearance_batch()
	character.hair_style = index as ModularCharacterBase.HairStyle
	_apply_hair_fit(index)
	character.end_appearance_batch()
	_sync_fit_room_sliders()
	_sync_fit_block_checks()
	_update_fit_status_labels()


func _on_fit_hat_selected(index: int) -> void:
	character.begin_appearance_batch()
	character.hat_style = index as ModularCharacterBase.HatStyle
	_apply_hat_fit(index)
	character.end_appearance_batch()
	_sync_fit_room_sliders()
	_sync_fit_block_checks()
	_update_fit_status_labels()


func _cycle_fit_hair(step: int) -> void:
	if _fit_hair_select == null or _fit_hair_select.item_count <= 1:
		return
	var next_index := wrapi(_fit_hair_select.selected + step, 1, _fit_hair_select.item_count)
	_fit_hair_select.select(next_index)
	_on_fit_hair_selected(next_index)


func _cycle_fit_hat(step: int) -> void:
	if _fit_hat_select == null or _fit_hat_select.item_count <= 0:
		return
	var next_index := wrapi(_fit_hat_select.selected + step, 0, _fit_hat_select.item_count)
	_fit_hat_select.select(next_index)
	_on_fit_hat_selected(next_index)


func _save_current_hair_fit() -> void:
	var style_id := int(character.hair_style)
	if style_id <= 0:
		_set_status("Pick a hair style before saving a fit.", true)
		return
	var hairs := _hair_fits()
	hairs[str(style_id)] = _current_hair_fit_dict()
	_accessory_fits["hairs"] = hairs
	if _save_accessory_fits():
		_update_fit_status_labels()
		_set_status("Saved hair fit for %s." % hair_select.get_item_text(style_id))
	else:
		_set_status("Could not save the hair fit.", true)


func _save_current_hat_fit() -> void:
	var style_id := int(character.hat_style)
	if style_id <= 0:
		_set_status("Pick a hat before saving a fit.", true)
		return
	var hats := _hat_fits()
	hats[str(style_id)] = _current_hat_fit_dict()
	_accessory_fits["hats"] = hats
	if _save_accessory_fits():
		_update_fit_status_labels()
		_set_status("Saved hat fit for %s." % hat_select.get_item_text(style_id))
	else:
		_set_status("Could not save the hat fit.", true)


func _sync_fit_room_sliders() -> void:
	var values := {
		"fit_hair_scale": character.hair_scale,
		"fit_hair_scale_x": character.hair_scale_xyz.x,
		"fit_hair_scale_y": character.hair_scale_xyz.y,
		"fit_hair_scale_z": character.hair_scale_xyz.z,
		"fit_hair_x": character.hair_offset.x,
		"fit_hair_y": character.hair_offset.y,
		"fit_hair_z": character.hair_offset.z,
		"fit_hat_scale": character.hat_scale,
		"fit_hat_x": character.hat_offset.x,
		"fit_hat_y": character.hat_offset.y,
		"fit_hat_z": character.hat_offset.z,
		"fit_hat_pitch": character.hat_rotation.x,
		"fit_hat_yaw": character.hat_rotation.y,
		"fit_hat_roll": character.hat_rotation.z,
	}
	for key in values:
		if _adjustment_sliders.has(key):
			_adjustment_sliders[key].set_value_no_signal(values[key])


func _update_fit_status_labels() -> void:
	var hair_id := int(character.hair_style)
	if _fit_hair_status != null:
		if hair_id <= 0:
			_fit_hair_status.text = "Pick a hair to fit."
		elif _is_hair_blocked(hair_id):
			_fit_hair_status.text = "Off random. This hair will not spawn on randomized characters."
		elif _has_hair_fit(hair_id):
			_fit_hair_status.text = "Saved fit loaded. Tweak and save again if needed."
		else:
			_fit_hair_status.text = "No saved fit yet for this hair."
	var hat_id := int(character.hat_style)
	if _fit_hat_status != null:
		if hat_id <= 0:
			_fit_hat_status.text = "Pick a hat to fit."
		elif _is_hat_blocked(hat_id):
			_fit_hat_status.text = "Off random. This hat will not spawn on randomized characters."
		elif _has_hat_fit(hat_id):
			_fit_hat_status.text = "Saved fit loaded. Tweak and save again if needed."
		else:
			_fit_hat_status.text = "No saved fit yet for this hat."


func _make_fit_block_check(label_text: String) -> CheckBox:
	var box := CheckBox.new()
	box.text = label_text
	box.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_theme_color_override("font_color", Color(1.0, 0.78, 0.72, 1.0))
	box.add_theme_color_override("font_pressed_color", Color(1.0, 0.62, 0.52, 1.0))
	box.tooltip_text = "Randomize will skip this style even if a fit is saved."
	return box


func _on_fit_hair_block_toggled(on: bool) -> void:
	var style_id := int(character.hair_style)
	if style_id <= 0:
		return
	_set_style_blocked("blocked_hairs", style_id, on)
	var style_name := hair_select.get_item_text(style_id) if style_id < hair_select.item_count else "This hair"
	if on:
		_set_status("%s will not appear on randomized characters." % style_name)
	else:
		_set_status("%s can appear on randomized characters." % style_name)


func _on_fit_hat_block_toggled(on: bool) -> void:
	var style_id := int(character.hat_style)
	if style_id <= 0:
		return
	_set_style_blocked("blocked_hats", style_id, on)
	var style_name := hat_select.get_item_text(style_id) if style_id < hat_select.item_count else "This hat"
	if on:
		_set_status("%s will not appear on randomized characters." % style_name)
	else:
		_set_status("%s can appear on randomized characters." % style_name)


func _sync_fit_block_checks() -> void:
	var hair_id := int(character.hair_style)
	if _fit_hair_block != null:
		_fit_hair_block.disabled = hair_id <= 0
		_fit_hair_block.set_pressed_no_signal(hair_id > 0 and _is_hair_blocked(hair_id))
	var hat_id := int(character.hat_style)
	if _fit_hat_block != null:
		_fit_hat_block.disabled = hat_id <= 0
		_fit_hat_block.set_pressed_no_signal(hat_id > 0 and _is_hat_blocked(hat_id))


func _refresh_fit_select_labels() -> void:
	if _fit_hair_select != null:
		for i in _fit_hair_select.item_count:
			var base := hair_select.get_item_text(i) if i < hair_select.item_count else "Hair"
			if i > 0 and _is_hair_blocked(i):
				_fit_hair_select.set_item_text(i, "%s  · off random" % base)
			else:
				_fit_hair_select.set_item_text(i, base)
	if _fit_hat_select != null:
		for i in _fit_hat_select.item_count:
			var base := hat_select.get_item_text(i) if i < hat_select.item_count else "Hat"
			if i > 0 and _is_hat_blocked(i):
				_fit_hat_select.set_item_text(i, "%s  · off random" % base)
			else:
				_fit_hat_select.set_item_text(i, base)


func _set_status(message: String, is_error: bool = false) -> void:
	status_label.text = message
	status_label.modulate = Color("ff8c8c") if is_error else Color("aeb9cc")
