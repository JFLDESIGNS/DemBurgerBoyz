extends SceneTree


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	var packed := load("res://scenes/character_creator/character_creator.tscn") as PackedScene
	assert(packed != null)
	var creator := packed.instantiate()
	root.add_child(creator)
	await process_frame
	await process_frame
	creator.call("_toggle_paint_mode")
	creator.call("_set_flat_paint_mode", true)
	await process_frame
	var panel := creator.get("_flat_paint_panel") as PanelContainer
	var canvas := creator.get("_flat_paint_canvas") as Control
	assert(panel != null and panel.visible)
	assert(canvas != null and canvas.is_visible_in_tree())
	creator.call("_set_paint_brush_size", 0.75)
	assert(is_equal_approx(float(creator.get("_paint_brush_size")), 0.75))
	var character = creator.get("character")
	character.clear_skin_paint()
	creator.call("_reset_paint_history")
	assert((creator.get("_paint_tool_buttons") as Dictionary).has("erase"))
	creator.call("_begin_paint_stroke", "Test stroke")
	character.paint_skin_stamp(Vector2(0.4, 0.4), 2.0, Color.RED, true)
	creator.set("_paint_stroke_changed", true)
	creator.call("_end_paint_stroke")
	assert((creator.get("_paint_history") as Array).size() == 1)
	creator.call("_undo_paint_stroke")
	assert(not character.has_skin_paint())
	creator.call("_set_paint_unlit_preview", true)
	assert(bool(creator.get("_paint_unlit_preview")))
	creator.call("_set_paint_unlit_preview", false)
	creator.call("_toggle_paint_mode")
	print("CHARACTER_PAINT_UI_SMOKE_OK")
	quit(0)
