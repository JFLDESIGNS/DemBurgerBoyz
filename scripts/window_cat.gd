## Street-cat that peeks under the service window — pet the head or feed treats.
extends Node3D

const SCENE_PATH := "res://assets/cat/cat.fbx"
const CAT_COLLISION_LAYER := 128
## Screen-left of the window (world +X) — clear of the center customer lane.
const HOME_X := 1.38
const HOME_Z := 1.68
## Under the sill when hidden; peek high enough to clear the ledge.
## Dropped another 6″ from the prior peek heights.
const HIDDEN_Y := 0.141
const SHOWN_Y := 0.741
const MESH_SCALE := 3.35
## Gets chunkier with each treat — width sticks when it comes back.
const FAT_PER_TOPPING := 0.10
const FAT_MAX := 1.35 ## ~2.35× horizontal scale at max chonk
## Face the cook (mesh nose points +Z; yaw 180 looks into the truck).
const FACE_COOK_YAW := 180.0
const FACE_AWAY_YAW := 0.0
## First peek early in the shift so players notice him.
const FIRST_PEEK_SEC := 18.0
## Regular dice-roll peeks — every 45s, 75% chance he shows (even with customers).
const REPEEK_SEC := 45.0
const PEEK_CHANCE := 0.75
const PEEK_MIN_SEC := 5.5
const PEEK_MAX_SEC := 9.0
## After a full burger — celebrate, then bolt for a long break.
const FED_HOLD_SEC := 1.15
const PATTY_EAT_WIDTH_BOOST := 0.25 ## +25% width while chewing a patty, before run-away.
const RUN_SEC := 1.35
const AFTER_BURGER_HIDE_SEC := 95.0

signal fed(kind: String)
signal petted

var _visual: Node3D = null
var _area: Area3D = null
var _anim: AnimationPlayer = null
var _state: String = "hidden" ## hidden | rising | peek | lowering | fed_hold | running
var _timer: float = 4.0
var _bob: float = 0.0
var _pet_squash: float = 0.0
var _treat_arm: float = 0.0
var _eat_flash: float = 0.0
var enabled: bool = true
## Kept for API compat — peeks no longer require an empty window.
var _gap_open: bool = true
var _mouth_burger: Node3D = null
var _hearts: GPUParticles3D = null
var _run_from: Vector3 = Vector3.ZERO
var _run_to: Vector3 = Vector3.ZERO
var _run_yaw_from: float = FACE_COOK_YAW
## Persistent chonk from feeding (0 = slim … FAT_MAX = very wide). Survives run-aways.
var _fat: float = 0.0
## 0–1 — patty chew swell (width grows to +25% during fed_hold, then commits to _fat).
var _patty_eat_wide: float = 0.0


func _ready() -> void:
	_build()
	position = Vector3(HOME_X, HIDDEN_Y, HOME_Z)
	rotation_degrees = Vector3(0.0, FACE_COOK_YAW, 0.0)
	_timer = FIRST_PEEK_SEC
	_state = "hidden"
	visible = false


func set_customer_gap(_open: bool) -> void:
	## Peeks happen on a timer now — customers no longer block or duck him.
	_gap_open = true


func _build() -> void:
	if not ResourceLoader.exists(SCENE_PATH):
		push_warning("Window cat missing: %s" % SCENE_PATH)
		return
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		return
	_visual = packed.instantiate() as Node3D
	if _visual == null:
		return
	_visual.name = "CatMesh"
	_visual.position = Vector3.ZERO
	_visual.rotation_degrees = Vector3.ZERO
	_visual.scale = Vector3.ONE * MESH_SCALE
	add_child(_visual)
	_retint_cat_fur(_visual)
	_anim = _visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim != null and _anim.has_animation("CINEMA_4D_Main"):
		_anim.get_animation("CINEMA_4D_Main").loop_mode = Animation.LOOP_LINEAR
		_anim.play("CINEMA_4D_Main")
		_anim.speed_scale = 0.85

	_area = Area3D.new()
	_area.name = "CatPetZone"
	_area.input_ray_pickable = true
	_area.collision_layer = CAT_COLLISION_LAYER
	_area.collision_mask = 0
	_area.monitoring = false
	_area.monitorable = true
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	## Generous head hit box in local (unscaled root) space.
	box.size = Vector3(0.55, 0.55, 0.45)
	shape.shape = box
	shape.position = Vector3(0.0, 0.42, 0.08)
	_area.add_child(shape)
	add_child(_area)
	_ensure_hearts()


