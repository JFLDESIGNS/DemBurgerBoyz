## Armed hostile — patrols from far down the street; gunmen shoot, bombers rush the cart.
extends "res://scripts/customer.gd"

signal shot_player(damage: float)
signal detonated(damage: float, at: Vector3)

## Simple black pistol — bone-mounted to RightHand so it tracks the grip.
const GUN_GRIP_SIZE := Vector3(0.076, 0.18, 0.10)
const GUN_BARREL_SIZE := Vector3(0.048, 0.056, 0.26)
const GUN_SLIDE_SIZE := Vector3(0.06, 0.07, 0.20)
const GUN_MUZZLE_LOCAL := Vector3(0.0, 0.0, -0.36)
const GUN_HAND_OFFSET := Vector3(0.0, 0.03, 0.04)
const GUN_LOCAL_GRIP_ROT := Vector3(8.0, -92.0, -6.0)
const GUN_AIM_PITCH := -6.0
const GUN_AIM_ROLL := 4.0
const TERR_RAGDOLL_TWIST_SEC := 1.25
const TERR_RAGDOLL_ACTIVE_SEC := 7.0
const TERR_FLAT_PITCH := 90.0
const TERR_FLAT_Y_OFFSET := 0.06
## ~1 Godot unit ≈ 1 meter. Stay in front of the street matte (Z ≈ 11.5).
const FT := 0.3048
const WINDOW_Z := 1.05
const MATTE_SAFE_Z := 9.55 ## Just in front of MATTE_FRONT_Z_MAX / street paint.
const DISTANT_Z := 9.35 ## Furthest visible hostiles (still in front of backdrop).
const FAR_Z := 7.65
const MID_Z := 5.55
const HOLD_Z_MIN := 3.55
const HOLD_Z_MAX := 4.85
const SHOOT_Z := 8.85
const SHOOT_INTERVAL := 5.0 ## One roll every five seconds.
const SHOOT_CHANCE := 0.5 ## 50% chance to actually fire on each roll.
const AIM_POSE_SEC := 0.65 ## Hold two-hand aim while the shot goes off.
const BOMB_DETONATE_Z := 2.38
const BOMB_SPRINT_Z := 4.15
const BOMB_WALK_SPEED := 1.55
const BOMB_RUN_SPEED := 3.65
const GUN_WALK_SPEED := 1.45
## Wide street lanes — hostiles must not stack in one clump.
const TERR_LANE_X: Array[float] = [-9.2, -6.4, -3.6, -0.8, 2.0, 4.8, -11.5, 7.0]
const OPENING_SPAWN_X: Array[float] = [-9.5, -6.0, -2.2, 1.5, 4.8, -11.8, 7.2, -4.2]
## Keep old names for game.gd call sites.
const HOLD_Z := HOLD_Z_MIN + 0.8
const MID_HOLD_Z := MID_Z
const SPAWN_X := -8.5
const SPAWN_Z_MIN := FAR_Z
const SPAWN_Z_MAX := DISTANT_Z

var target_z: float = HOLD_Z
var is_bomber: bool = false
var _combat_ready: bool = false
var _weapon_presented: bool = false
var _shoot_timer: float = 5.0
var _aim_pose_t: float = 0.0
var _detonated: bool = false
var _pause_t: float = 0.0
var _waypoints_done: int = 0
var _gun_root: Node3D = null
var _gun_mesh: Node3D = null
var _gun_flash: OmniLight3D = null
var _muzzle_flash: MeshInstance3D = null
var _bomb_vest: MeshInstance3D = null
var _chest_mount: BoneAttachment3D = null
var _hand_mount: BoneAttachment3D = null


func setup_terrorist(p_lane: int) -> void:
	is_bomber = false
	order = []
	body_color = Color(0.42, 0.4, 0.38)
	patience_max = 9999.0
	patience = patience_max
	lane = p_lane
	order_value = 0
	personality = "quiet"
	chatter = ""
	speech = ""
	is_terrorist = true
	_skin_path = "res://assets/characters/Skins/criminalMaleA.png"
	_face_style = 0
	target_x = lane_x_for(p_lane)
	target_z = HOLD_Z


