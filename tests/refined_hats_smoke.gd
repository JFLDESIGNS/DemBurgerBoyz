extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _bounds(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		var local_box: AABB = node.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		box = local_box if first else box.merge(local_box)
		first = false
	return box

func _run() -> void:
	assert(ModularCharacterBase.HAT_SCENES.size() == 11)
	assert(ModularCharacterBase.HAT_LABELS.size() == ModularCharacterBase.HatStyle.size())
	var character = load("res://scenes/character_creator/modular_character_base.tscn").instantiate()
	root.add_child(character)
	await process_frame
	var hat_root: Node3D = character.get("_hat_root")
	for style in range(1, 11):
		character.hat_style = style
		await process_frame
		assert(hat_root.get_child_count() == 1, "One grouped hat must replace the previous selection")
		var hat := hat_root.get_child(0) as Node3D
		var meshes := hat.find_children("*", "MeshInstance3D", true, false)
		assert(meshes.size() >= 3)
		assert(hat.find_children("*", "Skeleton3D", true, false).is_empty())
		var colors := {}
		for mesh in meshes:
			assert(mesh.skin == null, "Hat export must not contain the source head or rig")
			for surface in mesh.mesh.get_surface_count():
				var material: BaseMaterial3D = mesh.get_active_material(surface)
				assert(material != null)
				colors[material.albedo_color.to_html()] = true
		assert(colors.size() >= 2, "Preserve separate trim and body colors")
		var box := _bounds(hat)
		assert(box.size.x > 0.5 and box.size.x < 2.0)
		assert(box.size.y > 0.15 and box.size.y < 1.3)
		assert(box.size.z > 0.4 and box.size.z < 1.8)
		assert(box.position.y > 0.0 and box.end.y < 1.5, "Hat must be fitted above the head bone")
		print("HAT_OK ", style, " ", ModularCharacterBase.HAT_LABELS[style], " ", box)
	# Animation attachment and customer wrapper scaling must move every part together.
	var local_before := hat_root.transform
	character.rotation.y = 0.7
	character.scale = Vector3.ONE * 0.552
	await process_frame
	assert(hat_root.transform.is_equal_approx(local_before))
	character.hat_color = Color(0.5, 0.8, 1.0)
	await process_frame
	character.hat_color = Color.WHITE
	await process_frame
	var reset_hat := hat_root.get_child(0)
	for mesh in reset_hat.find_children("*", "MeshInstance3D", true, false):
		var neutral = mesh.get_surface_override_material(0) as BaseMaterial3D
		assert(neutral != null, "Hat must use a neutral colorable material")
		assert(is_equal_approx(neutral.albedo_color.r,neutral.albedo_color.g) and is_equal_approx(neutral.albedo_color.g,neutral.albedo_color.b), "White tint must remove the authored hue")
	var legacy := {"hat_style": 5, "hat_scale": 1.8, "hat_offset": [0.4, -0.4, 0.6]}
	ModularCharacterBase.migrate_legacy_hat_fields(legacy)
	assert(legacy.hat_style == ModularCharacterBase.HatStyle.BASEBALL_CAP)
	assert(legacy.hat_scale == 1.0 and legacy.hat_offset == [0.0, 0.0, 0.0])
	var current := {"hat_catalog_version": 2, "hat_style": 9, "hat_scale": 1.15, "hat_color": "aabbccff"}
	character.apply_saved_preset(current)
	await process_frame
	assert(character.hat_style == ModularCharacterBase.HatStyle.GOLDEN_CROWN)
	assert(is_equal_approx(character.hat_scale, 1.15))
	character.hat_style = ModularCharacterBase.HatStyle.NONE
	await process_frame
	assert(hat_root.get_child_count() == 0)
	character.queue_free()
	await process_frame
	var creator = load("res://scenes/character_creator/character_creator.tscn").instantiate()
	root.add_child(creator)
	await process_frame
	assert(creator.hat_select.item_count == 11)
	assert(creator._fitted_hat_ids().size() > 0)
	creator._on_hat_selected(4)
	await process_frame
	assert(creator.character.hat_style == ModularCharacterBase.HatStyle.BASEBALL_CAP)
	assert(creator.character.hat_color == Color.WHITE)
	assert(creator.character.get("_hat_root").get_child_count() == 1)
	print("REFINED_HATS_SMOKE_OK")
	quit(0)