func _retint_cat_fur(node: Node) -> void:
	## Darken the coat and kill the purple cast — more black street cat.
	## Eyes get a wet glossy look instead.
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var is_eye := str(mi.name).to_lower().contains("eye")
		var surf_count := 0
		if mi.mesh != null:
			surf_count = mi.mesh.get_surface_count()
		if surf_count <= 0:
			surf_count = maxi(1, mi.get_surface_override_material_count())
		for si in surf_count:
			var base: Material = mi.get_active_material(si) if mi.mesh != null and si < mi.mesh.get_surface_count() else null
			if base == null:
				base = mi.material_override
			var sm: StandardMaterial3D
			if base is StandardMaterial3D:
				sm = (base as StandardMaterial3D).duplicate() as StandardMaterial3D
			elif base == null:
				sm = StandardMaterial3D.new()
			else:
				continue
			if is_eye:
				_make_eye_glossy(sm, si, base)
			else:
				_make_fur_dark(sm)
			if mi.mesh != null and si < mi.mesh.get_surface_count():
				mi.set_surface_override_material(si, sm)
			else:
				mi.material_override = sm
	for child in node.get_children():
		_retint_cat_fur(child)


func _make_eye_glossy(sm: StandardMaterial3D, surf_i: int, base: Material) -> void:
	## Wet glass cornea look — bright iris + shiny black pupil.
	var src := sm.albedo_color
	if base is StandardMaterial3D:
		src = (base as StandardMaterial3D).albedo_color
	var name_hint := ""
	if base != null:
		name_hint = str(base.resource_name).to_lower()
	var is_yellow := name_hint.contains("yellow") or (src.r > 0.45 and src.g > 0.35 and src.b < 0.45)
	var is_black := name_hint.contains("black") or src.get_luminance() < 0.25
	## Surface order on this mesh: yellow iris / black pupil (either way).
	if is_yellow or (not is_black and surf_i == 0 and src.g > src.b):
		sm.albedo_color = Color(0.95, 0.78, 0.12)
		if sm.albedo_texture != null:
			sm.albedo_color = Color(1.0, 0.92, 0.55)
	else:
		sm.albedo_color = Color(0.04, 0.035, 0.03)
		if sm.albedo_texture != null:
			sm.albedo_color = Color(0.12, 0.1, 0.09)
	sm.metallic = 0.08
	sm.roughness = 0.06
	sm.clearcoat_enabled = true
	sm.clearcoat = 1.0
	sm.clearcoat_roughness = 0.04
	sm.rim_enabled = true
	sm.rim = 0.45
	sm.rim_tint = 0.35
	sm.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	sm.anisotropy_enabled = false


func _make_fur_dark(sm: StandardMaterial3D) -> void:
	var c := sm.albedo_color
	## Pull blue/magenta toward charcoal so the coat reads black, not purple.
	var gray := (c.r + c.g + c.b) / 3.0
	c.r = lerpf(c.r, gray, 0.35)
	c.g = lerpf(c.g, gray, 0.2)
	c.b = lerpf(c.b, gray * 0.85, 0.7)
	## Multiply dark — textures darken with this tint.
	if sm.albedo_texture != null:
		c = Color(0.38, 0.34, 0.30) * Color(minf(c.r + 0.15, 1.0), minf(c.g + 0.12, 1.0), minf(c.b + 0.08, 1.0))
	else:
		c = c.darkened(0.42)
		c.b *= 0.75
	sm.albedo_color = c
	sm.metallic = minf(sm.metallic, 0.05)
	sm.roughness = maxf(sm.roughness, 0.72)


