extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	create_timer(100).timeout.connect(func():quit(1))
	var intro=load("res://scenes/boot_intro.tscn").instantiate()
	root.add_child(intro);current_scene=intro
	assert(intro.company_splash.visible and not intro.cinematic.visible)
	await create_timer(1.0).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://build/pal_loading_release/pal_splash.png"))
	await create_timer(3.0).timeout
	assert(not intro._company_done,"Company card must stay for five seconds")
	await create_timer(1.2).timeout
	assert(intro._company_done and intro.cinematic.visible and not intro.company_splash.visible)
	assert(intro.cinematic.video.is_playing())
	intro.skip_intro()
	while current_scene==intro: await process_frame
	assert(current_scene.menu_ready)
	print("PAL_SPLASH_OK")
	root.get_node("IntroBootMusic").stop()
	current_scene._loading_video.stop()
	current_scene.queue_free()
	current_scene = null
	for i in 8: await process_frame
	quit()
