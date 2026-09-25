extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	create_timer(100).timeout.connect(func():push_error("BRIGHT_MENU_TIMEOUT");quit(1))
	var intro=load("res://scenes/boot_intro.tscn").instantiate()
	root.add_child(intro);current_scene=intro
	var music=root.get_node("IntroBootMusic")
	assert(music.intro_voice_play_count==0)
	while not intro._requested_menu: await process_frame
	assert(music.intro_voice_play_count==1 and music.intro_voice.playing)
	intro.skip_intro()
	assert(music.intro_voice_play_count==1,"Repeated skip cannot retrigger the voice")
	while current_scene==intro: await process_frame
	var game=current_scene
	assert(game.menu_ready and not game._kitchen_ready)
	var backdrop=game.start_overlay.get_node("DinerBackdrop")
	assert(backdrop.street_art!=null)
	assert(game.start_btn.is_visible_in_tree() and game.multiplayer_btn.is_visible_in_tree())
	root.mode=Window.MODE_WINDOWED
	for resolution in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=resolution
		for i in 12: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/bright_menu_release/menu_%d.png"%resolution.x)
		var creator=game.start_overlay.find_child("CharacterCreatorButton",true,false)
		assert(creator.get_global_rect().end.y<root.get_visible_rect().size.y-25,"All menu choices must fit")
	print("BRIGHT_MENU_OK natural intro voice once, menu art, 720p and 1080p")
	quit()
