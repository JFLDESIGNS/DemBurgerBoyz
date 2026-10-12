extends Node3D
## Host-driven wildlife with replicated poses and sound events.
const BIRD_SCENE: PackedScene = preload("res://models/park_bird/park_bird.glb")
const HOUSE_SCENE: PackedScene = preload("res://models/park_bird/birdhouse.glb")
const HOUSE_SCALE := 0.32 # Asset itself already includes the requested 1.2 enlargement.
const BIRD_SCALE := 0.22
const PERCH := Vector3(0.01536, 0.205, 0.37)
const CLIPS := [&"Idle", &"Fly", &"Perch", &"Mad_Peck", &"Takeoff"]
signal sound_triggered(kind: StringName)
const CHIRP = preload("res://sounds/park_bird/chirp.wav")
const PECK = preload("res://sounds/park_bird/peck.wav")
const WINGS = preload("res://sounds/park_bird/wings.wav")
const LAUNCH := Vector3(0.16, 0.30, 0.30)
const DISTANT := Vector3(8.0, 3.5, 5.0)
const APPROACH := Vector3(-7.0, 3.0, 5.0)
const LANDING := Vector3(-0.25, 0.25, 0.35)
const PLUMAGE := [
	[Color(0.16, 0.32, 0.74), Color(0.055, 0.115, 0.32)], # Blue
	[Color("F3BE46"), Color("A56424")], # Golden
	[Color("EE786B"), Color("8C3E56")], # Coral
]
var color_variant := -1
var plumage_materials: Array[Dictionary] = []
var game: Node
var network_pose: Dictionary = {}
var sound_serial := 0
var sound_kind := ""
var received_sound := -1
var network_send_left := 0.0
var network_drag_left := 0.0
var network_drag_target := Vector2.ZERO
var sway: Node3D
var sway_time := 0.0
var swing := Vector2.ZERO
var swing_velocity := Vector2.ZERO
var dragging_house := false
var drag_origin := Vector2.ZERO
var drag_swing := Vector2.ZERO
var tap_cooldown := 0.0
var voice: AudioStreamPlayer3D
var wing_sound: AudioStreamPlayer3D
var tap_sound: AudioStreamPlayer3D
var idle_duration := 10.0
var away_duration := 8.0
var chirp_at := 2.0
var _rng := RandomNumberGenerator.new()
var bird: Node3D
var house: Node3D
var animator: AnimationPlayer
var state: StringName = &"Idle"
var state_time := 0.0
var enabled := true
var cycle := 0
var _flight_start := PERCH

func _ready() -> void:
	sway = Node3D.new()
	sway.name = "HangingSway"
	add_child(sway)
	house = HOUSE_SCENE.instantiate() as Node3D
	house.name = "House"
	house.scale = Vector3.ONE * HOUSE_SCALE
	sway.add_child(house)
	var hanger := MeshInstance3D.new()
	hanger.name = "BranchHanger"
	var cord := CylinderMesh.new()
	cord.top_radius = 0.006
	cord.bottom_radius = 0.006
	cord.height = 0.40
	hanger.mesh = cord
	hanger.position = Vector3(0.061, 1.04, 0.0)
	var cord_mat := StandardMaterial3D.new()
	cord_mat.albedo_color = Color(0.32, 0.20, 0.10)
	hanger.material_override = cord_mat
	sway.add_child(hanger)
	bird = BIRD_SCENE.instantiate() as Node3D
	bird.name = "Bird"
	bird.scale = Vector3.ONE * BIRD_SCALE
	bird.position = PERCH
	bird.rotation.y = 0.0
	sway.add_child(bird)
	for mesh in bird.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var original = mesh.get_active_material(surface)
			if not original is StandardMaterial3D: continue
			var wing: bool = original.resource_name.begins_with("Wing blue")
			if not wing and not original.resource_name.begins_with("Bird blue"): continue
			var material = original.duplicate()
			mesh.set_surface_override_material(surface, material)
			plumage_materials.append({"material":material,"wing":wing})
	_apply_color_variant(0)
	animator = bird.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert(animator != null, "Park bird needs an AnimationPlayer")
	for clip in CLIPS:
		assert(animator.has_animation(clip), "Missing park bird animation: %s" % clip)
	for clip in [&"Idle", &"Fly"]:
		animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_rng.randomize()
	voice = _audio_player("Chirp", CHIRP, -2.0)
	tap_sound = _audio_player("Peck", PECK, 0.0)
	var loop_wings = WINGS.duplicate() as AudioStreamWAV
	loop_wings.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop_wings.loop_end = int(loop_wings.get_length() * loop_wings.mix_rate)
	wing_sound = _audio_player("Wings", loop_wings, -4.0)
	wing_sound.pitch_scale = 1.7
	_enter(&"Away")
	away_duration = _rng.randf_range(27.0, 33.0)

func _apply_color_variant(value: int) -> void:
	value = clampi(value, 0, PLUMAGE.size() - 1)
	if color_variant == value: return
	color_variant = value
	for entry in plumage_materials:
		entry.material.albedo_color = PLUMAGE[value][1 if entry.wing else 0]

