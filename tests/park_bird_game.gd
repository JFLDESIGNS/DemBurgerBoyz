extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	create_timer(240).timeout.connect(func(): push_error("PARK_BIRD_GAME_TIMEOUT"); quit(1))
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(1280,720)
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	while not game.menu_ready: await process_frame
	print("PARK_BIRD_MENU_READY")
	await game._start_game()
	print("PARK_BIRD_LEVEL_READY")
	game._clear_bts_day_intro(false)
	game._bts_day1_performance_done=true
	game._boss_intro_running=false
	game.spawn_timer=99999
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(1280,720)
	game.shift_paused=true
	game.current_location_id="riverside_park"
	game._apply_current_location_background_settings()
	var actor=game.park_bird_house
	assert(is_instance_valid(actor) and actor.visible)
	assert(actor.get_parent()==game.tree_front_node)
	actor.set_process(false)
	actor._enter(&"Idle")
	actor.animator.pause()
	actor.animator.seek(0,true)
	game.current_location_id="market_street"
	game._apply_current_location_background_settings()
	assert(not actor.visible)
	game.current_location_id="riverside_park"
	game._apply_current_location_background_settings()
	actor.set_process(false)
	actor._enter(&"Idle")
	actor.animator.pause()
	actor.animator.seek(0,true)
	for frame in 6:await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://output/bird_house_variants/in_game.png")
		var camera=Camera3D.new()
		game.world.add_child(camera)
		camera.global_position=actor.global_position+Vector3(.75,.55,-1.5)
		camera.look_at(actor.global_position+Vector3(0,.38,-.15))
		camera.fov=42
		camera.make_current()
		for frame in 4:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://output/bird_house_variants/tree_closeup.png")
		actor._enter(&"Fly")
		actor.advance(.8)
		actor.animator.pause()
		actor.animator.seek(.25,true)
		for frame in 4:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://output/bird_house_variants/tree_flight.png")
	print("PARK_BIRD_GAME_OK location=riverside_park parent=",actor.get_parent().name," mount=",actor.global_position," clips=",actor.animator.get_animation_list())
	quit()
