extends SceneTree


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		push_error("Could not load main scene")
		quit(1)
		return
	var game := packed.instantiate()
	root.add_child(game)
	current_scene = game
	await create_timer(3.0).timeout
	if game.find_child("MuvyeButton", true, false) != null:
		push_error("Legacy main-menu MUVYE button still exists")
		quit(1)
		return
	var app_button := game.find_child("MuvyeAppButton", true, false) as Button
	var app_page := game.find_child("MuvyeApp", true, false) as Control
	if app_button == null or app_page == null:
		push_error("MUVYE phone app icon or page is missing")
		quit(1)
		return
	game.call("_set_phone_app", "muvye")
	await process_frame
	if not app_page.is_visible_in_tree():
		push_error("MUVYE phone page did not become visible")
		quit(1)
		return
	var back_button := game.find_child("PhoneNavBack", true, false) as Button
	if back_button == null or not bool(game.call("_phone_owns_pointer", back_button.get_global_rect().get_center())):
		push_error("Phone Back button is not protected from 3D cup/rack input")
		quit(1)
		return
	back_button.emit_signal("pressed")
	await process_frame
	if str(game.get("_phone_app_id")) != "home":
		push_error("Phone Back button did not return from MUVYE")
		quit(1)
		return
	game.call("_set_phone_app", "muvye")
	await process_frame
	var player := app_page.find_child("PhoneMuvyePlayer", true, false) as VideoStreamPlayer
	if player == null:
		push_error("In-phone MUVYE player was not created")
		quit(1)
		return
	if app_page.find_child("MuvyeFeaturedPoster", true, false) == null:
		push_error("MUVYE title picker is missing the featured poster")
		quit(1)
		return
	app_page.call("_play_movie", 0)
	await create_timer(0.2).timeout
	var phone_screen := game.find_child("PhoneScreen", true, false) as Control
	var player_rect := player.get_global_rect()
	if phone_screen == null or not phone_screen.get_global_rect().encloses(player_rect) or player_rect.size.x < 100.0 or player_rect.size.y < 80.0:
		push_error("Movie display is not contained at a usable size inside the phone screen")
		quit(1)
		return
	if player.volume_db < 17.0:
		push_error("Film volume is not at least 4x louder")
		quit(1)
		return
	print("Phone screen=%s movie display=%s volume_db=%.1f" % [phone_screen.get_global_rect(), player_rect, player.volume_db])
	for index in 3:
		app_page.call("_play_movie", index)
		await create_timer(0.35).timeout
		if player.stream == null or not player.is_playing():
			push_error("Phone movie %d did not start" % index)
			quit(1)
			return
		player.stop()
	if app_page.has_method("set_cinema"):
		app_page.call("set_cinema", true)
		await process_frame
		var status := game.find_child("PhoneStatusBar", true, false) as Control
		if status != null and status.visible:
			push_error("FULL SCREEN did not black out the rest of the phone UI")
			quit(1)
			return
		app_page.call("set_cinema", false)
	print("PHONE MUVYE test passed: protected Back button, picker, louder films, fullscreen, and 3/3 movies")
	quit(0)