func setup_bomber(p_lane: int) -> void:
	setup_terrorist(p_lane)
	is_bomber = true
	target_z = BOMB_DETONATE_Z
	_skin_path = "res://assets/characters/Skins/criminalMaleA.png"


static func lane_x_for(lane_i: int) -> float:
	if TERR_LANE_X.is_empty():
		return 0.0
	return TERR_LANE_X[clampi(lane_i, 0, TERR_LANE_X.size() - 1)]


static func spawn_pose(lane_i: int) -> Vector3:
	return Vector3(
		lane_x_for(lane_i) + randf_range(-0.8, 0.8),
		STAND_Y,
		randf_range(FAR_Z, DISTANT_Z)
	)


static func opening_pose(slot: int, tier: String, role: String = "gun") -> Dictionary:
	## Unique wide X per slot so the opening wave fans across the street.
	var spawn_x := OPENING_SPAWN_X[clampi(slot, 0, OPENING_SPAWN_X.size() - 1)]
	spawn_x += randf_range(-0.35, 0.35)
	var spawn_z := DISTANT_Z
	match tier:
		"mid":
			spawn_z = randf_range(MID_Z - 0.6, MID_Z + 0.9)
		"far":
			spawn_z = randf_range(FAR_Z - 0.7, FAR_Z + 0.9)
		_:
			## Furthest band still in front of the street painting.
			spawn_z = randf_range(DISTANT_Z - 0.55, DISTANT_Z)
	## Stagger depth per slot so they aren't a single rank.
	spawn_z = minf(MATTE_SAFE_Z, spawn_z + float(slot % 3) * 0.35 + randf_range(-0.25, 0.25))
	if role == "bomber":
		return {
			"pos": Vector3(spawn_x, STAND_Y, spawn_z),
			"target_x": spawn_x + randf_range(-1.2, 1.2),
			"target_z": maxf(BOMB_SPRINT_Z, spawn_z - randf_range(1.6, 3.2)),
		}
	var first_z := maxf(HOLD_Z_MAX, spawn_z - randf_range(1.2, 2.8))
	first_z = minf(MATTE_SAFE_Z, first_z)
	return {
		"pos": Vector3(spawn_x, STAND_Y, spawn_z),
		"target_x": spawn_x + randf_range(-2.2, 2.2),
		"target_z": first_z,
	}


func present_weapon(aim_ready: bool = false) -> void:
	_weapon_presented = true
	if aim_ready:
		_combat_ready = true
		rotation_degrees.y = FACE_TRUCK_YAW
		_set_gun_aim(true)
		_aim_pose_t = AIM_POSE_SEC
	_shoot_timer = randf_range(0.5, SHOOT_INTERVAL)


func _ready() -> void:
	super._ready()
	if is_bomber:
		_attach_bomb_vest()
	else:
		call_deferred("_attach_gun")
	_shoot_timer = randf_range(0.5, SHOOT_INTERVAL)
	_pause_t = 0.0


func _ensure_hand_mount() -> BoneAttachment3D:
	if _hand_mount != null and is_instance_valid(_hand_mount):
		return _hand_mount
	_cache_panic_bones()
	_cache_skeleton()
	if _skeleton == null:
		return null
	_hand_mount = BoneAttachment3D.new()
	_hand_mount.name = "TerrorHandMount"
	if _panic_bones.has("RightHand"):
		_hand_mount.bone_name = "RightHand"
	elif _panic_bones.has("RightForeArm"):
		_hand_mount.bone_name = "RightForeArm"
	else:
		return null
	_skeleton.add_child(_hand_mount)
	return _hand_mount


func _ensure_chest_mount() -> BoneAttachment3D:
	if _chest_mount != null and is_instance_valid(_chest_mount):
		return _chest_mount
	_cache_panic_bones()
	_cache_skeleton()
	if _skeleton == null:
		return null
	_chest_mount = BoneAttachment3D.new()
	_chest_mount.name = "TerrorChestMount"
	if _panic_bones.has("UpperChest"):
		_chest_mount.bone_name = "UpperChest"
	elif _panic_bones.has("Chest"):
		_chest_mount.bone_name = "Chest"
	else:
		_chest_mount.bone_name = "Spine"
	_skeleton.add_child(_chest_mount)
	return _chest_mount


