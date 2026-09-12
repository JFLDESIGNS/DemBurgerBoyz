extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1440, 1000)
	var main_path := "res://scenes/character_creator/character_creator.tscn"
	if not ResourceLoader.exists(main_path):
		main_path = "res://scenes/main.tscn"
	var creator = load(main_path).instantiate()
	root.add_child(creator)
	await process_frame
	creator.character.begin_appearance_batch()
	creator.character.hair_style = 0
	creator.character.hat_style = 0
	creator.character.top_color = Color.WHITE
	creator.character.bottom_style = 1
	creator.character.shirt_graphic = 9
	creator.character.shirt_graphic_color = Color.WHITE
	creator.character.shirt_graphic_scale = 1.0
	creator.character.shirt_graphic_horizontal = 0.0
	creator.character.shirt_graphic_vertical = 0.0
	creator.character.end_appearance_batch()
	creator.character.set_control_rig_visible(false)
	creator.character.reset_pose_controls()
	creator._camera_distance = 4.6
	creator._camera_pan = Vector3(0, 0.25, 0)
	creator._orbit_y = 0.0
	creator._orbit_x = -0.02
	creator._apply_camera()
	creator._scroll_to_feature("shirt")
	var output := "C:/Users/joe/Desktop/burgergame/build/wardrobe_qa"
	DirAccess.make_dir_recursive_absolute(output)
	for style in range(1, 13):
		creator.character.top_style = style
		creator.top_select.select(style)
		for frame in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output + "/top_%02d.png" % style)
	creator.character.top_style = 3
	creator.character.set_pose_control("left_arm_raise", 55.0)
	creator.character.set_pose_control("spine_twist", 25.0)
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output + "/posed.png")
	print("FITTED_WARDROBE_RENDER_OK")
	quit()