func _ensure_hearts() -> void:
	if _hearts != null and is_instance_valid(_hearts):
		return
	_hearts = GPUParticles3D.new()
	_hearts.name = "CatHearts"
	_hearts.amount = 18
	_hearts.lifetime = 1.15
	_hearts.one_shot = true
	_hearts.explosiveness = 0.75
	_hearts.randomness = 0.55
	_hearts.emitting = false
	_hearts.position = Vector3(0.0, 0.62, 0.06)
	_hearts.visibility_aabb = AABB(Vector3(-1.5, -0.2, -1.5), Vector3(3, 3, 3))
	_hearts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 42.0
	mat.initial_velocity_min = 0.55
	mat.initial_velocity_max = 1.35
	mat.gravity = Vector3(0, 0.35, 0)
	mat.damping_min = 0.4
	mat.damping_max = 1.1
	mat.scale_min = 0.55
	mat.scale_max = 1.15
	mat.color = Color(1.0, 0.35, 0.48, 1.0)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.2, 0.75, 1.0])
	grad.colors = PackedColorArray([
		Color(1.0, 0.55, 0.65, 0.0),
		Color(1.0, 0.28, 0.42, 1.0),
		Color(1.0, 0.45, 0.55, 0.85),
		Color(1.0, 0.7, 0.8, 0.0),
	])
	var tex := GradientTexture1D.new()
	tex.gradient = grad
	mat.color_ramp = tex
	_hearts.process_material = mat
	## Little heart-ish billboards (pink quads).
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.09)
	var draw := StandardMaterial3D.new()
	draw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw.albedo_color = Color(1.0, 0.35, 0.5, 0.95)
	draw.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	draw.cull_mode = BaseMaterial3D.CULL_DISABLED
	draw.vertex_color_use_as_albedo = true
	quad.material = draw
	_hearts.draw_pass_1 = quad
	add_child(_hearts)


func _build_mouth_burger() -> void:
	_clear_mouth_burger()
	_mouth_burger = Node3D.new()
	_mouth_burger.name = "MouthBurger"
	## Sit in the muzzle — toward the cook (local +Z after mesh facing).
	_mouth_burger.position = Vector3(0.0, 0.34, 0.22)
	_mouth_burger.rotation_degrees = Vector3(-12.0, 0.0, 8.0)
	_mouth_burger.scale = Vector3(0.55, 0.55, 0.55)
	add_child(_mouth_burger)

	var bot := _burger_bun_mesh(Color(0.78, 0.52, 0.28), 0.11, 0.045)
	bot.position = Vector3(0, 0.0, 0)
	_mouth_burger.add_child(bot)

	var meat := MeshInstance3D.new()
	var disk := CylinderMesh.new()
	disk.top_radius = 0.095
	disk.bottom_radius = 0.095
	disk.height = 0.028
	disk.radial_segments = 18
	meat.mesh = disk
	meat.position = Vector3(0, 0.038, 0)
	var meat_mat := StandardMaterial3D.new()
	meat_mat.albedo_color = Color(0.28, 0.14, 0.08)
	meat_mat.roughness = 0.85
	meat.material_override = meat_mat
	_mouth_burger.add_child(meat)

	var cheese := MeshInstance3D.new()
	var cbox := BoxMesh.new()
	cbox.size = Vector3(0.18, 0.012, 0.18)
	cheese.mesh = cbox
	cheese.position = Vector3(0, 0.055, 0)
	cheese.rotation_degrees = Vector3(0, 18, 0)
	var ch_mat := StandardMaterial3D.new()
	ch_mat.albedo_color = Color(1.0, 0.82, 0.22)
	ch_mat.roughness = 0.55
	cheese.material_override = ch_mat
	_mouth_burger.add_child(cheese)

	var top := _burger_bun_mesh(Color(0.86, 0.58, 0.3), 0.112, 0.055)
	top.position = Vector3(0, 0.088, 0)
	_mouth_burger.add_child(top)

	## Sesame flecks on the top bun.
	for i in 5:
		var seed := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.008
		s.height = 0.016
		seed.mesh = s
		seed.position = Vector3(randf_range(-0.06, 0.06), 0.118, randf_range(-0.05, 0.05))
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(0.95, 0.9, 0.75)
		seed.material_override = sm
		_mouth_burger.add_child(seed)


