extends SceneTree
func _initialize(): call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	var game = load("res://scenes/main.tscn").instantiate()
	game.set_script(load(get_script().resource_path.get_base_dir().path_join("main_ticket_harness.gd")))
	root.add_child(game)
	for child in game.get_node("UI/Root").get_children():
		if child is CanvasItem: child.hide()
	game._build_challenge_ui()
	game.challenge_overlay.show()
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	var output := OS.get_environment("BURGER_PROBE_OUTPUT")
	root.get_texture().get_image().save_png(output.path_join("challenge_redesign.png"))
	game.challenge_overlay.hide()
	var panel := Control.new()
	game.get_node("UI/Root").add_child(panel)
	game.stations = [{"items":["bun_bottom","patty","lettuce","tomato","bun_top"]}]
	var built: Dictionary = game._build_serve_fly_stack(panel,0)
	var stack: Control = built.stack
	stack.position = Vector2(350,200)
	stack.scale = Vector2.ONE * 3.0
	for stage in [0.0,0.2,0.5,0.8,1.0]:
		for row in stack.get_children():
			if row.visible: row.get_node("LayerTexture").material.set_shader_parameter("consumed",stage)
		for frame in 3: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("burger_bites_%d.png" % roundi(stage*100)))
	print("CHALLENGE_PRESENTATION_OK")
	quit()
