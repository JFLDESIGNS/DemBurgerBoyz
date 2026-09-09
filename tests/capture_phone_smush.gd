extends SceneTree

const SmushScript := preload("res://scripts/phone_smush.gd")


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var smush := SmushScript.new()
	smush.position = Vector2.ZERO
	smush.size = Vector2(236, 478)
	root.add_child(smush)
	smush.set_active(true)
	await process_frame
	await process_frame
	await process_frame
	var image := root.get_texture().get_image().get_region(Rect2i(0, 0, 236, 478))
	var output := OS.get_temp_dir().path_join("burger_pals_smush_preview.png")
	var error := image.save_png(output)
	print("SMUSH_PREVIEW=%s ERROR=%d" % [output, error])
	quit(0 if error == OK else 1)
