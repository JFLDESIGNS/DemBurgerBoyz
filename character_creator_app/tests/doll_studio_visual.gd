extends SceneTree
var creator
func _initialize():
	call_deferred("run")
func run():
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1100,720)
	root.content_scale_size = Vector2i(1100,720)
	var standalone = not ResourceLoader.exists("res://scenes/character_creator/character_creator.tscn")
	creator = load("res://scenes/main.tscn" if standalone else "res://scenes/character_creator/character_creator.tscn").instantiate()
	var output = "C:/Users/joe/Desktop/burgergame/build/"+("standalone_" if standalone else "")
	root.add_child(creator)
	for i in 30: await process_frame
	var studio = creator._studio
	studio.apply_starter(0)
	creator.character_name.text = "Peach"
	print("CAMERA ",creator.camera.global_position," DIST ",creator._camera_distance," FOV ",creator.camera.fov," HEAD ",creator.character.feature_world_position("hair")," FOOT ",creator.character.feature_world_position("shoes"))
	studio.select_category("Clothes")
	for i in 160: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"studio_clothes.png")
	studio.select_category("Face")
	for i in 10: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"studio_face.png")
	studio.select_category("Hair")
	for i in 250: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"studio_hair.png")
	studio.catalog_turn("Hair",1)
	for i in 40: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"studio_hair_page2.png")
	studio.select_category("Accessories")
	studio.select_style("Hats",3)
	for i in 40: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"studio_hats.png")
	studio.catalog_turn("Hats",1)
	for i in 40: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"studio_hats_page2.png")
	root.size = Vector2i(900,620)
	root.content_scale_size = Vector2i(900,620)
	studio.select_category("Face")
	for i in 10: await process_frame
	studio.layout()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"studio_small.png")
	root.size = Vector2i(1375,900)
	root.content_scale_size = Vector2i(1100,720)
	for i in 10: await process_frame
	studio.layout()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"studio_125percent.png")
	root.size = Vector2i(1650,1080)
	root.content_scale_size = Vector2i(1100,720)
	for i in 10: await process_frame
	studio.layout()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"studio_150percent.png")
	print("FOOTER ",studio.footer.get_global_rect()," STATUS ",creator.status_label.get_global_rect()," SAVED ",studio.saved_label.get_global_rect())
	print("STUDIO_VISUAL_OK",studio.size," ",studio.stage_rect)
	creator.queue_free()
	for i in 3: await process_frame
	quit()
