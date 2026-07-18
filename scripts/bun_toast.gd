## Toastable bun half on the flat-top. Ready at 2s, burns at 4.2s.
extends Area3D

const UiFontsScript := preload("res://scripts/ui_fonts.gd")

const TOAST_READY := 2.0
const TOAST_BURNT := 4.2

signal clicked(bun: Area3D)

## "bun_bottom" or "bun_top"
var bun_kind: String = "bun_bottom"
var cook_time: float = 0.0
var heating: bool = true
var heat_mul: float = 1.0
var is_held: bool = false
var slot_index: int = -1
var net_id: int = -1
var warm_hold_time: float = 0.0
## Duck-type so grill code that expects patties keeps working.
var flipped_once: bool = true
var has_cheese: bool = false
var base_y: float = 0.9
var _rest_x: float = 0.0
var _rest_z: float = 0.0
var mp_puppet: bool = false

var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _hint: Label3D
var _hint_focused: bool = false
var _announced_ready: bool = false
var _announced_burnt: bool = false


func is_bun_toast() -> bool:
	return true


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	monitoring = false
	monitorable = true
	input_ray_pickable = true
	_build_mesh()
	_build_hint()
	_refresh_visuals()


func _build_mesh() -> void:
	_mesh = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	var is_top := bun_kind == "bun_top"
	cyl.top_radius = 0.118 if is_top else 0.122
	cyl.bottom_radius = 0.122 if is_top else 0.118
	cyl.height = 0.038 if is_top else 0.028
	_mesh.mesh = cyl
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh.material_override = _mat
	add_child(_mesh)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.125
	shape.height = 0.04
	col.shape = shape
	add_child(col)


func _build_hint() -> void:
	_hint = Label3D.new()
	_hint.text = ""
	_hint.position = Vector3(0, 0.12, 0)
	_hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hint.visible = false
	UiFontsScript.apply_label3d(_hint, true, 56, 0.06)
	_hint.outline_size = 0
	add_child(_hint)


func setup(kind: String, start_cook: float = 0.0) -> void:
	bun_kind = kind
	cook_time = maxf(0.0, start_cook)
	_announced_ready = cook_time >= TOAST_READY
	_announced_burnt = cook_time >= TOAST_BURNT
	if _mesh != null:
		_refresh_visuals()


func _process(delta: float) -> void:
	if mp_puppet:
		_refresh_visuals()
		_update_hint()
		return
	if heating and not is_held and heat_mul > 0.001:
		cook_time += delta * heat_mul
	_refresh_visuals()
	_update_hint()


func is_ready() -> bool:
	return cook_time >= TOAST_READY and cook_time < TOAST_BURNT


func is_burnt() -> bool:
	return cook_time >= TOAST_BURNT


func can_scoop() -> bool:
	## Always liftable — toasting is optional, burn is the risk.
	return true


func can_flip() -> bool:
	return false


func flip() -> bool:
	return false


func toast_frac() -> float:
	## 0 raw · 1 ready · >1 toward burnt (caps ~2).
	if cook_time <= TOAST_READY:
		return cook_time / TOAST_READY
	return 1.0 + clampf((cook_time - TOAST_READY) / maxf(0.001, TOAST_BURNT - TOAST_READY), 0.0, 1.0)


func cook_rating_text() -> String:
	if is_burnt():
		return "BURNT"
	if is_ready():
		return "TOASTED"
	return "TOASTING"


func cook_rating() -> Dictionary:
	if is_burnt():
		return {"color": Color("EF5350")}
	if is_ready():
		return {"color": Color("FFCC80")}
	return {"color": Color("FFE082")}


func set_hint_focus(on: bool) -> void:
	_hint_focused = on
	_update_hint()


func refresh_cook_visuals() -> void:
	_refresh_visuals()


func _raw_color() -> Color:
	if bun_kind == "bun_top":
		return Color(0.91, 0.66, 0.36)
	return Color(0.98, 0.78, 0.42)


func _toasted_color() -> Color:
	return Color(0.72, 0.42, 0.18)


func _burnt_color() -> Color:
	return Color(0.18, 0.10, 0.06)


func _refresh_visuals() -> void:
	if _mat == null:
		return
	var c := _raw_color()
	if cook_time <= TOAST_READY:
		var t := cook_time / TOAST_READY
		c = c.lerp(_toasted_color(), t)
	else:
		var t2 := clampf((cook_time - TOAST_READY) / maxf(0.001, TOAST_BURNT - TOAST_READY), 0.0, 1.0)
		c = _toasted_color().lerp(_burnt_color(), t2)
	_mat.albedo_color = c


func _update_hint() -> void:
	if _hint == null:
		return
	if is_held:
		_hint.visible = false
		return
	if is_burnt():
		_hint.text = "BURNT"
		_hint.modulate = Color("EF5350")
		_hint.visible = true
		if not _announced_burnt:
			_announced_burnt = true
	elif is_ready():
		_hint.text = "READY"
		_hint.modulate = Color("FFCC80")
		_hint.visible = true
		if not _announced_ready:
			_announced_ready = true
	elif heating and heat_mul > 0.001:
		_hint.text = "TOAST"
		_hint.modulate = Color("FFE082")
		_hint.visible = _hint_focused
	else:
		_hint.visible = false
	_hint.scale = Vector3.ONE * (1.0 if _hint_focused else 0.72)


func _input_event(_camera: Camera3D, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)
