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
	var expected_unit: float = character.global_transform.basis.get_scale().x / character.get("_head_attachment").global_transform.basis.get_scale().x
	assert(is_equal_approx(float(character.get("_unit")), expected_unit))
	character.set_control_rig_visible(false)
	print("CHARACTER_CUSTOMER_INTEGRATION_SMOKE_OK")
	quit(0)
