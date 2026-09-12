extends SceneTree
func _initialize(): call_deferred("run")
func run():
	root.size = Vector2i(1100,720)
	root.content_scale_size = Vector2i(1100,720)
	var c = load("res://scenes/character_creator/character_creator.tscn").instantiate()
	root.add_child(c)
	for i in 10: await process_frame
	c._studio.apply_starter(0)
	c._studio.select_category("Face")
	for spec in [[1,1.3,0.03],[4,1.3,0.45],[6,0.9,0.5],[7,0.9,0.5]]:
		c.character.hair_style = spec[0]
		c.character.hair_scale = spec[1]
		c.character.hair_offset = Vector3(0,spec[2],0)
		for i in 8: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/studio_fit_%d.png" % spec[0])
	print("FIT_CONTACT_OK")
	quit()