func _black_gun_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.05, 0.06)
	mat.metallic = 0.4
	mat.roughness = 0.48
	return mat


func _build_simple_gun() -> Node3D:
	var root := Node3D.new()
	root.name = "SimplePistol"
	var mat := _black_gun_material()
	var grip := MeshInstance3D.new()
	var grip_box := BoxMesh.new()
	grip_box.size = GUN_GRIP_SIZE
	grip.mesh = grip_box
	grip.material_override = mat
	grip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	grip.sorting_offset = 30.0
	root.add_child(grip)
	var slide := MeshInstance3D.new()
	var slide_box := BoxMesh.new()
	slide_box.size = GUN_SLIDE_SIZE
	slide.mesh = slide_box
	slide.material_override = mat
	slide.position = Vector3(0.0, 0.04, -0.08)
	slide.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	slide.sorting_offset = 30.0
	root.add_child(slide)
	var barrel := MeshInstance3D.new()
	var barrel_box := BoxMesh.new()
	barrel_box.size = GUN_BARREL_SIZE
	barrel.mesh = barrel_box
	barrel.material_override = mat
	barrel.position = Vector3(0.0, 0.028, -0.18)
	barrel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	barrel.sorting_offset = 30.0
	root.add_child(barrel)
	return root


func _attach_gun() -> void:
	var mount := _ensure_hand_mount()
	if mount == null:
		return
	_gun_root = Node3D.new()
	_gun_root.name = "TerrorGun"
	mount.add_child(_gun_root)
	_gun_root.position = GUN_HAND_OFFSET
	_gun_root.rotation_degrees = GUN_LOCAL_GRIP_ROT
	_gun_root.scale = Vector3.ONE
	_gun_mesh = _build_simple_gun()
	_gun_root.add_child(_gun_mesh)
	_gun_flash = OmniLight3D.new()
	_gun_flash.name = "GunFlash"
	_gun_flash.light_color = Color(1.0, 0.82, 0.45)
	_gun_flash.light_energy = 0.0
	_gun_flash.omni_range = 0.55
	_gun_flash.shadow_enabled = false
	_gun_flash.position = GUN_MUZZLE_LOCAL
	_gun_root.add_child(_gun_flash)
	_muzzle_flash = MeshInstance3D.new()
	_muzzle_flash.name = "MuzzleFlash"
	var disc := SphereMesh.new()
	disc.radius = 0.06
	disc.height = 0.12
	_muzzle_flash.mesh = disc
	var flash_mat := StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.albedo_color = Color(1.0, 0.88, 0.45, 0.95)
	flash_mat.emission_enabled = true
	flash_mat.emission = Color(1.0, 0.75, 0.25)
	flash_mat.emission_energy_multiplier = 4.0
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_muzzle_flash.material_override = flash_mat
	_muzzle_flash.visible = false
	_muzzle_flash.position = GUN_MUZZLE_LOCAL
	_gun_root.add_child(_muzzle_flash)
	_sync_gun_pose(false)


func _player_aim_point() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		return cam.global_position
	## Fallback: cook window / grill line.
	return Vector3(randf_range(-0.25, 0.25), 1.55, 0.72)


func _muzzle_global() -> Vector3:
	if _gun_root != null and is_instance_valid(_gun_root):
		return _gun_root.to_global(GUN_MUZZLE_LOCAL)
	return global_position + Vector3(0.0, 1.0, 0.0)


func _aim_gun_at_player() -> void:
	if _gun_root == null or not is_instance_valid(_gun_root):
		return
	var target := _player_aim_point()
	_gun_root.look_at(target, Vector3.UP)
	## look_at points −Z at the player; barrel extends along −Z.
	_gun_root.rotate_object_local(Vector3.RIGHT, deg_to_rad(GUN_AIM_PITCH))
	_gun_root.rotate_object_local(Vector3.FORWARD, deg_to_rad(GUN_AIM_ROLL))


