extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/character_creator/character_creator.tscn") as PackedScene
	assert(packed != null)
	var creator := packed.instantiate()
	root.add_child(creator)
	await process_frame
	await process_frame
	creator.call("_open_sculpt_mode")
	await process_frame
	await process_frame
	var sculpt = creator.get("_sculpt_workspace")
	assert(sculpt != null)
	assert((sculpt.get("_vertices") as PackedVector3Array).size() > 250)
	assert((sculpt.get("_mesh_instance") as MeshInstance3D).mesh != null)
	assert(sculpt.get("_reference_body") != null)
	assert(sculpt.get("_brush_cursor") != null)
	var reference := sculpt.get("_reference_body") as Node3D
	var reference_before := reference.position
	sculpt.call("_move_reference_by", Vector2(12, -8))
	assert(reference.position != reference_before)
	sculpt.set("_reference_opacity", 0.22)
	sculpt.call("_apply_reference_ghost")
	var reference_meshes := reference.find_children("*", "GeometryInstance3D", true, false)
	assert(not reference_meshes.is_empty())
	assert(is_equal_approx((reference_meshes[0] as GeometryInstance3D).transparency, 0.78))
	sculpt.set("_key_energy", 2.1)
	sculpt.set("_ambient_energy", 0.4)
	sculpt.call("_apply_lighting")
	assert(is_equal_approx((sculpt.get("_key_light") as Light3D).light_energy, 2.1))
	sculpt.set("_show_points", false)
	sculpt.call("_rebuild_points")
	assert(not (sculpt.get("_points_instance") as MultiMeshInstance3D).visible)
	sculpt.set("_next_subdivisions", 48)
	sculpt.call("_new_sphere")
	assert((sculpt.get("_vertices") as PackedVector3Array).size() > 1400)
	sculpt.set("_next_subdivisions", 24)
	sculpt.call("_new_plane")
	var plane_count: int = (sculpt.get("_vertices") as PackedVector3Array).size()
	assert(plane_count > 250)
	sculpt.call("_solidify_plane")
	assert(bool(sculpt.get("_is_solid")))
	assert((sculpt.get("_vertices") as PackedVector3Array).size() == plane_count * 2)
	var tools := sculpt.get("_tool_select") as OptionButton
	tools.select(1)
	sculpt.set("_active_vertex", int(plane_count / 2))
	var before := (sculpt.get("_vertices") as PackedVector3Array).duplicate()
	sculpt.call("_apply_brush", Vector2.ZERO, Vector2(0, -14))
	var after := sculpt.get("_vertices") as PackedVector3Array
	assert(before != after)
	tools.select(3)
	before = after.duplicate()
	sculpt.call("_apply_brush", Vector2.ZERO, Vector2(8, -6))
	after = sculpt.get("_vertices") as PackedVector3Array
	assert(before != after)
	tools.select(4)
	before = after.duplicate()
	sculpt.call("_apply_brush", Vector2.ZERO, Vector2(8, -6))
	after = sculpt.get("_vertices") as PackedVector3Array
	assert(before != after)
	tools.select(6)
	for stroke in range(8):
		sculpt.call("_apply_brush", Vector2.ZERO, Vector2.ZERO)
	var mask := sculpt.get("_mask_weights") as PackedFloat32Array
	var strongest_mask := 0.0
	for value in mask: strongest_mask = maxf(strongest_mask, value)
	assert(strongest_mask > 0.25)
	sculpt.call("_invert_mask")
	sculpt.call("_clear_mask")
	for value in (sculpt.get("_mask_weights") as PackedFloat32Array): assert(is_zero_approx(value))
	tools.select(5)
	(sculpt.get("_color_button") as ColorPickerButton).color = Color.CYAN
	sculpt.call("_apply_brush", Vector2.ZERO, Vector2.ZERO)
	var colors := sculpt.get("_colors") as PackedColorArray
	assert(colors.size() == after.size())
	sculpt.call("_undo_action")
	sculpt.call("_redo_action")
	var combined_before: int = (sculpt.get("_vertices") as PackedVector3Array).size()
	sculpt.call("_append_sphere")
	assert(int(sculpt.get("_primitive_count")) == 2)
	var combined_count: int = (sculpt.get("_vertices") as PackedVector3Array).size()
	assert(combined_count > combined_before)
	(sculpt.get("_name_edit") as LineEdit).text = "Codex Sculpt Smoke"
	(sculpt.get("_category_select") as OptionButton).select(1)
	sculpt.call("_save_item")
	var saved_path := "user://sculpted_items/hat/codex_sculpt_smoke.res"
	assert(ResourceLoader.exists(saved_path))
	(sculpt.get("_library_select") as OptionButton).select((sculpt.get("_saved_items") as Array).size() - 1)
	sculpt.call("_load_selected_item")
	assert((sculpt.get("_vertices") as PackedVector3Array).size() == combined_count)
	assert(int(sculpt.get("_primitive_count")) == 2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saved_path))
	(sculpt.get("_saved_items") as Array).pop_back()
	sculpt.call("_write_manifest")
	creator.call("_close_sculpt_mode")
	print("SCULPT_MODE_SMOKE_OK")
	quit(0)