func _burger_bun_mesh(color: Color, radius: float, height: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius * 0.92
	cyl.bottom_radius = radius
	cyl.height = height
	cyl.radial_segments = 18
	mi.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.78
	mi.material_override = mat
	return mi


func _clear_mouth_burger() -> void:
	if _mouth_burger != null and is_instance_valid(_mouth_burger):
		_mouth_burger.queue_free()
	_mouth_burger = null


func _burst_hearts() -> void:
	_ensure_hearts()
	if _hearts == null:
		return
	_hearts.restart()
	_hearts.emitting = true


func _process(delta: float) -> void:
	if not enabled or _visual == null:
		return
	_bob += delta
	_treat_arm = maxf(0.0, _treat_arm - delta)
	_pet_squash = maxf(0.0, _pet_squash - delta * 3.2)
	_eat_flash = maxf(0.0, _eat_flash - delta)
	_timer -= delta
	match _state:
		"hidden":
			visible = false
			position = Vector3(HOME_X, HIDDEN_Y, HOME_Z)
			if _timer <= 0.0:
				## Every 45s: 75% chance to peek (even with a full window).
				if randf() < PEEK_CHANCE:
					_state = "rising"
					_timer = 0.55
					visible = true
					position.y = HIDDEN_Y
				else:
					_timer = REPEEK_SEC
		"rising":
			position.x = HOME_X
			position.z = HOME_Z
			visible = true
			var t := 1.0 - clampf(_timer / 0.55, 0.0, 1.0)
			var ease := 1.0 - pow(1.0 - t, 3.0)
			position.y = lerpf(HIDDEN_Y, SHOWN_Y, ease)
			if _timer <= 0.0:
				_state = "peek"
				_timer = randf_range(PEEK_MIN_SEC, PEEK_MAX_SEC)
				position.y = SHOWN_Y
		"peek":
			position.x = HOME_X
			position.z = HOME_Z
			visible = true
			position.y = SHOWN_Y + sin(_bob * 2.4) * 0.012
			rotation_degrees.y = FACE_COOK_YAW + sin(_bob * 1.3) * 6.0
			if _timer <= 0.0:
				_state = "lowering"
				_timer = 0.5
		"fed_hold":
			## Proud pose with burger in mouth + hearts; width swells while chewing.
			visible = true
			position.x = HOME_X
			position.z = HOME_Z
			position.y = SHOWN_Y + sin(_bob * 5.0) * 0.03
			rotation_degrees.y = FACE_COOK_YAW + sin(_bob * 4.0) * 10.0
			var eat_u := 1.0 - clampf(_timer / FED_HOLD_SEC, 0.0, 1.0)
			_patty_eat_wide = eat_u * eat_u * (3.0 - 2.0 * eat_u)
			if _mouth_burger != null and is_instance_valid(_mouth_burger):
				_mouth_burger.rotation_degrees.y = sin(_bob * 6.0) * 12.0
				_mouth_burger.position.y = 0.34 + sin(_bob * 7.0) * 0.01
			if _timer <= 0.0:
				_begin_run_away()
		"running":
			visible = true
			var u := 1.0 - clampf(_timer / RUN_SEC, 0.0, 1.0)
			var ease_r := u * u * (3.0 - 2.0 * u)
			position = _run_from.lerp(_run_to, ease_r)
			rotation_degrees.y = lerpf(_run_yaw_from, FACE_AWAY_YAW + 25.0, ease_r)
			## Gallop bob while carrying the burger off.
			position.y += absf(sin(u * TAU * 3.0)) * 0.08
			if _anim != null:
				_anim.speed_scale = 1.6
			if _timer <= 0.0:
				_finish_run_away()
		"lowering":
			position.x = HOME_X
			position.z = HOME_Z
			visible = true
			var t2 := 1.0 - clampf(_timer / 0.5, 0.0, 1.0)
			var ease2 := t2 * t2
			position.y = lerpf(SHOWN_Y, HIDDEN_Y, ease2)
			if _timer <= 0.0:
				_state = "hidden"
				_timer = REPEEK_SEC
				visible = false
				position.y = HIDDEN_Y
				rotation_degrees.y = FACE_COOK_YAW
				_treat_arm = 0.0
				_clear_mouth_burger()
	## Soft squash when petted / fed — keep accumulated width.
	if _visual != null:
		var fat_w := 1.0 + _fat
		var eat_w := 1.0 + _patty_eat_wide * PATTY_EAT_WIDTH_BOOST
		var sx := MESH_SCALE * fat_w * eat_w * (1.0 - _pet_squash * 0.08)
		var sy := MESH_SCALE * (1.0 + _pet_squash * 0.06) * (1.0 + _fat * 0.08)
		var sz := MESH_SCALE * lerpf(1.0, fat_w, 0.7) * eat_w * (1.0 - _pet_squash * 0.05)
		_visual.scale = Vector3(sx, sy, sz)


func _begin_run_away() -> void:
	## Lock in the patty chew chonk before bolting.
	_fat = minf(FAT_MAX, _fat + PATTY_EAT_WIDTH_BOOST)
	_patty_eat_wide = 0.0
	_state = "running"
	_timer = RUN_SEC
	_run_from = position
	## Dash screen-left / street-ward with the burger.
	_run_to = Vector3(HOME_X + 2.4, HIDDEN_Y + 0.15, HOME_Z + 2.8)
	_run_yaw_from = rotation_degrees.y
	if _anim != null:
		_anim.speed_scale = 1.55


func _finish_run_away() -> void:
	_state = "hidden"
	_timer = AFTER_BURGER_HIDE_SEC
	visible = false
	position = Vector3(HOME_X, HIDDEN_Y, HOME_Z)
	rotation_degrees = Vector3(0.0, FACE_COOK_YAW, 0.0)
	_treat_arm = 0.0
	_clear_mouth_burger()
	if _anim != null:
		_anim.speed_scale = 0.85
	if _hearts != null and is_instance_valid(_hearts):
		_hearts.emitting = false


func is_interactable() -> bool:
	return enabled and visible and (_state == "peek" or _state == "rising")


func treat_window_open() -> bool:
	return is_interactable() and _treat_arm > 0.0


func head_global() -> Vector3:
	return global_position + Vector3(0.0, 0.48, 0.05)


func hit_test(camera: Camera3D, screen_pos: Vector2, max_px: float = 52.0) -> bool:
	if not is_interactable() or camera == null or _area == null:
		return false
	var tip := head_global()
	if camera.is_position_behind(tip):
		return false
	var screen_pt := camera.unproject_position(tip)
	if screen_pos.distance_to(screen_pt) <= max_px:
		return true
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 24.0)
	q.collide_with_areas = true
	q.collide_with_bodies = false
	q.collision_mask = CAT_COLLISION_LAYER
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return not hit.is_empty() and hit.get("collider") == _area


