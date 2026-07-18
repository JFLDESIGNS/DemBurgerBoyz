## Toastable bun pair on the flat-top — 2D top + bottom art, shared cook clock.
## Perfect toast at 2.0s; burns at 4.2s.
## Gated off in game.gd via BUN_TOAST_ENABLED — flip that true to restore.
extends Area3D

const UiFontsScript := preload("res://scripts/ui_fonts.gd")
const FoodSpritesScript := preload("res://scripts/food_sprites.gd")

const TOAST_READY := 2.0 ## Perfect toasted score window center
const TOAST_BURNT := 4.2
const TOAST_PERFECT_SLACK := 0.35 ## ±sec around 2s still counts as perfect
const TOAST_HOLD_MAX := 40.0 ## Toasted buns stay fresh this long on HOLD

signal clicked(bun: Area3D)

## Kept for duck-typing; pair always carries both halves.
var bun_kind: String = "bun_pair"
var cook_time: float = 0.0
var heating: bool = true
var heat_mul: float = 1.0
var is_held: bool = false
var slot_index: int = -1
var net_id: int = -1
var warm_hold_time: float = 0.0
var flipped_once: bool = true
var has_cheese: bool = false
var base_y: float = 0.9
var _rest_x: float = 0.0
var _rest_z: float = 0.0
var mp_puppet: bool = false

var _bottom_spr: Sprite3D
var _top_spr: Sprite3D
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
	_build_sprites()
	_build_collision()
	_build_hint()
	_refresh_visuals()


func _build_sprites() -> void:
	## Flat 2D burger-art facing the cook — both halves toast together.
	_bottom_spr = Sprite3D.new()
	_bottom_spr.name = "BunBottom2D"
	_bottom_spr.texture = FoodSpritesScript.get_tex("bun_bottom")
	_bottom_spr.pixel_size = 0.00135
	_bottom_spr.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_bottom_spr.shaded = false
	_bottom_spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_bottom_spr.position = Vector3(0.0, 0.002, 0.0)
	_bottom_spr.rotation_degrees = Vector3(-72.0, 0.0, 0.0)
	add_child(_bottom_spr)

	_top_spr = Sprite3D.new()
	_top_spr.name = "BunTop2D"
	_top_spr.texture = FoodSpritesScript.get_tex("bun_top")
	_top_spr.pixel_size = 0.00135
	_top_spr.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_top_spr.shaded = false
	_top_spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_top_spr.position = Vector3(0.0, 0.028, -0.012)
	_top_spr.rotation_degrees = Vector3(-72.0, 0.0, 0.0)
	add_child(_top_spr)


func _build_collision() -> void:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.28, 0.06, 0.22)
	col.shape = shape
	col.position = Vector3(0.0, 0.02, 0.0)
	add_child(col)


func _build_hint() -> void:
	_hint = Label3D.new()
	_hint.text = ""
	_hint.position = Vector3(0, 0.14, 0.02)
	_hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hint.visible = false
	UiFontsScript.apply_label3d(_hint, true, 56, 0.06)
	_hint.outline_size = 0
	add_child(_hint)


func setup(_kind: String = "bun_pair", start_cook: float = 0.0) -> void:
	bun_kind = "bun_pair"
	cook_time = maxf(0.0, start_cook)
	_announced_ready = cook_time >= TOAST_READY
	_announced_burnt = cook_time >= TOAST_BURNT
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


func is_perfect_toast() -> bool:
	return absf(cook_time - TOAST_READY) <= TOAST_PERFECT_SLACK and cook_time < TOAST_BURNT


func is_burnt() -> bool:
	return cook_time >= TOAST_BURNT


func is_hold_stale() -> bool:
	return warm_hold_time >= TOAST_HOLD_MAX


func hold_seconds_left() -> float:
	return maxf(0.0, TOAST_HOLD_MAX - warm_hold_time)


func can_scoop() -> bool:
	return true


func can_flip() -> bool:
	return false


func flip() -> bool:
	return false


func toast_frac() -> float:
	if cook_time <= TOAST_READY:
		return cook_time / TOAST_READY
	return 1.0 + clampf((cook_time - TOAST_READY) / maxf(0.001, TOAST_BURNT - TOAST_READY), 0.0, 1.0)


func toast_score_mul() -> float:
	## Peak pay at exactly 2s toasted; raw (never grilled) is neutral 1.0.
	if cook_time <= 0.05:
		return 1.0
	if is_burnt():
		return 0.72
	if is_perfect_toast():
		return 1.15
	if cook_time < TOAST_READY:
		return lerpf(0.94, 1.15, cook_time / TOAST_READY)
	return lerpf(1.15, 0.72, (cook_time - TOAST_READY) / maxf(0.001, TOAST_BURNT - TOAST_READY))


func cook_rating_text() -> String:
	if is_burnt():
		return "BURNT"
	if is_perfect_toast():
		return "PERFECT TOAST"
	if is_ready():
		return "TOASTED"
	return "TOASTING"


func cook_rating() -> Dictionary:
	if is_burnt():
		return {"color": Color("EF5350")}
	if is_perfect_toast():
		return {"color": Color("FFE082")}
	if is_ready():
		return {"color": Color("FFCC80")}
	return {"color": Color("FFF3E0")}


func set_hint_focus(on: bool) -> void:
	_hint_focused = on
	_update_hint()


func refresh_cook_visuals() -> void:
	_refresh_visuals()


func _toast_modulate() -> Color:
	var raw := Color(1, 1, 1, 1)
	var toasted := Color(0.82, 0.58, 0.36, 1)
	var burnt := Color(0.28, 0.16, 0.10, 1)
	if cook_time <= TOAST_READY:
		return raw.lerp(toasted, cook_time / TOAST_READY)
	var t := clampf(
		(cook_time - TOAST_READY) / maxf(0.001, TOAST_BURNT - TOAST_READY),
		0.0, 1.0
	)
	return toasted.lerp(burnt, t)


func _refresh_visuals() -> void:
	var m := _toast_modulate()
	if _bottom_spr != null:
		_bottom_spr.modulate = m
	if _top_spr != null:
		_top_spr.modulate = m


func _update_hint() -> void:
	if _hint == null:
		return
	if is_held:
		_hint.visible = false
		return
	if is_hold_stale():
		_hint.text = "STALE"
		_hint.modulate = Color("EF5350")
		_hint.visible = true
	elif warm_hold_time > 0.05 and cook_time >= TOAST_READY and not is_burnt():
		_hint.text = "HOLD %ds" % maxi(1, int(ceil(hold_seconds_left())))
		_hint.modulate = Color("90CAF9")
		_hint.visible = true
	elif is_burnt():
		_hint.text = "BURNT"
		_hint.modulate = Color("EF5350")
		_hint.visible = true
		_announced_burnt = true
	elif is_perfect_toast():
		_hint.text = "PERFECT"
		_hint.modulate = Color("FFE082")
		_hint.visible = true
		_announced_ready = true
	elif is_ready():
		_hint.text = "READY"
		_hint.modulate = Color("FFCC80")
		_hint.visible = true
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
