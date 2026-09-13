extends Node3D
## Reusable ticket. Model origin is the top edge; printed front faces local +Z.
signal state_changed(state: StringName)

@export var wind_enabled: bool = false
@export var interactable: bool = true
@export_range(0.01, 0.5) var blend_seconds: float = 0.12

var current_state: StringName = &"static"
var _player: AnimationPlayer
var _paper: MeshInstance3D
var _clips: Dictionary = {}

func _ready() -> void:
	_player = _find_type(self, "AnimationPlayer") as AnimationPlayer
	_paper = _find_type(self, "MeshInstance3D") as MeshInstance3D
	$TapArea.input_ray_pickable = interactable
	if _player == null:
		push_error("Order ticket: imported GLB has no AnimationPlayer")
		return
	# Libraries are local per ticket so loop changes never alter shared imports.
	for library_name in _player.get_animation_library_list():
		var local_library := _player.get_animation_library(library_name).duplicate(true) as AnimationLibrary
		_player.remove_animation_library(library_name)
		_player.add_animation_library(library_name, local_library)
	for clip in _player.get_animation_list():
		var short_name := String(clip).get_slice("/", String(clip).get_slice_count("/") - 1)
		_clips[short_name] = clip
		var animation := _player.get_animation(clip)
		animation.loop_mode = Animation.LOOP_LINEAR if short_name in ["static", "wave", "rolled"] else Animation.LOOP_NONE
	_player.animation_finished.connect(_on_finished)
	set_state(&"wave" if wind_enabled else &"static", 0.0)

func _find_type(node: Node, type_name: String) -> Node:
	for child in node.get_children():
		if child.is_class(type_name):
			return child
		var result := _find_type(child, type_name)
		if result != null:
			return result
	return null

func set_state(state: StringName, transition: float = -1.0) -> void:
	if _player == null or not _clips.has(String(state)):
		return
	current_state = state
	_player.play(_clips[String(state)], blend_seconds if transition < 0.0 else transition)
	state_changed.emit(state)

func set_wind(enabled: bool, speed: float = 1.0) -> void:
	wind_enabled = enabled
	if _player == null:
		return
	_player.speed_scale = clampf(speed, 0.1, 3.0)
	if current_state in [&"static", &"wave"]:
		set_state(&"wave" if enabled else &"static")

func tap() -> void:
	if current_state not in [&"roll", &"rolled", &"unroll"]:
		set_state(&"tap", 0.04)

func shake() -> void:
	if current_state not in [&"roll", &"rolled", &"unroll"]:
		set_state(&"shake", 0.05)

func roll_up() -> void:
	if current_state not in [&"roll", &"rolled"]:
		set_state(&"roll")

func unroll() -> void:
	if current_state == &"rolled":
		set_state(&"unroll", 0.0)

func set_ticket_texture(atlas: Texture2D) -> void:
	if _paper == null or atlas == null:
		return
	var material := _paper.get_active_material(0).duplicate() as StandardMaterial3D
	if material != null:
		material.albedo_texture = atlas
		_paper.set_surface_override_material(0, material)

func _on_finished(_animation_name: StringName) -> void:
	if current_state == &"roll":
		set_state(&"rolled", 0.0)
	elif current_state in [&"tap", &"shake", &"unroll"]:
		set_state(&"wave" if wind_enabled else &"static")

func _on_tap_area_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		tap()
	elif event is InputEventScreenTouch and event.pressed:
		tap()
