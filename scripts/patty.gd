## 3D burger patty on the flat-top. Pink -> grey -> cooked -> black.
extends Area3D

signal flipped
signal clicked(patty: Area3D)

enum CookState { RAW, SEARING, COOKED, PERFECT, BURNT }

const COOK_SEAR := 2.0
const COOK_DONE := 4.2
const COOK_PERFECT := 5.4
const COOK_BURNT := 7.5
const FLIP_READY := 1.0
const FLIP_WINDOW_START := 1.5
const FLIP_WINDOW_END := 4.5
const SCOOP_READY := 2.2 ## cook time needed after flip before scoop

var cook_time: float = 0.0
var flipped_once: bool = false
var is_held: bool = false
var smash_bonus: float = 0.0
var slot_index: int = -1
var perfect_flip: bool = false
var heating: bool = true
var base_y: float = 0.9

var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _hint: Label3D
var _sizzle: float = 0.0


func _ready() -> void:
	input_ray_pickable = true
	monitoring = false
	monitorable = false
	collision_layer = 2
	collision_mask = 0

	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.28
	cyl.height = 0.22
	shape.shape = cyl
	add_child(shape)

	_mesh = MeshInstance3D.new()
	var disk := CylinderMesh.new()
	disk.top_radius = 0.135
	disk.bottom_radius = 0.135
	disk.height = 0.065
	disk.radial_segments = 18
	_mesh.mesh = disk
	_mat = StandardMaterial3D.new()
	_mat.roughness = 0.8
	_mat.albedo_color = get_patty_color()
	_mat.emission_enabled = true
	_mat.emission = Color("FF8A80")
	_mat.emission_energy_multiplier = 0.2
	_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	_mesh.material_override = _mat
	add_child(_mesh)

	_hint = Label3D.new()
	_hint.text = "CLICK TO FLIP!"
	_hint.font_size = 32
	_hint.pixel_size = 0.0032
	_hint.position = Vector3(0, 0.22, 0)
	_hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hint.modulate = Color("FFEB3B")
	_hint.outline_modulate = Color.BLACK
	_hint.outline_size = 10
	_hint.visible = false
	add_child(_hint)


func _process(delta: float) -> void:
	if is_held:
		return
	if heating:
		var rate := 1.0 + smash_bonus
		smash_bonus = maxf(0.0, smash_bonus - delta * 0.8)
		cook_time += delta * rate
		_sizzle += delta * 8.0
	_mat.albedo_color = get_patty_color()
	_mat.emission = get_patty_color()
	_mat.emission_energy_multiplier = 0.35 if cook_time < COOK_SEAR else 0.08

	if can_flip():
		_hint.visible = true
		if is_in_flip_window():
			_hint.text = "CLICK TO FLIP!"
			_hint.modulate = Color("FFEB3B")
		else:
			_hint.text = "FLIP NOW"
			_hint.modulate = Color("FFCC80")
		_hint.modulate.a = 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() * 0.01))
	elif flipped_once and can_scoop():
		_hint.visible = true
		_hint.text = "CLICK TO SCOOP"
		_hint.modulate = Color("A5D6A7")
		_hint.modulate.a = 0.6 + 0.4 * absf(sin(Time.get_ticks_msec() * 0.008))
	elif flipped_once:
		_hint.visible = true
		_hint.text = "COOKING..."
		_hint.modulate = Color("FFCC80")
		_hint.modulate.a = 0.7
	else:
		_hint.visible = false

	rotation.y = 0.0
	position.y = slot_base_y()


func slot_base_y() -> float:
	return base_y


func get_patty_color() -> Color:
	var t := cook_time
	if t < COOK_SEAR:
		return Color("FF8A80").lerp(Color("BCAAA4"), t / COOK_SEAR)
	elif t < COOK_DONE:
		return Color("BCAAA4").lerp(Color("6D4C41"), (t - COOK_SEAR) / (COOK_DONE - COOK_SEAR))
	elif t < COOK_PERFECT:
		return Color("6D4C41").lerp(Color("5D4037"), (t - COOK_DONE) / (COOK_PERFECT - COOK_DONE))
	elif t < COOK_BURNT:
		return Color("5D4037").lerp(Color("212121"), (t - COOK_PERFECT) / (COOK_BURNT - COOK_PERFECT))
	return Color("121212")


func get_state() -> CookState:
	if cook_time >= COOK_BURNT:
		return CookState.BURNT
	if cook_time >= COOK_PERFECT:
		return CookState.PERFECT
	if cook_time >= COOK_DONE:
		return CookState.COOKED
	if cook_time >= COOK_SEAR:
		return CookState.SEARING
	return CookState.RAW


func get_doneness_label() -> String:
	match get_state():
		CookState.RAW:
			return "Raw"
		CookState.SEARING:
			return "Searing"
		CookState.COOKED:
			return "Cooked"
		CookState.PERFECT:
			return "Perfect!"
		CookState.BURNT:
			return "Burnt!"
	return ""


func can_flip() -> bool:
	return not flipped_once and cook_time >= FLIP_READY


func can_scoop() -> bool:
	## Only after a flip, and only once the second side has cooked a bit.
	return flipped_once and cook_time >= SCOOP_READY


func is_in_flip_window() -> bool:
	return not flipped_once and cook_time >= FLIP_WINDOW_START and cook_time <= FLIP_WINDOW_END


func flip() -> bool:
	if flipped_once or cook_time < FLIP_READY:
		return false
	flipped_once = true
	perfect_flip = is_in_flip_window()
	cook_time = maxf(cook_time * 0.35, COOK_SEAR * 0.35)
	_hint.visible = false
	var tw := create_tween()
	tw.tween_property(self, "scale:x", 0.1, 0.08)
	tw.tween_property(self, "scale:x", 1.0, 0.12)
	flipped.emit()
	return true


func smash() -> void:
	smash_bonus = 1.6
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1.3, 0.55, 1.3), 0.06)
	tw.tween_property(self, "scale", Vector3.ONE, 0.1)


func quality_multiplier() -> float:
	if not flipped_once:
		return 0.35
	match get_state():
		CookState.PERFECT:
			return 1.35 if perfect_flip else 1.2
		CookState.COOKED:
			return 1.1 if perfect_flip else 1.0
		CookState.BURNT:
			return 0.25
		CookState.SEARING:
			return 0.55
		_:
			return 0.3


func _input_event(_camera: Camera3D, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit(self)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			smash()
