extends Control
var camera: Camera3D
func setup() -> void:
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
	camera.size = 2.35
	camera.position = Vector3(0, 1.1, 5)
	world.add_child(camera)
	camera.look_at(Vector3(0, 1.1, 0))
	var pal = load("res://scripts/customer.gd").new()
	pal.is_street_pedestrian = true
	pal.set_meta("delivery_driver", true)
	pal.setup(["bun_bottom", "patty", "bun_top"] as Array[String], Color("EF9964"), 9999.0, 0, 0, -1, -1, {}, true)
	world.add_child(pal)
	pal.set_process(false)
	pal.set_physics_process(false)
	pal.rotation.y = .2
	if pal._anim_player != null and pal._anim_player.has_animation("kenney/Idle"):
		pal._anim_player.play("kenney/Idle")