func _sync_gun_pose(aiming: bool) -> void:
	if _gun_root == null or not is_instance_valid(_gun_root):
		return
	_gun_root.scale = Vector3.ONE
	_gun_root.position = GUN_HAND_OFFSET
	if aiming:
		_aim_gun_at_player()
	else:
		_gun_root.rotation_degrees = GUN_LOCAL_GRIP_ROT


func _set_gun_carry(_hip: bool) -> void:
	_sync_gun_pose(false)


func _set_gun_aim(aiming: bool) -> void:
	_sync_gun_pose(aiming)
	if aiming:
		_cache_panic_bones()
		if _skeleton == null:
			return
		if _anim_player:
			_anim_player.active = false
		## Arms forward aiming pose: Z rotates arm down from T-pose, X tilts forward.
		_set_panic_bone_rot("RightArm", Vector3(deg_to_rad(-45.0), deg_to_rad(10.0), deg_to_rad(-72.0)))
		_set_panic_bone_rot("RightForeArm", Vector3(deg_to_rad(-40.0), deg_to_rad(12.0), 0.0))
		_set_panic_bone_rot("LeftArm", Vector3(deg_to_rad(-45.0), deg_to_rad(-10.0), deg_to_rad(72.0)))
		_set_panic_bone_rot("LeftForeArm", Vector3(deg_to_rad(-40.0), deg_to_rad(-12.0), 0.0))
	else:
		_reset_skeleton_pose()
		if _anim_player:
			_anim_player.active = true


func _attach_bomb_vest() -> void:
	var chest := _ensure_chest_mount()
	var parent: Node3D = chest if chest != null else _body
	if parent == null:
		return
	_bomb_vest = MeshInstance3D.new()
	_bomb_vest.name = "BombVest"
	var box := BoxMesh.new()
	box.size = Vector3(0.22, 0.28, 0.12)
	_bomb_vest.mesh = box
	## Body parent: chest height. Bone parent: local offset on chest.
	if chest != null:
		_bomb_vest.position = Vector3(0.0, -0.04, 0.10)
		_bomb_vest.scale = Vector3(0.35, 0.35, 0.35)
	else:
		_bomb_vest.position = Vector3(0.0, 0.95, 0.14)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.11, 0.10)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.32, 0.08)
	mat.emission_energy_multiplier = 1.1
	mat.roughness = 0.85
	_bomb_vest.material_override = mat
	parent.add_child(_bomb_vest)
	var blink := MeshInstance3D.new()
	var led := SphereMesh.new()
	led.radius = 0.018
	led.height = 0.036
	blink.mesh = led
	blink.position = Vector3(0.0, 0.08, 0.09)
	var led_mat := StandardMaterial3D.new()
	led_mat.emission_enabled = true
	led_mat.emission = Color(1.0, 0.15, 0.05)
	led_mat.emission_energy_multiplier = 3.0
	blink.material_override = led_mat
	_bomb_vest.add_child(blink)


func _process(delta: float) -> void:
	_bounce += delta * 3.2
	_bobble_phase += delta * 2.4
	_home_x = target_x
	if _gun_flash != null and is_instance_valid(_gun_flash):
		_gun_flash.light_energy = maxf(0.0, _gun_flash.light_energy - delta * 18.0)
	if _aim_pose_t > 0.0:
		_aim_pose_t = maxf(0.0, _aim_pose_t - delta)

	if is_ragdoll:
		_update_ragdoll(delta)
		return

	if is_bomber:
		_process_bomber(delta)
		return

	_process_gunman(delta)


func _face_travel(dx: float, dz: float) -> void:
	if absf(dx) > absf(dz) * 0.65:
		rotation_degrees.y = WALK_PLUS_X_YAW if dx > 0.0 else WALK_MINUS_X_YAW
	elif dz < -0.02:
		rotation_degrees.y = FACE_TRUCK_YAW
	elif dz > 0.02:
		rotation_degrees.y = FACE_AWAY_YAW


