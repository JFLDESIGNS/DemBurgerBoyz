extends SceneTree


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	var packed := load("res://scenes/character_creator/modular_character_base.tscn") as PackedScene
	assert(packed != null)
	var character := packed.instantiate()
	character.apply_saved_preset({
		"format_version": 8,
		"name": "Smoke Test Customer",
		"body_type": "kenney_chunky_toon",
		"skin_color": "cf895fff",
		"hair_style": 4,
		"hair_color": "5b3028ff",
		"top_style": 1,
		"top_color": "7259d9ff",
		"bottom_style": 2,
		"bottom_color": "39465cff",
		"shoe_style": 1,
		"shoe_color": "eeeeeeff",
		"eye_pupil_size": 0.58,
	})
	var customer_wrapper := Node3D.new()
	customer_wrapper.scale = Vector3.ONE * 0.552
	character.scale = Vector3.ONE * (1.0 / 0.7)
	customer_wrapper.add_child(character)
	root.add_child(customer_wrapper)
	await process_frame
	assert(character.get_active_skeleton() != null)
	assert(not character.get_active_body().find_children("*", "MeshInstance3D", true, false).is_empty())
	assert(character.eyelid_enabled)
	assert(character.lash_style == ModularCharacterBase.LashStyle.NONE)
	var eyelids := character.find_children("Eyelid", "MeshInstance3D", true, false)
	assert(eyelids.is_empty())
	character.apply_saved_preset({"eye_opening_version": 1, "lash_style": 0})
	await process_frame
	assert(character.lash_style == ModularCharacterBase.LashStyle.ALMOND)
	eyelids = character.find_children("Eyelid", "MeshInstance3D", true, false)
	assert(eyelids.size() == 2)
	var lid_material := (eyelids[0] as MeshInstance3D).material_override as ShaderMaterial
	assert(lid_material != null)
	assert("almond_h" in lid_material.shader.code)
	assert(not bool(lid_material.get_shader_parameter("rim_enabled")))
	character.apply_saved_preset({"lash_style": 2, "lash_color": "b21f65ff"})
	await process_frame
	assert(character.lash_style == ModularCharacterBase.LashStyle.NONE)
	assert(character.find_children("Eyelid", "MeshInstance3D", true, false).is_empty())
	character.apply_saved_preset({"eye_opening_version": 1, "lash_style": 1, "lash_color": "b21f65ff", "lash_rim_width": 0.30})
	await process_frame
	assert(character.lash_style == ModularCharacterBase.LashStyle.ALMOND_RIM)
	assert(is_equal_approx(character.lash_rim_width, 0.30))
	eyelids = character.find_children("Eyelid", "MeshInstance3D", true, false)
	lid_material = (eyelids[0] as MeshInstance3D).material_override as ShaderMaterial
	assert(bool(lid_material.get_shader_parameter("rim_enabled")))
	character.apply_saved_preset({"eye_opening_version": 1, "lash_style": 2})
	await process_frame
	assert(character.lash_style == ModularCharacterBase.LashStyle.CLASSIC)
	eyelids = character.find_children("Eyelid", "MeshInstance3D", true, false)
	lid_material = (eyelids[0] as MeshInstance3D).material_override as ShaderMaterial
	assert(int(lid_material.get_shader_parameter("opening_style")) == 2)
	assert((character.get("_lashes_root") as Node).get_child_count() == 0)
	var expected_unit: float = character.global_transform.basis.get_scale().x / character.get("_head_attachment").global_transform.basis.get_scale().x
	assert(is_equal_approx(float(character.get("_unit")), expected_unit))
	character.set_control_rig_visible(false)
	print("CHARACTER_CUSTOMER_INTEGRATION_SMOKE_OK")
	quit(0)
