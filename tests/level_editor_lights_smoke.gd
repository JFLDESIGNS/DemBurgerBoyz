extends SceneTree


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _init() -> void:
	var script: Script = load("res://scripts/level_editor.gd") as Script
	var editor: Node = script.new()
	var failures: Array[String] = []
	var rect := editor.call("_make_dressing_light", "rect_area") as SpotLight3D
	_expect(rect != null, "Rect Area does not create a light", failures)
	if rect != null:
		_expect(bool(rect.get_meta("rect_area", false)), "Rect Area identity metadata is missing", failures)
		_expect(rect.light_projector != null, "Rect Area projector is missing", failures)
		_expect(is_equal_approx(float(rect.get_meta("rect_width", 0.0)), 1.2), "Rect Area default width is wrong", failures)
		_expect(is_equal_approx(float(rect.get_meta("rect_height", 0.0)), 0.55), "Rect Area default height is wrong", failures)
		_expect(str(editor.call("_dressing_kind", rect)) == "rect_area", "Rect Area does not persist as its own type", failures)
	var marker_tex := editor.call("_light_marker_texture") as Texture2D
	_expect(marker_tex != null, "3D light marker icon is missing", failures)
	var source := FileAccess.get_file_as_string("res://scripts/level_editor.gd")
	_expect(source.contains("[\"Rect Area\", func(): _place_light(\"rect_area\")]"), "Rect Area button is missing from L mode", failures)
	_expect(source.contains("func _pick_light_marker_at"), "light markers cannot be clicked", failures)
	_expect(source.contains("_select(marker_light)"), "clicked marker does not select its light", failures)
	_expect(source.contains("_sync_outliner_selection()"), "world outliner is not synchronized", failures)
	_expect(source.contains("marker.modulate = light.light_color.lightened"), "all-light marker state is not updated", failures)
	if rect != null:
		rect.free()
	editor.free()
	if failures.is_empty():
		print("LEVEL_EDITOR_LIGHTS_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
