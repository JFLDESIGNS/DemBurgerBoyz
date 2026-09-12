extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := "res://scenes/character_creator/modular_character_base.tscn"
	if not ResourceLoader.exists(path):
		path = "res://scenes/modular_character_base.tscn"
	var character = load(path).instantiate()
	root.add_child(character)
	await process_frame
	var body: MeshInstance3D = character._get_skin_mesh()
	var skeleton: Skeleton3D = character.get_active_skeleton()
	assert(ModularCharacterBase.BOTTOM_LABELS.size() == 16)
	assert(ModularCharacterBase.BottomStyle.size() == 16)
	character.top_style = 12
	character.shirt_graphic = 9
	for style in range(1, 16):
		character.bottom_style = style
		await process_frame
		var bottom: MeshInstance3D = character._fitted_bottom
		assert(bottom != null and bottom.skin == body.skin)
		assert(bottom.get_node(bottom.skeleton) == skeleton)
		assert(character.find_children("*", "Skeleton3D", true, false).size() == 1)
		assert(bottom.mesh != character._fitted_top.mesh, "Top and bottom caches must remain distinct")
		var triangles := 0
		var bounds := bottom.mesh.get_aabb()
		assert(bounds.position.z > 0.001 and bounds.end.z < 0.018, "Bottom must stay in the customer's lower-body bind space")
		for surface in bottom.mesh.get_surface_count():
			var a := bottom.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
			triangles += a[Mesh.ARRAY_INDEX].size() / 3
			assert(a[Mesh.ARRAY_TEX_UV].size() == vertices.size())
			for v in vertices.size():
				var total := 0.0
				var rest := Vector3.ZERO
				for influence in 4:
					var index := v * 4 + influence
					var bind := bones[index]
					assert(bind >= 0 and bind < body.skin.get_bind_count())
					var bone := skeleton.find_bone(body.skin.get_bind_name(bind))
					rest += skeleton.get_bone_global_rest(bone) * body.skin.get_bind_pose(bind) * vertices[v] * weights[index]
					total += weights[index]
				assert(absf(total - 1.0) < 0.001)
				assert(rest.distance_to(vertices[v]) < 0.00002)
			var material := bottom.get_surface_override_material(surface) as ShaderMaterial
			assert(material != null and not material.get_shader_parameter("graphic_enabled"))
		assert(triangles > 400 and triangles < 2000)
		for fit in [0.9, 1.12]:
			character.bottom_scale = fit
			character.bottom_color = Color("aaddec")
			var mat: ShaderMaterial = character._fitted_bottom.get_surface_override_material(0)
			assert(mat.get_shader_parameter("fabric_tint") == Color("aaddec"))
		character.bottom_scale = 1.0
		character.bottom_color = Color.WHITE
		character.set_pose_control("left_leg_forward", 18.0)
		character.set_pose_control("right_leg_forward", -12.0)
		await process_frame
		assert(character._fitted_bottom.get_node(character._fitted_bottom.skeleton) == skeleton)
		var top_material: ShaderMaterial = character._fitted_top.get_surface_override_material(0)
		assert(top_material.get_shader_parameter("graphic_enabled"))
		assert(top_material.get_shader_parameter("graphic_texture") == ModularCharacterBase.SHIRT_GRAPHICS[9])
		character.reset_pose_controls()
		print("FITTED_BOTTOM_OK ", style, " triangles=", triangles)
	var mapping := [8, 2, 8, 12, 6, 13, 15, 14]
	for old_style in range(8):
		var old := {"format_version": 11, "bottom_style": old_style, "bottom_color": "123456ff"}
		ModularCharacterBase.Wardrobe.migrate_preset(old)
		assert(old.bottom_style == mapping[old_style] and old.bottom_color == "ffffffff")
		ModularCharacterBase.Wardrobe.migrate_preset(old)
		assert(old.bottom_style == mapping[old_style], "Migration must be idempotent")
	for style in range(16):
		character.apply_saved_preset({"bottom_catalog_version": 1, "bottom_style": style, "bottom_color": "aaddecff", "top_catalog_version": 1, "top_style": 12, "shirt_graphic": 9})
		assert(character.bottom_style == style and character.bottom_color == Color("aaddecff"))
		assert((character._fitted_bottom == null) == (style == 0))
	character.queue_free()
	await process_frame
	var creator_path := "res://scenes/character_creator/character_creator.tscn" if ResourceLoader.exists("res://scenes/character_creator/character_creator.tscn") else "res://scenes/main.tscn"
	var creator = load(creator_path).instantiate()
	root.add_child(creator)
	await process_frame
	assert(creator.bottom_select.item_count == 16)
	for style in range(16):
		creator.bottom_select.item_selected.emit(style)
		assert(creator.character.bottom_style == style)
	print("FITTED_BOTTOMS_SMOKE_OK: 15 bottoms, bind transforms, weights, fit, tint, pose attachment, top graphics, preset migration, creator controls")
	quit(0)
