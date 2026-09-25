extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var patty = load("res://scripts/patty.gd")
	var shader: Shader = patty._frozen_ball_shader_resource(true)
	assert(not shader.code.contains("ALPHA ="))
	assert(shader.code.contains("unshaded"))
	assert(patty._frozen_ball_shader_resource(false).code.contains("ALPHA ="))
	var scene := Node3D.new()
	root.add_child(scene)
	var ball: Node3D = patty.make_standalone_frozen_ball()
	scene.add_child(ball)
	ball.position.y = 0.10
	assert(ball.get_node("Meat").cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	var plane := MeshInstance3D.new()
	plane.mesh = PlaneMesh.new()
	scene.add_child(plane)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35,-40,0)
	light.shadow_enabled = true
	light.shadow_normal_bias = 0.2
	scene.add_child(light)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(0.5,0.45,0.65)
	camera.look_at(Vector3(0,0.04,0))
	root.size = Vector2i(640,480)
	for i in 10: await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/light_balance_release/ball_shadow.png")
	print("BALL_SHADOW_OK opaque bright core, translucent frost, shadow caster")
	quit()
