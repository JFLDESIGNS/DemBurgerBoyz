extends Node
## A small, interruptible snack reaction, independent of burger/order eating.
const DURATION := 1.18
var game: Node
var subject: Node3D
var mouth: MeshInstance3D
var original := Transform3D.IDENTITY
var center := Vector3.ZERO
var material: ShaderMaterial
var old_round := 0.0
var temporary_mouth := false
var food: MeshInstance3D
var food_scale := Vector3.ONE
var hit := Vector3.ZERO
var reach := Vector3.ZERO
var elapsed := 0.0
var finished := false
var voiced := false
var body: Node3D
var body_home_y := 0.0
var body_drop := 0.0

static func accepts(id: String, is_cat: bool, roll: float) -> bool:
	if id in ["bacon", "cheese"]: return is_cat or roll < .80
	return roll < .25

func setup(owner_game: Node, eater: Node3D, id: String, at: Vector3) -> void:
	game = owner_game
	subject = eater
	hit = at
	# Stop speech before taking over the same mouth shader.
	var speech = subject.get_node_or_null("MouthSpeech")
	if speech != null:
		speech.stop()
		speech.set_process(false)
	for mesh in subject.find_children("*Mouth", "MeshInstance3D", true, false):
		if mesh.is_visible_in_tree() and not mesh.is_queued_for_deletion() and mesh.mesh != null:
			mouth = mesh
			break
	if mouth == null:
		# The cat's face has no separate mouth mesh: add a tiny chewing oval.
		mouth = MeshInstance3D.new()
		mouth.name = "SnackMouth"
		var sphere := SphereMesh.new()
		sphere.radius = .045
		sphere.height = .09
		mouth.mesh = sphere
		var ink := StandardMaterial3D.new()
		ink.albedo_color = Color("241620")
		ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mouth.material_override = ink
		subject.add_child(mouth)
		mouth.scale = Vector3(1.0, .55, .22)
		if subject.has_method("side_food_mouth_global"):
			mouth.global_position = subject.side_food_mouth_global()
		else:
			var left = subject.find_child("Cat_Eye_L", true, false) as MeshInstance3D
			var right = subject.find_child("Cat_Eye_R", true, false) as MeshInstance3D
			var body = subject.find_child("Cat_Body", true, false) as Node3D
			if left != null and right != null and body != null:
				var a := left.to_global(left.get_aabb().get_center())
				var b := right.to_global(right.get_aabb().get_center())
				var eye_span := a.distance_to(b)
				mouth.reparent(body)
				mouth.global_position = (a+b)*.5 + subject.global_basis.orthonormalized()*Vector3(0,-eye_span*.68,eye_span*.53)
			else:
				mouth.position = Vector3(0, .34, .22)
		temporary_mouth = true
	original = mouth.transform
	center = mouth.get_aabb().get_center()
	if mouth.material_override is ShaderMaterial:
		material = mouth.material_override
		var value = material.get_shader_parameter("speech_round")
		old_round = float(value) if value != null and speech == null else 0.0
	var home := mouth.to_global(center)
	if subject.has_method("side_food_mouth_global"):
		body = subject.get("_body") as Node3D
		if is_instance_valid(body):
			body_home_y = body.position.y
			body_drop = clampf(at.y-home.y, -.14, 0.0)
	food = game._make_thrown_ingredient_card(id, game.FoodSpritesScript.get_tex(id))
	game.world.add_child(food)
	food.global_position = at
	food_scale = food.scale
	set_process(true)
	sample(0.0)

func sample(age: float) -> void:
	if finished or not is_instance_valid(mouth): return
	var reach_amount := smoothstep(0.0, .16, age) * (1.0-smoothstep(.35, .91, age))
	var chew_time := clampf((age-.18)/.78, 0.0, 1.0)
	var chew := sin(chew_time*PI*3.0)
	chew = absf(chew) if age >= .18 and age < .96 else 0.0
	var jaw_scale := Vector3(1.0-.07*chew, 1.0+.40*chew, 1.0)
	var moved := original
	moved.basis = original.basis.scaled_local(jaw_scale)
	moved.origin += original.basis * (center-center*jaw_scale)
	if is_instance_valid(body): body.position.y = body_home_y + body_drop * reach_amount
	mouth.transform = moved
	if material != null: material.set_shader_parameter("speech_round", .80*chew)
	if is_instance_valid(food):
		var destination := mouth.to_global(center)
		food.global_position = hit.lerp(destination, smoothstep(0.0, .20, age))
		# Bite-size steps disappear into the mouth on each closing beat.
		var bites := clampf(floorf(chew_time*3.0)/3.0, 0.0, 1.0)
		food.scale = food_scale * maxf(.001, 1.0-bites)
		food.visible = age < .96
		if is_instance_valid(game.camera):
			food.look_at(game.camera.global_position, Vector3.UP)
			food.rotate_object_local(Vector3.UP, PI)

func _process(delta: float) -> void:
	if finished: return
	if not is_instance_valid(subject) or not is_instance_valid(mouth):
		finish()
		queue_free()
		return
	elapsed += delta
	if elapsed >= .16 and not voiced:
		voiced = true
		if is_instance_valid(game.game_audio):
			var voice: String = subject.get_customer_voice() if subject.has_method("get_customer_voice") else "male"
			var cat_voice: bool = subject == game.window_cat or bool(subject.get("is_disguise_cat")) if subject.has_method("get_customer_voice") else subject == game.window_cat
			game.game_audio.play_customer_nom_nom("female" if cat_voice else voice, subject, 1.55 if cat_voice else 1.0)
	sample(elapsed)
	if elapsed >= DURATION:
		finish()
		queue_free()

func finish() -> void:
	if finished: return
	finished = true
	set_process(false)
	if is_instance_valid(body): body.position.y = body_home_y
	if is_instance_valid(mouth):
		mouth.transform = original
		if temporary_mouth:
			mouth.get_parent().remove_child(mouth)
			mouth.queue_free()
	if is_instance_valid(material): material.set_shader_parameter("speech_round", old_round)
	if is_instance_valid(food): food.queue_free()

func _exit_tree() -> void:
	finish()
