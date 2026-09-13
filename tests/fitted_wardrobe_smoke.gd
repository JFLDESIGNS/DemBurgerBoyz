extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene_path := "res://scenes/character_creator/modular_character_base.tscn"
	if not ResourceLoader.exists(scene_path):
		scene_path = "res://scenes/modular_character_base.tscn"
	var character = load(scene_path).instantiate()
	root.add_child(character)
	await process_frame
	var body: MeshInstance3D = character._get_skin_mesh()
	var skeleton: Skeleton3D = character.get_active_skeleton()
	assert(ModularCharacterBase.TOP_LABELS.size() == 16)
	assert(ModularCharacterBase.TopStyle.size() == 16)
	for style in range(1, 16):
		character.top_style = style
		await process_frame
		var top: MeshInstance3D = character._fitted_top
		assert(top != null and top.skin == body.skin)
		assert(top.get_node(top.skeleton) == skeleton)
		assert(character.find_children("*", "Skeleton3D", true, false).size() == 1)
		var triangles := 0
		var print_faces := 0
		var center_height := 0.02235 if style == 12 else 0.0216
		for surface in top.mesh.get_surface_count():
			var a := top.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = a[Mesh.ARRAY_INDEX]
			var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
			var coords: PackedVector2Array = a[Mesh.ARRAY_TEX_UV2]
			var mask: PackedColorArray = a[Mesh.ARRAY_COLOR]
			triangles += indices.size() / 3
			assert(coords.size() == vertices.size())
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
				assert(rest.distance_to(vertices[v]) < 0.00002, "Bind conversion must preserve rest positions")
				if mask[v].a > 0.5 and absf(coords[v].x) < 0.0013 and absf(coords[v].y - center_height) < 0.0013:
					print_faces += 1
		assert(triangles > 400 and triangles < 2000)
		assert(print_faces > 0, "Each shirt needs printable front fabric at its default position")
		for graphic in range(1, 11):
			character.shirt_graphic = graphic
			for surface in top.mesh.get_surface_count():
				var material := top.get_surface_override_material(surface) as ShaderMaterial
				assert(material.get_shader_parameter("graphic_enabled"))
				assert(material.get_shader_parameter("graphic_texture") == ModularCharacterBase.SHIRT_GRAPHICS[graphic])
		character.shirt_graphic_color = Color.RED
		character.shirt_graphic_scale = 1.3
		character.shirt_graphic_horizontal = 0.02
		character.shirt_graphic_vertical = 0.01
		var material := top.get_surface_override_material(0) as ShaderMaterial
		assert(material.get_shader_parameter("graphic_color") == Color.RED)
		assert(is_equal_approx(material.get_shader_parameter("graphic_center").x, 0.0002))
		character.shirt_graphic = 0
		assert(not material.get_shader_parameter("graphic_enabled"))
		character.set_pose_control("left_arm_raise", 55.0)
		character.set_pose_control("spine_twist", 20.0)
		await process_frame
		assert(top.get_node(top.skeleton) == skeleton)
		character.reset_pose_controls()
		character.shirt_graphic_horizontal = 0.0
		character.shirt_graphic_vertical = 0.0
		print("FITTED_TOP_OK ", style, " triangles=", triangles)
	var old := {"top_style": 2, "top_color": "123456ff", "shirt_graphic": 9}
	ModularCharacterBase.Wardrobe.migrate_preset(old)
	assert(old.top_style == 11 and old.top_color == "ffffffff" and old.shirt_graphic == 9)
	var current := {"top_catalog_version": 1, "top_style": 12, "top_color": "aabbccff", "shirt_graphic": 4, "shirt_graphic_scale": 1.2}
	character.apply_saved_preset(current)
	assert(character.top_style == 12 and character.shirt_graphic == 4)
	assert(character.top_color == Color("aabbccff"))
	character.top_style = 0
	await process_frame
	assert(character._fitted_top == null)
	character.apply_saved_preset({"top_catalog_version": 1, "top_style": 0})
	assert(character.top_style == 0)
	character.queue_free()
	await process_frame
	var creator_path := "res://scenes/character_creator/character_creator.tscn" if ResourceLoader.exists("res://scenes/character_creator/character_creator.tscn") else "res://scenes/main.tscn"
	var creator = load(creator_path).instantiate()
	root.add_child(creator)
	await process_frame
	assert(creator.top_select.item_count == 16)
	assert(creator.graphic_select.item_count == 11)
	for style in range(1, 16):
		creator.top_select.item_selected.emit(style)
		creator.graphic_select.item_selected.emit(9)
		assert(creator.character.top_style == style and creator.character.shirt_graphic == 9)
	print("FITTED_WARDROBE_SMOKE_OK: 15 tops, 150 graphics combinations, skin binds, preset migration, creator controls")
	quit(0)
