## Bigger cube customer with a clear order chat bubble.
extends Node3D

const GameDataScript := preload("res://scripts/game_data.gd")

signal arrived(customer: Node3D)
signal patience_expired(customer: Node3D)
signal served(customer: Node3D, payout: int)

var order: Array[String] = []
var body_color: Color = Color.WHITE
var patience_max: float = 45.0
var patience: float = 45.0
var target_x: float = 0.0
var lane: int = 0
var is_waiting: bool = false
var is_leaving: bool = false
var order_value: int = 8
var speech: String = ""

var _body: MeshInstance3D
var _face: Label3D
var _bubble: Label3D
var _bubble_bg: MeshInstance3D
var _bar_bg: MeshInstance3D
var _bar_fill: MeshInstance3D
var _bounce: float = 0.0


func setup(p_order: Array[String], color: Color, p_patience: float, p_lane: int) -> void:
	order = p_order
	body_color = color
	patience_max = p_patience
	patience = p_patience
	lane = p_lane
	order_value = GameDataScript.order_value(order)
	speech = _make_speech()


func _ready() -> void:
	_build()
	_bounce = randf() * TAU


func _build() -> void:
	_body = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.95, 1.05, 0.95)
	_body.mesh = box
	_body.position = Vector3(0, 0.55, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = body_color
	mat.roughness = 0.55
	_body.material_override = mat
	add_child(_body)

	add_child(_make_eye(Vector3(-0.2, 0.72, 0.48)))
	add_child(_make_eye(Vector3(0.2, 0.72, 0.48)))

	_face = Label3D.new()
	_face.text = "^_^"
	_face.font_size = 48
	_face.pixel_size = 0.004
	_face.position = Vector3(0, 0.48, 0.5)
	_face.modulate = Color(0.1, 0.1, 0.12)
	add_child(_face)

	_bubble_bg = MeshInstance3D.new()
	var bg_mesh := BoxMesh.new()
	bg_mesh.size = Vector3(1.6, 0.55, 0.05)
	_bubble_bg.mesh = bg_mesh
	_bubble_bg.position = Vector3(0, 1.85, 0)
	var bgm := StandardMaterial3D.new()
	bgm.albedo_color = Color(1, 1, 1, 0.95)
	bgm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bubble_bg.material_override = bgm
	_bubble_bg.visible = false
	add_child(_bubble_bg)

	_bubble = Label3D.new()
	_bubble.text = speech
	_bubble.font_size = 22
	_bubble.pixel_size = 0.0045
	_bubble.position = Vector3(0, 1.85, 0.04)
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.modulate = Color(0.12, 0.12, 0.14)
	_bubble.outline_modulate = Color.WHITE
	_bubble.outline_size = 4
	_bubble.visible = false
	add_child(_bubble)

	_bar_bg = MeshInstance3D.new()
	var bg := BoxMesh.new()
	bg.size = Vector3(0.9, 0.08, 0.05)
	_bar_bg.mesh = bg
	_bar_bg.position = Vector3(0, 1.35, 0)
	var bar_mat := StandardMaterial3D.new()
	bar_mat.albedo_color = Color(0.15, 0.15, 0.15)
	_bar_bg.material_override = bar_mat
	add_child(_bar_bg)

	_bar_fill = MeshInstance3D.new()
	var fill := BoxMesh.new()
	fill.size = Vector3(0.84, 0.06, 0.055)
	_bar_fill.mesh = fill
	_bar_fill.position = Vector3(0, 1.35, 0.01)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("66BB6A")
	_bar_fill.material_override = fm
	add_child(_bar_fill)


func _make_eye(pos: Vector3) -> MeshInstance3D:
	var eye := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = 0.08
	m.height = 0.16
	eye.mesh = m
	eye.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.08, 0.1)
	eye.material_override = mat
	return eye


func _make_speech() -> String:
	var parts: Array[String] = []
	for item in order:
		if item == "bun_bottom" or item == "bun_top":
			continue
		if item == "patty":
			parts.append("Patty")
		else:
			parts.append(GameDataScript.INGREDIENT_LABELS.get(item, item))
	if parts.is_empty():
		return "Burger please!"
	return "I want:\n" + " + ".join(parts)


func _process(delta: float) -> void:
	_bounce += delta * 3.0
	if is_leaving:
		global_position.z += delta * 2.2
		global_position.y += delta * 0.2
		if global_position.z > 14.0:
			queue_free()
		return

	var dx: float = target_x - global_position.x
	if absf(dx) > 0.05:
		global_position.x += signf(dx) * minf(absf(dx), delta * 1.6)
		_body.position.y = 0.55 + sin(_bounce) * 0.04
	elif not is_waiting:
		is_waiting = true
		_bubble.visible = true
		_bubble_bg.visible = true
		arrived.emit(self)

	if is_waiting:
		patience -= delta
		var t: float = clampf(patience / patience_max, 0.0, 1.0)
		_bar_fill.scale = Vector3(t, 1, 1)
		_bar_fill.position.x = -0.42 * (1.0 - t)
		var fm: StandardMaterial3D = _bar_fill.material_override
		if t > 0.55:
			fm.albedo_color = Color("66BB6A")
			_face.text = "^_^"
		elif t > 0.28:
			fm.albedo_color = Color("FFCA28")
			_face.text = "-_-"
		else:
			fm.albedo_color = Color("EF5350")
			_face.text = ">_<"
		if patience <= 0.0:
			leave_mad()
			patience_expired.emit(self)


func leave_happy() -> void:
	is_leaving = true
	is_waiting = false
	_bubble.visible = false
	_bubble_bg.visible = false
	_face.text = "^o^"


func leave_mad() -> void:
	is_leaving = true
	is_waiting = false
	_bubble.visible = false
	_bubble_bg.visible = false
	_face.text = "X_X"


func patience_ratio() -> float:
	return clampf(patience / maxf(0.01, patience_max), 0.0, 1.0)


func receive_burger(built: Array, patty_mult: float, combo: int, tip: float) -> int:
	var result: Dictionary = GameDataScript.compare_orders(built, order)
	if result.quality < 0.4:
		complete_serve(0)
		return 0
	var payout: int = int(round(
		float(order_value) * float(result.quality) * patty_mult * (1.0 + tip) * (1.0 + float(combo) * 0.08)
	))
	payout = maxi(payout, 1 if result.quality >= 0.55 else 0)
	complete_serve(payout)
	return payout


func complete_serve(payout: int) -> void:
	served.emit(self, payout)
	leave_happy()