func _pick_next_gun_waypoint() -> void:
	_waypoints_done += 1
	var advance := randf_range(0.9, 2.4)
	if randf() < 0.3 and global_position.z > HOLD_Z_MAX + 1.0:
		advance = randf_range(0.15, 0.7)
	var next_z := maxf(HOLD_Z_MIN, global_position.z - advance)
	if next_z <= HOLD_Z_MAX:
		next_z = randf_range(HOLD_Z_MIN, HOLD_Z_MAX)
	next_z = minf(MATTE_SAFE_Z, next_z)
	var next_x := clampf(global_position.x + randf_range(-3.5, 3.5), -12.0, 8.0)
	if randf() < 0.55:
		next_x = lane_x_for(randi() % TERR_LANE_X.size()) + randf_range(-1.0, 1.0)
	target_x = next_x
	target_z = next_z
	_pause_t = 0.0
	_combat_ready = false


func _move_toward(goal_x: float, goal_z: float, delta: float, speed: float) -> bool:
	global_position.y = STAND_Y
	goal_z = minf(goal_z, MATTE_SAFE_Z)
	var dx := goal_x - global_position.x
	var dz := goal_z - global_position.z
	var dist := sqrt(dx * dx + dz * dz)
	if dist <= 0.14:
		global_position.x = goal_x
		global_position.z = goal_z
		return true
	var step := minf(dist, delta * speed)
	global_position.x += (dx / dist) * step
	global_position.z += (dz / dist) * step
	## Never slip behind / into the street painting.
	global_position.z = minf(global_position.z, MATTE_SAFE_Z)
	_face_travel(dx, dz)
	return false


func _process_bomber(delta: float) -> void:
	if _detonated:
		return
	global_position.y = STAND_Y
	if global_position.z <= BOMB_SPRINT_Z + 0.15:
		target_x = lerpf(target_x, lane_x_for(lane), delta * 2.0)
		target_z = BOMB_DETONATE_Z
		var arrived := _move_toward(target_x, BOMB_DETONATE_Z, delta, BOMB_RUN_SPEED)
		if _anim_player:
			_anim_player.active = true
			_play_anim("walk")
			_anim_player.speed_scale = 1.55
		if arrived or global_position.z <= BOMB_DETONATE_Z + 0.1:
			_detonate()
			return
	else:
		if _pause_t > 0.0:
			_pause_t -= delta
			rotation_degrees.y = FACE_TRUCK_YAW
			if _anim_player:
				_anim_player.active = true
				_play_anim("idle")
		else:
			var arrived2 := _move_toward(target_x, target_z, delta, BOMB_WALK_SPEED)
			if _anim_player:
				_anim_player.active = true
				_play_anim("walk")
				_anim_player.speed_scale = 1.05
			if arrived2:
				_waypoints_done += 1
				if target_z <= BOMB_SPRINT_Z + 0.4:
					target_z = BOMB_DETONATE_Z
				else:
					target_z = maxf(BOMB_SPRINT_Z, target_z - randf_range(3.5, 6.5))
					target_x = clampf(target_x + randf_range(-2.8, 2.8), -12.0, 8.0)
					_pause_t = randf_range(0.15, 0.45)
	if _bomb_vest != null and is_instance_valid(_bomb_vest):
		var pulse := 0.85 + sin(Time.get_ticks_msec() * 0.012) * 0.15
		var m := _bomb_vest.material_override as StandardMaterial3D
		if m != null:
			m.emission_energy_multiplier = 0.9 + pulse * 0.5
	if _bar_root:
		_bar_root.visible = false


func _in_shoot_range() -> bool:
	return global_position.z <= SHOOT_Z