func hit_test_feed(camera: Camera3D, screen_pos: Vector2) -> bool:
	## Roomier drop target while dragging a burger / topping to the cat.
	return hit_test(camera, screen_pos, 130.0)


func pet() -> void:
	if not is_interactable():
		return
	_pet_squash = 1.0
	_treat_arm = 2.4
	## Linger a bit longer when loved.
	if _state == "peek":
		_timer = maxf(_timer, 4.0)
	petted.emit()


func feed(kind: String) -> void:
	if not is_interactable():
		return
	_pet_squash = 1.0
	_eat_flash = 0.6
	_treat_arm = 0.0
	## Widen on toppings a little; patty swell animates during fed_hold.
	if kind == "patty":
		_patty_eat_wide = 0.0
		_feed_full_burger()
	else:
		_fat = minf(FAT_MAX, _fat + FAT_PER_TOPPING)
		if _state == "peek":
			_timer = maxf(_timer, 5.0)
		_burst_hearts()
	fed.emit(kind)


func _feed_full_burger() -> void:
	## 3D burger in the mouth, hearts from the head, then dash away.
	_build_mouth_burger()
	_burst_hearts()
	_state = "fed_hold"
	_timer = FED_HOLD_SEC
	visible = true
	position.y = SHOWN_Y
	if _anim != null:
		_anim.speed_scale = 1.25


func reset_shift() -> void:
	_state = "hidden"
	_timer = FIRST_PEEK_SEC
	_treat_arm = 0.0
	_pet_squash = 0.0
	_fat = 0.0
	_patty_eat_wide = 0.0
	_gap_open = true
	visible = false
	position = Vector3(HOME_X, HIDDEN_Y, HOME_Z)
	rotation_degrees = Vector3(0.0, FACE_COOK_YAW, 0.0)
	_clear_mouth_burger()
	if _anim != null:
		_anim.speed_scale = 0.85
	if _hearts != null and is_instance_valid(_hearts):
		_hearts.emitting = false
	if _visual != null:
		_visual.scale = Vector3.ONE * MESH_SCALE