func _audio_player(label: String, stream: AudioStream, level: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.name = label
	player.stream = stream
	player.bus = &"SFX"
	player.volume_db = level
	player.unit_size = 6.0
	player.max_distance = 22.0
	sway.add_child(player)
	return player

func _chirp() -> void:
	if is_instance_valid(game) and game.mp_enabled and not NetManager.is_host(): return
	voice.position = bird.position
	voice.pitch_scale = _rng.randf_range(1.05, 1.22)
	voice.play()
	sound_serial += 1; sound_kind = "chirp"
	sound_triggered.emit(&"chirp")

func set_enabled(value: bool) -> void:
	if enabled == value:
		return
	enabled = value
	visible = value
	if not value: dragging_house = false
	set_process(value)
	if animator != null:
		if value:
			_enter(&"Away")
		else:
			animator.pause()
			voice.stop()
			wing_sound.stop()
			tap_sound.stop()

func react_to_tree_shake() -> void:
	if enabled and state == &"Idle":
		_enter(&"Mad_Peck")

func _enter(next: StringName) -> void:
	state = next
	state_time = 0.0
	bird.visible = next != &"Away"
	animator.speed_scale = 1.0
	if next in [&"Idle", &"Mad_Peck"]:
		bird.position = PERCH
		bird.rotation.y = 0.0
	if next == &"Idle":
		idle_duration = _rng.randf_range(4.0, 6.0)
		chirp_at = _rng.randf_range(1.2, 2.8)
	if next == &"Away":
		away_duration = _rng.randf_range(21.0, 25.0)
		animator.pause()
		voice.stop()
		wing_sound.stop()
		return
	var clip := next
	if next == &"Fly_In":
		if not is_instance_valid(game) or not game.mp_enabled or NetManager.is_host():
			_apply_color_variant((color_variant + _rng.randi_range(1, 2)) % PLUMAGE.size())
		clip = &"Fly"
		bird.position = PERCH + APPROACH
	if next in [&"Takeoff", &"Fly", &"Fly_In", &"Perch"]:
		animator.speed_scale = 2.5
		if next == &"Takeoff":
			animator.speed_scale = 0.75 / 0.22
			_flight_start = bird.position
		if next == &"Perch": animator.speed_scale = 1.25 / 0.4
		if not wing_sound.playing:
			wing_sound.position = bird.position
			wing_sound.play()
			sound_triggered.emit(&"wings")
	else:
		wing_sound.stop()
	if next in [&"Takeoff", &"Fly_In"]: _chirp()
	animator.play(clip, 0.05)

func _process(delta: float) -> void:
	if is_instance_valid(game) and game.mp_enabled and not NetManager.is_host():
		network_send_left -= delta
		tap_cooldown = maxf(0.0,tap_cooldown-delta)
		if dragging_house:
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and network_send_left <= 0.0:
				network_send_left = .05
				var pull := get_viewport().get_mouse_position() - drag_origin
				game.mp_bird_interact.rpc_id(1,"drag",(drag_swing + Vector2(pull.y,-pull.x)*.002).clamp(Vector2(-.12,-.16),Vector2(.12,.16)))
			elif not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): dragging_house = false
		if not network_pose.is_empty():
			bird.position = bird.position.lerp(network_pose.position, minf(1.0,delta*18.0))
			bird.rotation.y = lerp_angle(bird.rotation.y,float(network_pose.yaw),minf(1.0,delta*18.0))
			sway.transform = sway.transform.interpolate_with(network_pose.sway,minf(1.0,delta*18.0))
			voice.position = bird.position
			wing_sound.position = bird.position
		return
	advance(delta)
	if is_instance_valid(game) and game.mp_enabled and NetManager.is_host():
		network_send_left -= delta
		if network_send_left <= 0.0:
			network_send_left = .05
			game.mp_bird_snapshot.rpc(network_snapshot())

func _move_flying(offset: Vector3) -> void:
	var destination := PERCH + offset
	var direction := destination - bird.position
	if direction.length_squared() > 0.000001:
		bird.rotation.y = atan2(direction.z, -direction.x)
	bird.position = destination

