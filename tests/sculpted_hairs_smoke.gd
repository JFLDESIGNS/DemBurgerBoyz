extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var legacy_names := ["NONE", "SIMPLE_PARTED", "BUZZED", "LONG", "BUNS", "LOWPOLY_MALE", "LOWPOLY_SHORT_1", "LOWPOLY_PONYTAIL", "LOWPOLY_SHORT_2", "CAP_WITH_HAIR", "CAPSULE_FEMALE", "CAPSULE_MALE"]
	for id in legacy_names.size():
		assert(ModularCharacterBase.HairStyle[legacy_names[id]] == id, "Existing hair IDs must stay stable")
	assert(ModularCharacterBase.HAIR_SCENES.size() == 18)
	assert(ModularCharacterBase.HAIR_LABELS.size() == 18)
	var creator = load("res://scenes/character_creator/character_creator.tscn").instantiate()
	root.add_child(creator)
	await process_frame
	creator._accessory_fits = {"hairs": {}, "hats": {}, "blocked_hairs": [], "blocked_hats": []}
	assert(creator.hair_select.item_count == 18)
	var c = creator.character
	c.extra_hairs = []
	c.hair_scale = 1.3
	c.hair_scale_xyz = Vector3.ONE
	c.hair_offset = Vector3(0.0, 0.3, 0.0)
	var hair_root: Node3D = c.get("_hair_root")
	for id in range(12, 18):
		creator.hair_select.select(id)
		creator.hair_select.item_selected.emit(id)
		await process_frame
		assert(int(c.hair_style) == id)
		assert(hair_root.get_child_count() == 1)
		var hair := hair_root.get_child(0) as Node3D
		assert(hair.find_children("*", "Skeleton3D", true, false).is_empty())
		var meshes := hair.find_children("*", "MeshInstance3D", true, false)
		assert(meshes.size() == 1, "Each asset must contain only its hair mesh")
		var mesh := meshes[0] as MeshInstance3D
		assert(mesh.skin == null)
		var box: AABB = hair.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		assert(box.size.x > 0.45 and box.size.x < 1.55, str(box))
		assert(box.size.y > 0.45 and box.size.y < 1.85, str(box))
		assert(box.end.y > 0.65 and box.end.y < 1.3, str(box))
		assert(hair.position.is_zero_approx(), "Default controls must preserve the authored fit")
		c.hair_color = Color("a34729")
		await process_frame
		mesh = hair_root.get_child(0).find_children("*", "MeshInstance3D", true, false)[0]
		assert(mesh.material_override != null, "Existing color controls must work")
		var saved := {"hair_style": id, "hair_color": c.hair_color.to_html(true), "hair_scale": 1.3, "hair_scale_xyz": [1,1,1], "hair_offset": [0,0.3,0], "facial_hair_style": 0}
		c.hair_style = ModularCharacterBase.HairStyle.NONE
		c.apply_saved_preset(JSON.parse_string(JSON.stringify(saved)))
		await process_frame
		assert(int(c.hair_style) == id and hair_root.get_child_count() == 1)
		print("SCULPTED_HAIR_OK ", id, " ", ModularCharacterBase.HAIR_LABELS[id], " ", box)
	c.add_extra_hair(12)
	await process_frame
	assert(hair_root.get_child_count() == 2, "New hairs must support the existing extra-hair layers")
	var attachment: BoneAttachment3D = hair_root.get_parent()
	assert(attachment.bone_name == "Head")
	var before := hair_root.transform
	c.scale = Vector3.ONE * 0.552
	c.set_pose_control("head_yaw", 25.0)
	await process_frame
	assert(hair_root.transform.is_equal_approx(before))
	c.extra_hairs = []
	for id in range(1, 12):
		c.hair_style = id
		await process_frame
		assert(hair_root.get_child_count() == 1, "Existing hairstyles must still load")
	creator.queue_free()
	await process_frame
	print("SCULPTED_HAIRS_SMOKE_OK")
	quit(0)

