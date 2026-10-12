extends Control
var cat: Node3D
var eyes: Array[ShaderMaterial] = []
var hop := 0.0
var idle_time := 0.0
var game: Node
var camera: Camera3D
func setup(owner_game: Node) -> void:
	game = owner_game
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(240, 300)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("dce9ed")
	environment.environment.ambient_light_energy = .8
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -25, 0)
	light.light_energy = 1.4
	world.add_child(light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.5
	camera.position = Vector3(0, 1.1, 5)
	world.add_child(camera)
	camera.look_at(Vector3(0, 1.1, 0))
	cat = preload("res://assets/cat/shipping_cat.glb").instantiate()
	cat.name = "OpeningCat3D"
	world.add_child(cat)
	cat.position = Vector3.ZERO
	cat.scale = Vector3.ONE * 2.145
	cat.rotation.y = 0.0
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


	game.start_btn.pressed.connect(celebrate)

func celebrate() -> void:
	hop = .65
	if is_instance_valid(game.game_audio): game.game_audio.play_cat_chirp()

func _process(delta: float) -> void:
	if not is_instance_valid(cat) or not is_visible_in_tree(): return
	idle_time += delta
	hop = maxf(0, hop - delta)
	cat.rotation.z = sin(idle_time * 1.6) * .025
	cat.scale = Vector3(1.0 + sin(idle_time * 2.0) * .012, 1.0 - sin(idle_time * 2.0) * .012, 1.0) * 2.145
	cat.position.y = sin((1.0 - hop / .65) * PI) * .6 if hop > 0 else 0.0
	var target := (get_local_mouse_position() - size * Vector2(.5, .7)) / (size * .5)
	var gaze := Vector2(target.x, -target.y).limit_length(1.0) * .1
	for material in eyes:
		var current: Vector2 = material.get_shader_parameter("pupil_gaze")
		material.set_shader_parameter("pupil_gaze", current.lerp(gaze, 1.0 - exp(-12.0 * delta)))