func advance(delta: float) -> void:
	if not enabled or bird == null: return
	sway_time += delta
	tap_cooldown = maxf(0.0, tap_cooldown - delta)
	if dragging_house and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): dragging_house = false
	network_drag_left = maxf(0.0,network_drag_left-delta)
	var target := network_drag_target if network_drag_left > 0.0 else Vector2.ZERO
	if dragging_house:
		var pull := get_viewport().get_mouse_position() - drag_origin
		target = (drag_swing + Vector2(pull.y, -pull.x) * 0.002).clamp(Vector2(-0.12, -0.16), Vector2(0.12, 0.16))
	# Substeps keep the spring stable through frame hitches.
	var remaining := minf(delta, 0.25)
	while remaining > 0.0:
		var step := minf(remaining, 1.0 / 120.0)
		swing_velocity += ((target - swing) * 28.0 - swing_velocity * (8.0 if dragging_house or network_drag_left > 0.0 else 0.85)) * step
		swing += swing_velocity * step
		remaining -= step
	sway.rotation = Vector3(sin(sway_time * 1.1) * 0.009 + swing.x, 0.0, sin(sway_time * 1.4) * 0.014 + swing.y)
	var anchor := Vector3(0.061, 1.24, 0.0)
	sway.position = anchor - sway.basis * anchor
	var previous := state_time
	state_time += delta
	match state:
		&"Idle":
			if previous < chirp_at and state_time >= chirp_at: _chirp()
			if state_time >= idle_duration: _enter(&"Takeoff")
		&"Takeoff":
			var t := clampf(state_time / 0.22, 0.0, 1.0)
			_move_flying(LAUNCH * t * t)
			if t >= 1.0: _enter(&"Fly")
		&"Fly":
			var t := clampf(state_time / 0.9, 0.0, 1.0)
			_move_flying(LAUNCH.lerp(DISTANT, t))
			if t >= 1.0: _enter(&"Away")
		&"Away":
			if state_time >= away_duration: _enter(&"Fly_In")
		&"Fly_In":
			var t := clampf(state_time / 1.1, 0.0, 1.0)
			_move_flying(APPROACH.lerp(LANDING, t))
			if t >= 1.0: _enter(&"Perch")
		&"Perch":
			var t := clampf(state_time / 0.4, 0.0, 1.0)
			var ease := t * t * (3.0 - 2.0 * t)
			bird.position = PERCH + LANDING * (1.0 - ease)
			bird.rotation.y = lerp_angle(atan2(-LANDING.z, LANDING.x), 0.0, ease)
			if t >= 1.0:
				swing_velocity += Vector2(0.28, 0.48)
				cycle += 1
				_chirp()
				_enter(&"Mad_Peck" if cycle % 2 == 1 else &"Idle")
		&"Mad_Peck":
			var turn := minf(state_time / 0.25, (2.0 - state_time) / 0.25)
			bird.rotation.y = -PI / 2.0 * clampf(turn, 0.0, 1.0)
			# Head strikes peak three times in the two-second Blender action.
			for hit in [1.0 / 6.0, 5.0 / 6.0, 1.5]:
				if previous < hit and state_time >= hit:
					tap_sound.position = PERCH
					tap_sound.pitch_scale = _rng.randf_range(1.3, 1.5)
					tap_sound.play()
					sound_serial += 1; sound_kind = "peck"
					sound_triggered.emit(&"peck")
			if state_time >= 2.0: _enter(&"Idle")
	wing_sound.position = bird.position
	voice.position = bird.position

func tap_at(camera: Camera3D, screen_position: Vector2) -> bool:
	if not enabled or not is_visible_in_tree(): return false
	if bird.visible and _mesh_hit(bird, camera, screen_position):
		if tap_cooldown <= 0.0:
			if is_instance_valid(game) and game.mp_enabled: game.mp_bird_interact.rpc_id(1,"chirp",Vector2.ZERO)
			else: _chirp()
			tap_cooldown = 0.25
		return true
	if _mesh_hit(house, camera, screen_position):
		if is_instance_valid(game) and game.mp_enabled: game.mp_bird_interact.rpc_id(1,"tap",Vector2.ZERO)
		else: swing_velocity.y = clampf(swing_velocity.y + 0.42, -0.6, 0.6)
		dragging_house = true
		drag_origin = screen_position
		drag_swing = swing
		return true
	return false

func _mesh_hit(target: Node3D, camera: Camera3D, point: Vector2) -> bool:
	var start := camera.project_ray_origin(point)
	var end := start + camera.project_ray_normal(point) * 50.0
	for node in target.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not mesh.is_visible_in_tree() or mesh.mesh == null: continue
		var inverse := mesh.global_transform.affine_inverse()
		if mesh.get_aabb().grow(0.015).intersects_segment(inverse * start, inverse * end) != null:
			return true
	return false

func network_snapshot() -> Dictionary:
	return {"state":str(state),"time":state_time,"position":bird.position,"yaw":bird.rotation.y,"sway":sway.transform,"visible":bird.visible,"enabled":enabled,"sound":sound_kind,"serial":sound_serial,"variant":color_variant}

func apply_network_snapshot(data: Dictionary) -> void:
	if bird == null or data.is_empty(): return
	set_enabled(bool(data.enabled))
	if state != StringName(data.state): _enter(StringName(data.state))
	_apply_color_variant(int(data.get("variant",0)))
	state_time = float(data.time)
	if animator.is_playing(): animator.seek(state_time*animator.speed_scale,true)
	bird.visible = bool(data.visible)
	if network_pose.is_empty(): bird.position = data.position; sway.transform = data.sway
	network_pose = data
	if received_sound >= 0 and int(data.serial) != received_sound:
		if data.sound == "chirp": voice.position = bird.position; voice.play()
		elif data.sound == "peck": tap_sound.play()
	received_sound = int(data.serial)
