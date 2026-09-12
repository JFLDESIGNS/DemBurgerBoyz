extends SceneTree
const Food = preload("res://scripts/food_sprites.gd")
func _init() -> void:
	Food.use_prepared_art = false
	DirAccess.make_dir_recursive_absolute("res://assets/ingredients/prepared")
	for id in ["bun_top", "bun_bottom", "patty", "cheese", "lettuce", "tomato", "onion", "bacon", "pickle", "ketchup", "mustard", "cutting_board"]:
		var texture: Texture2D = Food.get_tex(id)
		if texture == null:
			continue
		texture.set_meta("content_aspect", Food.texture_content_aspect(texture))
		texture.set_meta("composite_rect", Food._opaque_crop_rect(texture.get_image()))
		var err := ResourceSaver.save(texture, "res://assets/ingredients/prepared/%s.res" % id, ResourceSaver.FLAG_COMPRESS)
		if err != OK:
			quit(1)
			return
		print("PREPARED_INGREDIENT ", id)
	quit(0)
