extends SceneTree


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	var packed := load("res://scenes/character_creator/modular_character_base.tscn") as PackedScene
	assert(packed != null)
	var character := packed.instantiate()
	root.add_child(character)
	await process_frame

	assert(character.top_style == ModularCharacterBase.TopStyle.T_SHIRT)
	assert(character.bottom_style == ModularCharacterBase.BottomStyle.SHORTS)
	assert(not character.has_skin_paint())

	var test_uv := Vector2(0.25, 0.20)
	character.paint_skin_stamp(test_uv, 5.0, Color.RED)
	var encoded: String = character.get_skin_paint_png_base64()
	assert(not encoded.is_empty())
	var decoded := Image.new()
	assert(decoded.load_png_from_buffer(Marshalls.base64_to_raw(encoded)) == OK)
	var direct_pixel := decoded.get_pixel(128, 102)
	var old_flipped_pixel := decoded.get_pixel(128, 409)
	assert(direct_pixel.a > 0.5)
	assert(old_flipped_pixel.a < 0.01)

	var next_character := packed.instantiate()
	root.add_child(next_character)
	await process_frame
	assert(not next_character.has_skin_paint())
	next_character.set_skin_paint_png_base64(encoded)
	assert(next_character.has_skin_paint())
	next_character.migrate_legacy_skin_paint_v_flip()
	var migrated := Image.new()
	assert(migrated.load_png_from_buffer(Marshalls.base64_to_raw(next_character.get_skin_paint_png_base64())) == OK)
	assert(migrated.get_pixel(128, 409).a > 0.5)
	assert(migrated.get_pixel(128, 102).a < 0.01)
	next_character.clear_skin_paint()
	assert(not next_character.has_skin_paint())
	assert(next_character.get_skin_paint_png_base64().is_empty())

	print("SKIN_PAINT_PERSISTENCE_SMOKE_OK")
	quit(0)
