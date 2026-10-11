extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	create_timer(75).timeout.connect(func():push_error("DIRECT_INTRO_TIMEOUT");quit(1))
	var intro=load("res://scenes/boot_intro.tscn").instantiate()
	root.add_child(intro);current_scene=intro
	assert(intro.get_node_or_null("PalLaboratories")==null,"Company card must not be created")
	assert(intro.cinematic.visible and intro.cinematic.video.is_playing(),"Opener must play immediately")
	assert(intro.skip_button.visible,"Skip must be available immediately")
	intro.skip_intro()
	while current_scene==intro: await process_frame
	assert(current_scene.menu_ready,"Skipping must reach a ready menu")
	await create_timer(1.5).timeout
	assert(root.get_node("IntroBootMusic").intro_voice_play_count == 1,"Intro must say Burger Pals only once")
	assert(not is_instance_valid(current_scene.burgerpals_startup_player) or not current_scene.burgerpals_startup_player.playing,"Menu must not repeat the intro voice")
	print("DIRECT_INTRO_OK")
	root.get_node("IntroBootMusic").stop()
	current_scene._loading_video.stop()
	current_scene.queue_free();current_scene=null
	for i in 8: await process_frame
	quit()
