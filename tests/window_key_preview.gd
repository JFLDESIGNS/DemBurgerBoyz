extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	create_timer(260).timeout.connect(func():push_error("WINDOW_KEY_TIMEOUT");quit(1))
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game);current_scene=game
	while not game.menu_ready: await process_frame
	await game._preload_gameplay_resources()
	await game._initialize_kitchen()
	game.start_overlay.hide()
	game._set_phone_in_truck(false)
	game.set_process(false)
	var customer=load("res://scripts/customer.gd").new()
	var order:Array[String]=["bun_bottom","patty","bun_top"]
	customer.setup(order,Color.WHITE,120,0,0,0,-1,{},true)
	game.customers_root.add_child(customer)
	customer.position=Vector3(0.55,customer.STAND_Y,2.25)
	customer.rotation.y=PI
	customer.is_waiting=true;customer.set_process(false)
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1280,720)
	var editor=game.level_editor
	for i in 3:
		editor._apply_window_key_preset(i,false)
		var light:SpotLight3D=editor._dressing.get_node("WarmWindowKey")
		assert(light.shadow_enabled and light.light_projector!=null and light.position.z>1.5)
		for frame in 12: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/window_key_release/option_%d.png"%(i+1))
	var light:SpotLight3D=editor._dressing.get_node("WarmWindowKey")
	light.hide()
	editor._dressing.get_node("WarmWindowCustomerFill").hide()
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/window_key_release/before.png")
	editor._apply_window_key_preset(0,false)
	editor._load_dressing()
	await process_frame
	light=editor._dressing.get_node("WarmWindowKey")
	assert(light.shadow_enabled and light.light_projector!=null and is_equal_approx(light.light_energy,3.4))
	editor.set_active(true)
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/window_key_release/light_menu.png")
	print("WINDOW_KEY_PREVIEW_OK three presets, shadows, persistence")
	game.queue_free()
	for frame in 8: await process_frame
	quit()
