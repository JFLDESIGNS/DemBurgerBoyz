extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var character = load("res://scenes/character_creator/modular_character_base.tscn").instantiate()
	root.add_child(character)
	await process_frame
	var body: MeshInstance3D = character._get_skin_mesh()
	var skeleton: Skeleton3D = character.get_active_skeleton()
	assert(ModularCharacterBase.ShoeStyle.size() == 16)
	assert(ModularCharacterBase.Footwear.CATEGORIES.count("universal") == 10)
	assert(ModularCharacterBase.Footwear.CATEGORIES.count("special") == 5)
	for style in range(1, 16):
		character.shoe_style = style
		await process_frame
		var shoes: MeshInstance3D = character._fitted_shoes
		assert(shoes != null and shoes.skin == body.skin)
		assert(shoes.get_node(shoes.skeleton) == skeleton)
		assert(character.find_children("*", "Skeleton3D", true, false).size() == 1)
		var triangles := 0
		var left := 0
		var right := 0
		for surface in shoes.mesh.get_surface_count():
			var a := shoes.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
			triangles += a[Mesh.ARRAY_INDEX].size() / 3
			for v in vertices.size():
				var total := 0.0
				var rest := Vector3.ZERO
				for influence in 4:
					var index := v * 4 + influence
					var bind := bones[index]
					assert(bind >= 0 and bind < body.skin.get_bind_count())
					var bone_name := String(body.skin.get_bind_name(bind))
					var bone := skeleton.find_bone(bone_name)
					rest += skeleton.get_bone_global_rest(bone) * body.skin.get_bind_pose(bind) * vertices[v] * weights[index]
					total += weights[index]
					if weights[index] > 0.001:
						assert(bone_name in ["LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToes", "RightUpLeg", "RightLeg", "RightFoot", "RightToes"], bone_name)
						assert(bone_name.begins_with("Left") == (vertices[v].x > 0.0), "Shoe must never bind to opposite foot")
				assert(absf(total - 1.0) < 0.001)
				assert(rest.distance_to(vertices[v]) < 0.00002, "Rest binding must preserve authored fit")
				assert(absf(vertices[v].x) > 0.001 and absf(vertices[v].x) < 0.006, "No stretched straps")
				assert(vertices[v].z < 0.0065 and vertices[v].z > -0.001)
				if vertices[v].x > 0: left += 1
				else: right += 1
		assert(left > 50 and right > 50)
		assert(triangles > 200 and triangles < 6000)
		# An independent foot rotation must deform the left shoe, not the right one.
		character._set_ik_enabled(false)
		skeleton.clear_bones_global_pose_override()
		skeleton.reset_bone_poses()
		var foot := skeleton.find_bone("LeftFoot")
		skeleton.set_bone_pose_rotation(foot, Quaternion(Vector3.RIGHT, 0.35))
		skeleton.force_update_all_bone_transforms()
		var moved := false
		for surface in shoes.mesh.get_surface_count():
			var a := shoes.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
			for v in vertices.size():
				var posed := Vector3.ZERO
				for j in 4:
					var index := v * 4 + j
					var bind := bones[index]
					var bone := skeleton.find_bone(body.skin.get_bind_name(bind))
					posed += skeleton.get_bone_global_pose(bone) * body.skin.get_bind_pose(bind) * vertices[v] * weights[index]
				if vertices[v].x > 0 and posed.distance_to(vertices[v]) > 0.00005: moved = true
				if vertices[v].x < 0: assert(posed.distance_to(vertices[v]) < 0.00002)
		assert(moved)
		skeleton.reset_bone_poses()
		skeleton.force_update_all_bone_transforms()
		for fit in [0.9, 1.2]:
			character.shoe_scale = fit
			assert(character._fitted_shoes != null)
		character.shoe_scale = 1.0
		print("FITTED_SHOE_OK ", style, " triangles=", triangles)
	for style in range(0, 6):
		var legacy := {"shoe_style": style, "shoe_scale": 1.12, "shoe_color": "654321ff"}
		ModularCharacterBase.Footwear.migrate_preset(legacy)
		assert(legacy.shoe_style == style and legacy.shoe_scale == 1.0 and legacy.shoe_color == "ffffffff")
	character.apply_saved_preset({"shoe_catalog_version": 1, "shoe_style": 15, "shoe_scale": 1.08, "shoe_color": "aabbccff"})
	assert(character.shoe_style == 15 and character.shoe_color == Color("aabbccff") and is_equal_approx(character.shoe_scale, 1.08))
	character.shoe_style = 0
	assert(character._fitted_shoes == null)
	character.queue_free()
	await process_frame
	var creator = load("res://scenes/character_creator/character_creator.tscn").instantiate()
	root.add_child(creator)
	await process_frame
	assert(creator.shoe_select.item_count == 16)
	for style in range(1, 16):
		creator.shoe_select.item_selected.emit(style)
		assert(creator.character.shoe_style == style and creator.character._fitted_shoes != null)
	print("FITTED_FOOTWEAR_SMOKE_OK: 15 pairs, categories, skin binds, left/right animation, fit, migration, creator UI")
	creator.queue_free()
	await process_frame
	await process_frame
	quit(0)

