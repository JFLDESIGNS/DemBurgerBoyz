extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var image:=Image.load_from_file("res://assets/props/seasoning_label.png")
	assert(image!=null)
	image.generate_mipmaps()
	assert(ResourceSaver.save(ImageTexture.create_from_image(image),"res://assets/props/seasoning_label.res")==OK)
	print("SEASONING_LABEL_READY")
	quit()