func _process_gunman(delta: float) -> void:
	global_position.y = STAND_Y
	if _bar_root:
		_bar_root.visible = false

	var in_range := _in_shoot_range()
	var aiming := _aim_pose_t > 0.0
	## Bone-mounted pistol — look_at player while aiming/shooting.
	_sync_gun_pose(aiming)

	if in_range:
		_combat_ready = true
		_shoot_timer -= delta
		if _shoot_timer <= 0.0:
			_shoot_timer = SHOOT_INTERVAL
			if randf() < SHOOT_CHANCE:
				rotation_degrees.y = FACE_TRUCK_YAW
				_aim_pose_t = AIM_POSE_SEC
				_fire_at_player()
	else:
		_combat_ready = false

	if _pause_t > 0.0:
		_pause_t -= delta
		rotation_degrees.y = FACE_TRUCK_YAW
		if aiming:
			_set_gun_aim(true)
			_apply_bobble(false)
		else:
			_set_gun_aim(false)
			if _anim_player:
				_anim_player.active = true
				_play_anim("idle")
				_anim_player.speed_scale = 0.7
			_apply_bobble(false)
		if _pause_t <= 0.0:
			_pick_next_gun_waypoint()
		return

	var arrived := _move_toward(target_x, target_z, delta, GUN_WALK_SPEED)
	if aiming:
		rotation_degrees.y = FACE_TRUCK_YAW
		_set_gun_aim(true)
		_apply_bobble(false)
		if _anim_player:
			_anim_player.active = false
	else:
		if _anim_player:
			_anim_player.active = true
			_play_anim("walk")
			_anim_player.speed_scale = 0.95
		_apply_bobble(true)
	if arrived:
		_pause_t = randf_range(0.8, 1.6)


func _show_muzzle_flash() -> void:
	if _gun_flash != null and is_instance_valid(_gun_flash):
		_gun_flash.light_energy = 9.0
	if _muzzle_flash != null and is_instance_valid(_muzzle_flash):
		_muzzle_flash.visible = true
		get_tree().create_timer(0.09).timeout.connect(func():
			if is_instance_valid(_muzzle_flash):
				_muzzle_flash.visible = false
		)


func _fire_at_player() -> void:
	if is_ragdoll:
		return
	if not _in_shoot_range():
		return
	_combat_ready = true
	_set_gun_aim(true)
	_aim_gun_at_player()
	_show_muzzle_flash()
	var from := _muzzle_global()
	var target := _player_aim_point()
	var dist := from.distance_to(target)
	var hit_chance := clampf(0.42 - dist * 0.014, 0.14, 0.48)
	var dmg := 0.0
	if randf() < hit_chance:
		dmg = randf_range(6.0, 14.0)
	shot_player.emit(dmg)
	if _bubble:
		_bubble.text = "GET DOWN!" if dmg > 0.0 else "BANG!"
		_bubble.visible = true
		_bubble.modulate = Color(1.0, 0.35, 0.3)
	get_tree().create_timer(0.45).timeout.connect(func():
		if is_instance_valid(self) and _bubble and not is_ragdoll:
			_bubble.visible = false
	)


func _detonate() -> void:
	if _detonated:
		return
	_detonated = true
	var at := global_position + Vector3(0.0, 0.88, 0.04)
	detonated.emit(randf_range(22.0, 42.0), at)
	if _bomb_vest != null and is_instance_valid(_bomb_vest):
		_bomb_vest.visible = false
	if _gun_root != null and is_instance_valid(_gun_root):
		_gun_root.visible = false
	visible = false
	queue_free()


func get_shot(shot_from: Vector3, shot_dir: Vector3) -> bool:
	if is_bomber and not _detonated and global_position.z < HOLD_Z_MAX + 2.0:
		_detonate()
		return true
	if _gun_root != null and is_instance_valid(_gun_root):
		_gun_root.visible = false
	var first_hit := super.get_shot(shot_from, shot_dir)
	if is_ragdoll:
		## Softer tumble, then a flat sprawled pose instead of noodly flailing.
		_ragdoll_ang *= 0.5
		_ragdoll_vel.x = clampf(_ragdoll_vel.x, -5.5, 5.5)
		_ragdoll_vel.z = clampf(_ragdoll_vel.z, -1.5, 7.5)
		_apply_flat_ragdoll_pose(1.0)
	return first_hit


