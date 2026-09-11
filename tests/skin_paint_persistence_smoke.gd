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
	assert(character.get_skin_paint_resolution() == 1024)
	assert(not character.get_skin_uv_guide_lines().is_empty())

	var test_uv := Vector2(0.25, 0.20)
	character.paint_skin_stamp(test_uv, 5.0, Color.RED)
	var encoded: String = character.get_skin_paint_png_base64()
	assert(not encoded.is_empty())
	var decoded := Image.new()
	assert(decoded.load_png_from_buffer(Marshalls.base64_to_raw(encoded)) == OK)
	assert(decoded.get_width() == 1024 and decoded.get_height() == 1024)
	var px := int(round(test_uv.x * float(decoded.get_width() - 1)))
	var py := int(round(test_uv.y * float(decoded.get_height() - 1)))
	var flipped_py := decoded.get_height() - 1 - py
	var direct_pixel := decoded.get_pixel(px, py)
	var old_flipped_pixel := decoded.get_pixel(px, flipped_py)
	assert(direct_pixel.a > 0.5)
	assert(old_flipped_pixel.a < 0.01)
	var before_hard: PackedByteArray = character.get_skin_paint_snapshot_png()
	character.paint_skin_stamp(Vector2(0.5, 0.5), 0.75, Color(0.0, 0.0, 1.0, 0.25), true)
	var hard_pixel := Image.new()
	assert(hard_pixel.load_png_from_buffer(character.get_skin_paint_snapshot_png()) == OK)
	assert(maxf(hard_pixel.get_pixel(511, 511).a, hard_pixel.get_pixel(512, 512).a) > 0.1)
	character.restore_skin_paint_snapshot_png(before_hard, true)
	for erase_pass in range(16):
		character.erase_skin_stamp(test_uv, 8.0, 1.0)
	assert(not character.has_skin_paint())
	assert(character.get_skin_paint_png_base64().is_empty())

	var next_character := packed.instantiate()
	root.add_child(next_character)
	await process_frame
	assert(not next_character.has_skin_paint())
	next_character.set_skin_paint_png_base64(encoded)
	assert(next_character.has_skin_paint())
	next_character.migrate_legacy_skin_paint_v_flip()
	var migrated := Image.new()
	assert(migrated.load_png_from_buffer(Marshalls.base64_to_raw(next_character.get_skin_paint_png_base64())) == OK)
	assert(migrated.get_pixel(px, flipped_py).a > 0.5)
	assert(migrated.get_pixel(px, py).a < 0.01)
	next_character.clear_skin_paint()
	assert(not next_character.has_skin_paint())
	assert(next_character.get_skin_paint_png_base64().is_empty())

	print("SKIN_PAINT_PERSISTENCE_SMOKE_OK")
	quit(0)
