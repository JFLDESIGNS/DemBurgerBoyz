extends SceneTree
func _initialize() -> void:
	for state in ["toasted", "burnt"]:
		var id: String = "bun_bottom_"+state
		var img := Image.load_from_file("res://assets/ingredients/"+id+".png")
		assert(img != null and img.get_pixel(0,0).a == 0)
		var texture := ImageTexture.create_from_image(preload("res://scripts/food_sprites.gd")._crop_to_opaque(img))
		assert(ResourceSaver.save(texture,"res://assets/ingredients/prepared/"+id+".res") == OK)
	print("COOKED_BUN_ASSETS_OK")
	quit()
