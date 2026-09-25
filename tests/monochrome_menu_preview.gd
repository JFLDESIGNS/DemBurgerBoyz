extends SceneTree
func _initialize() -> void: call_deferred("run")
func capture(path: String) -> void:
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	create_timer(80).timeout.connect(func():push_error("SIDE_MENU_TIMEOUT");quit(1))
	var game=load("res://scenes/main.tscn").instantiate()
	game.set_script(load("res://tests/main_ticket_harness.gd"))
	root.add_child(game);current_scene=game
	game._style_static_labels()
	game._setup_multiplayer_ui()
	game.flash_label.hide()
	game.game_over_panel.hide()
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(1280,720)
	await capture("res://build/monochrome_menu_release/menu_1280.png")
	var menu=game._menu_truck
	menu.set_process(false)
	assert(absf(menu.camera.position.x)<0.001,"Side camera must not skew the departure")
	assert(menu.size.x>root.get_visible_rect().size.x and menu.size.y>game.start_logo_wrap.size.y)
	var before:Vector2=menu.camera.unproject_position(Vector3(0,2,0))
	var after:Vector2=menu.camera.unproject_position(Vector3(8,2,0))
	assert(absf(before.y-after.y)<0.1,"Truck must travel horizontally")
	var card=game.start_overlay.find_child("StartMenuCard",true,false)
	var style:StyleBoxFlat=card.get_theme_stylebox("panel")
	assert(style.bg_color.get_luminance()<0.12 and style.content_margin_bottom>=30)
	for button in [game.start_btn,game.multiplayer_btn,game.tutorial_btn,game.start_overlay.find_child("CharacterCreatorButton",true,false)]:
		for state in ["normal","hover","pressed"]:
			assert(button.get_theme_stylebox(state).shadow_size==0)
	var backdrop=game.start_overlay.get_node("DinerBackdrop")
	var clock_before:float=backdrop.burst_clock
	await create_timer(0.2).timeout
	assert(backdrop.burst_clock>clock_before)
	root.size=Vector2i(1920,1080)
	await capture("res://build/monochrome_menu_release/menu_1920.png")
	root.size=Vector2i(1280,720)
	await process_frame
	menu.departing=true
	for step in 5:
		menu._process(0.2)
		await capture("res://build/monochrome_menu_release/departure_%d.png"%step)
	menu._process(0.35)
	assert(not menu.departing and menu.truck.position.x>20)
	print("SIDE_MENU_PREVIEW_OK side camera, overscan, flat buttons, black panel, rotating burst, departure")
	quit()
