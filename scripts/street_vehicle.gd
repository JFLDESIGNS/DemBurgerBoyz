## Animated 3D street traffic. Models face +X and rest on local Y = 0.
extends Node3D

const MODEL_PATHS := [
	"res://assets/vehicles/sugar_street/lagoon_hatch.glb",
	"res://assets/vehicles/sugar_street/guava_micro.glb",
	"res://assets/vehicles/sugar_street/blueberry_estate.glb",
	"res://assets/vehicles/sugar_street/custard_pickup.glb",
	"res://assets/vehicles/sugar_street/pistachio_van.glb",
	"res://assets/vehicles/sugar_street/tangerine_flatbed.glb",
	"res://assets/vehicles/sugar_street/wisteria_box_truck.glb",
]
const WHEEL_RADII := [0.385, 0.365, 0.4, 0.435, 0.415, 0.46, 0.45]
const DRIVE_CLIP := "DriveLoop"
var models: Array[Node3D] = []
var players: Array[AnimationPlayer] = []
var model_bounds: Array[AABB] = []
var variant_index: int = -1
var _material_colors: Array = []
var _darken: float = -1.0

func set_pool(packed_scenes: Array, spread_frames: bool = false) -> void:
	if not models.is_empty():
		return
	for packed in packed_scenes:
		var model := (packed as PackedScene).instantiate() as Node3D
		if model == null:
			continue
		add_child(model)
		model.visible = false
		models.append(model)
		if spread_frames: await get_tree().process_frame
		var mesh_count := 0
		for item in model.find_children("*", "MeshInstance3D", true, false):
			mesh_count += 1
			if spread_frames and mesh_count % 8 == 0: await get_tree().process_frame
			var mesh := item as MeshInstance3D
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			for surface in mesh.mesh.get_surface_count():
				var original := mesh.get_active_material(surface) as StandardMaterial3D
				if original == null:
					continue
				var material := original.duplicate() as StandardMaterial3D
				mesh.set_surface_override_material(surface, material)
				_material_colors.append([material, material.albedo_color])
		var animations := model.find_children("*", "AnimationPlayer", true, false)
		var player: AnimationPlayer = animations[0] as AnimationPlayer if not animations.is_empty() else null
		players.append(player)
		if player != null and player.has_animation(DRIVE_CLIP):
			player.get_animation(DRIVE_CLIP).loop_mode = Animation.LOOP_LINEAR
			player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			player.play(DRIVE_CLIP)
			player.advance(0.0)
		else:
			push_error("Street vehicle is missing its Blender DriveLoop animation: " + model.name)
		model_bounds.append(_measure(model))
		if spread_frames: await get_tree().process_frame
	if not models.is_empty():
		set_variant(0)

func _measure(model: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for item in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := item as MeshInstance3D
		var relative := model.global_transform.affine_inverse() * mesh.global_transform
		var part: AABB = relative * mesh.get_aabb()
		bounds = part if first else bounds.merge(part)
		first = false
	return bounds

func set_variant(index: int) -> void:
	if index < 0 or index >= models.size():
		return
	for i in models.size():
		models[i].visible = i == index
	variant_index = index
	reset_pose()

func reset_pose() -> void:
	if variant_index < 0:
		return
	var player := players[variant_index]
	if player != null and player.has_animation(DRIVE_CLIP):
		player.play(DRIVE_CLIP)
		player.seek(0.0, true)

func get_bounds() -> AABB:
	return model_bounds[variant_index] if variant_index >= 0 else AABB()

func face_direction(direction: float) -> void:
	rotation.y = 0.0 if direction > 0.0 else PI

func advance_driving(delta: float, world_speed: float) -> void:
	if variant_index < 0 or delta <= 0.0 or world_speed <= 0.0:
		return
	var player := players[variant_index]
	if player == null:
		return
	# Authored clip rolls four turns over two seconds. Match contact speed after scaling.
	var reference_speed: float = WHEEL_RADII[variant_index] * TAU * 2.0 * absf(scale.x)
	player.advance(delta * world_speed / maxf(reference_speed, 0.001))

func set_darken(value: float) -> void:
	value = clampf(value, 0.0, 0.7)
	if is_equal_approx(value, _darken):
		return
	_darken = value
	for pair in _material_colors:
		var material := pair[0] as StandardMaterial3D
		var color: Color = pair[1]
		material.albedo_color = Color(color.r * (1.0 - value), color.g * (1.0 - value), color.b * (1.0 - value), color.a)
