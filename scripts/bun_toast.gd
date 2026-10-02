## Toastable 3D bun pair with a shared cook clock.
## Toasted at 8 seconds; starts burning after 16 seconds.
extends Area3D

const UiFontsScript := preload("res://scripts/ui_fonts.gd")
const FoodSpritesScript := preload("res://scripts/food_sprites.gd")

const TOAST_READY := 8.0 ## First fully toasted moment
const TOAST_BURNT := 16.0
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

var _materials: Array = []
var _halo: MeshInstance3D
var _halo_mat: ShaderMaterial
var spot_dwell_t := 0.0
var spot_dwell_xz := Vector2.ZERO
var spot_residue_rolled := false
var spot_residue_spawned := false
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
	var pack = preload("res://scripts/burger_pack_models.gd")
	for half in ["Bottom", "Top"]:
		var path := "res://models/burgerpack/try2/SM_BurgerBunUntoasted%s.glb" % half
		var model: Node3D = pack.instantiate_scene(path, 1.0)
		if model == null: continue
		var holder := Node3D.new()
		holder.name = half
		add_child(holder)
		holder.add_child(model)
		model.scale.y *= 1.30 if half == "Bottom" else 1.10
		# Cut surfaces face the steel: invert the heel, leave the crown upright.
		if half == "Bottom": model.rotation.z = PI
		var game := get_tree().current_scene
		var bounds: AABB = game._shop_preview_bounds(holder)
		var factor := .16 / maxf(.001, maxf(bounds.size.x, bounds.size.z))
		model.scale *= factor
		model.position = Vector3(-.085 if half == "Bottom" else .085, 0, 0) - Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)*factor
		_collect_materials(model)
	_halo = MeshInstance3D.new()
	_halo.name = "CookingProgressHalo"
	var plane := QuadMesh.new()
	plane.size = Vector2(0.13, 0.13)
	_halo.mesh = plane
	_halo.position = Vector3(0, .19, 0)
	_halo_mat = ShaderMaterial.new()
	_halo_mat.shader = preload("res://shaders/patty_cook_halo.gdshader")
	_halo.material_override = _halo_mat
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_halo)


func _collect_materials(node: Node) -> void:
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var material = node.get_active_material(i)
			if material is StandardMaterial3D:
				var local = material.duplicate()
				node.set_surface_override_material(i, local)
				_materials.append({"material": local, "base": local.albedo_color})
	for child in node.get_children(): _collect_materials(child)


func _build_collision() -> void:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.34, 0.08, 0.18)
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
	var game := get_tree().current_scene
	if game != null and game.has_method("_boss_speech_active") and (not game.playing or game.options_menu_open or game.shift_paused or game._boss_speech_active()): return
	if mp_puppet:
		_refresh_visuals()
		_update_hint()
		return
	if heating and not is_held and heat_mul > 0.001:
		cook_time += delta
	_refresh_visuals()
	_update_hint()


func is_ready() -> bool:
	return cook_time >= TOAST_READY and cook_time <= TOAST_BURNT


func is_perfect_toast() -> bool:
	return is_ready()


func is_burnt() -> bool:
	return cook_time > TOAST_BURNT


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
	return 1.0 + clampf((cook_time - TOAST_BURNT) / 8.0, 0.0, 1.0)


func toast_score_mul() -> float:
	## The full 8–16 second toasted window earns the same bonus.
	if cook_time <= 0.05:
		return 1.0
	if is_burnt():
		return 0.72
	if is_perfect_toast():
		return 1.15
	if cook_time < TOAST_READY:
		return lerpf(0.94, 1.15, cook_time / TOAST_READY)
	return lerpf(1.15, 0.72, (cook_time - TOAST_BURNT) / 8.0)


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
	var toasted := Color(0.91, 0.79, 0.68, 1)
	var burnt := Color(0.28, 0.16, 0.10, 1)
	if cook_time <= TOAST_READY:
		return raw.lerp(toasted, cook_time / TOAST_READY)
	var t := clampf(
		(cook_time - TOAST_BURNT) / 8.0,
		0.0, 1.0
	)
	return toasted.lerp(burnt, t)


func _refresh_visuals() -> void:
	var m := _toast_modulate()
	for entry in _materials: entry.material.albedo_color = entry.base * m
	if is_instance_valid(_halo):
		_halo.visible = heating and heat_mul > .001 and not is_held and cook_time < TOAST_READY
		_halo_mat.set_shader_parameter("progress", clampf(cook_time / TOAST_READY, 0, 1))
		var camera := get_viewport().get_camera_3d()
		if camera != null and _halo.is_inside_tree(): _halo.look_at(camera.global_position, Vector3.UP, true)
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
		_hint.text = ""
		_hint.modulate = Color("FFE082")
		_hint.visible = false
	else:
		_hint.visible = false
	_hint.scale = Vector3.ONE * (1.0 if _hint_focused else 0.72)


func _input_event(_camera: Camera3D, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)
