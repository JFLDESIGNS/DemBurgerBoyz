extends Node3D
var cat: Node3D
var eyes: Array[ShaderMaterial] = []
var idle_time := 0.0
var leaving := false
var cinematic: Control
var home := Vector3(-1.6, 5.4, -.8)
func setup(owner_cinematic: Control) -> void:
	cinematic = owner_cinematic
	position = home
	cat = preload("res://assets/cat/shipping_cat.glb").instantiate()
	cat.name = "OpeningCat3D"
	add_child(cat)
	cat.position = Vector3.ZERO
	cat.scale = Vector3.ONE * 2.2
	cat.rotation.y = .65
	preload("res://scripts/cat_appearance.gd").apply_fur(cat)
	for part_name in ["Delivery_Box_Rig", "Postal_Cap_Rig", "Messenger_Bag_Rig", "Crossbody leather strap", "Flush strap stitching -1", "Flush strap stitching 1"]:
		var part := cat.find_child(part_name, true, false) as Node3D
		if part != null: part.hide()
	for eye_name in ["Cat_Eye_L", "Cat_Eye_R"]:
		var eye := cat.find_child(eye_name, true, false) as MeshInstance3D
		if eye != null:
			var material := ShaderMaterial.new()
			material.shader = preload("res://shaders/cat_eyes.gdshader")
			material.set_shader_parameter("pupil_gaze", Vector2.ZERO)
			eye.material_override = material
			eyes.append(material)
	var cat_animation := cat.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if cat_animation != null and cat_animation.has_animation("01_Idle"):
		cat_animation.get_animation("01_Idle").loop_mode = Animation.LOOP_LINEAR
		cat_animation.play("01_Idle")

func reset_perch() -> void:
	leaving = false
	position = home
	cat.rotation.y = .65
	var animation := cat.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation != null:
		animation.speed_scale = 1.0
		animation.play("01_Idle")
	show()

func leave_before_truck() -> void:
	if leaving:return
	leaving = true
	var game := get_tree().current_scene
	if game != null and is_instance_valid(game.get("game_audio")):
		game.game_audio.play_cat_chirp()
		game.game_audio.play_spatula_whoosh()
	var start := position
	var exit := Vector3(10.5, 3.7, -4.0)
	var tween := create_tween()
	tween.tween_method(func(t: float):
		var travel := t * t
		position = start.lerp(exit, travel) + Vector3(0, sin(t * PI) * 1.5, 0)
		cat.rotation.z = -sin(t * PI) * .35
		cat.rotation.y = lerp_angle(.65, PI * .5, t)
	, 0.0, 1.0, .85)
	await tween.finished
	hide()

func _process(delta: float) -> void:
	if not is_instance_valid(cat) or not is_visible_in_tree() or leaving:return
	idle_time += delta
	cat.rotation.z = sin(idle_time * 1.6) * .025
	cat.scale = Vector3(1.0 + sin(idle_time * 2.0) * .012, 1.0 - sin(idle_time * 2.0) * .012, 1.0) * 2.2
	var screen: Vector2 = cinematic.camera.unproject_position(global_position + Vector3(0, .9, 0))
	var target: Vector2 = cinematic.get_local_mouse_position() - screen
	var gaze := Vector2(target.x, -target.y).limit_length(200.0) * .0005
	for material in eyes:
		var current: Vector2 = material.get_shader_parameter("pupil_gaze")
		material.set_shader_parameter("pupil_gaze", current.lerp(gaze, 1.0 - exp(-12.0 * delta)))