func _apply_flat_ragdoll_pose(settle: float) -> void:
	## Sprawled on back — arms out, no sine wobble.
	_cache_panic_bones()
	_cache_skeleton()
	if _skeleton == null:
		return
	var s := clampf(settle, 0.0, 1.0)
	_skeleton.reset_bone_poses()
	_set_panic_bone_rot("RightArm", Vector3(deg_to_rad(-10.0 * s), deg_to_rad(6.0 * s), deg_to_rad(88.0 * s)))
	_set_panic_bone_rot("RightForeArm", Vector3(deg_to_rad(-18.0 * s), deg_to_rad(4.0 * s), deg_to_rad(8.0 * s)))
	_set_panic_bone_rot("RightHand", Vector3(deg_to_rad(-6.0 * s), 0.0, deg_to_rad(12.0 * s)))
	_set_panic_bone_rot("LeftArm", Vector3(deg_to_rad(-10.0 * s), deg_to_rad(-6.0 * s), deg_to_rad(-88.0 * s)))
	_set_panic_bone_rot("LeftForeArm", Vector3(deg_to_rad(-18.0 * s), deg_to_rad(-4.0 * s), deg_to_rad(-8.0 * s)))
	_set_panic_bone_rot("LeftHand", Vector3(deg_to_rad(-6.0 * s), 0.0, deg_to_rad(-12.0 * s)))
	_set_panic_bone_rot("Spine", Vector3(deg_to_rad(4.0 * s), 0.0, 0.0))
	_set_panic_bone_rot("Chest", Vector3(deg_to_rad(3.0 * s), 0.0, 0.0))
	_set_panic_bone_rot("UpperChest", Vector3(deg_to_rad(2.0 * s), 0.0, 0.0))
	_set_panic_bone_rot("Neck", Vector3(deg_to_rad(-6.0 * s), 0.0, 0.0))
	_set_panic_bone_rot("Head", Vector3(deg_to_rad(-4.0 * s), 0.0, 0.0))


func _update_ragdoll(delta: float) -> void:
	_ragdoll_t += delta
	var twisting := _ragdoll_t < TERR_RAGDOLL_TWIST_SEC
	var active := _ragdoll_t < TERR_RAGDOLL_ACTIVE_SEC
	var settle := 1.0 if twisting else clampf((_ragdoll_t - TERR_RAGDOLL_TWIST_SEC) * 3.0, 0.0, 1.0)
	_apply_flat_ragdoll_pose(settle)

	_ragdoll_vel.y -= 15.5 * delta
	global_position += _ragdoll_vel * delta

	if twisting:
		rotation_degrees.x += _ragdoll_ang.x * delta * 0.42
		rotation_degrees.y += _ragdoll_ang.y * delta * 0.48
		rotation_degrees.z += _ragdoll_ang.z * delta * 0.3
	else:
		_ragdoll_lie = minf(1.0, _ragdoll_lie + delta * 2.4)
		var flat_x := TERR_FLAT_PITCH * _ragdoll_lie
		rotation_degrees.x = lerpf(rotation_degrees.x, flat_x, 1.0 - exp(-delta * 6.0))
		rotation_degrees.z = lerpf(rotation_degrees.z, 0.0, 1.0 - exp(-delta * 5.0))
		_ragdoll_ang.y *= 1.0 - delta * 4.5

	if _body:
		## Keep all flattening on the root — avoids torso/feet splitting heights.
		_body.rotation_degrees = Vector3.ZERO
		_body.position.y = _base_body_y

	if global_position.z > MATTE_FRONT_Z_MAX:
		global_position.z = MATTE_FRONT_Z_MAX
		_ragdoll_vel.z = -absf(_ragdoll_vel.z) * 0.35

	var ground_y := STAND_Y
	if _ragdoll_lie > 0.7:
		ground_y = STAND_Y + TERR_FLAT_Y_OFFSET * _ragdoll_lie

	if global_position.y < ground_y:
		global_position.y = ground_y
		if _ragdoll_vel.y < 0.0:
			_ragdoll_vel.y *= -0.08
			_ragdoll_vel.x *= 0.55
			_ragdoll_vel.z *= 0.55
			_ragdoll_ang *= 0.35
			if absf(_ragdoll_vel.y) < 0.35:
				_ragdoll_vel.y = 0.0

	_ragdoll_ang *= 1.0 - delta * (2.2 if twisting else (4.0 if active else 8.0))
	_ragdoll_vel.x *= 1.0 - delta * (1.4 if active else 4.0)
	_ragdoll_vel.z *= 1.0 - delta * (1.2 if active else 4.0)

	if not active and _ragdoll_t > TERR_RAGDOLL_ACTIVE_SEC + RAGDOLL_DESPAWN_SEC:
		queue_free()
	if global_position.y < -2.0:
		queue_free()
