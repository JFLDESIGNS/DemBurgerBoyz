extends SceneTree


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _function_body(source: String, function_name: String, next_function_name: String) -> String:
	var start := source.find("func " + function_name)
	var finish := source.find("\n\nfunc " + next_function_name, start)
	if start < 0 or finish < 0:
		return ""
	return source.substr(start, finish - start)


func _init() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/game.gd")
	var failures: Array[String] = []
	var queue_body := _function_body(source, "_queue_condiment_pour", "_condiment_pour_target_world")
	var deposit_pos := queue_body.find("_deposit_condiment_entry(entry)")
	var animation_pos := queue_body.find("_start_condiment_pour(entry)")
	var busy_pos := queue_body.find("if _condiment_auto_active.has(id)")
	_expect(not queue_body.is_empty(), "condiment queue function is missing", failures)
	_expect(deposit_pos >= 0, "condiment input is not deposited immediately", failures)
	_expect(animation_pos > deposit_pos, "condiment gameplay still waits for its animation", failures)
	_expect(busy_pos > deposit_pos, "per-bottle busy state can delay condiment input", failures)
	_expect(not queue_body.contains("if condiment_pour_busy or condiment_tool_held"), "one bottle still globally blocks the other bottle", failures)
	var start_body := _function_body(source, "_start_condiment_pour", "_deposit_condiment_entry")
	_expect(start_body.contains("_condiment_auto_active[id] = true"), "automatic pours do not have per-bottle active state", failures)
	_expect(start_body.contains("_condiment_auto_streams.get(id"), "automatic pours do not use independent streams", failures)
	_expect(start_body.contains("camera_right * bottle_side * 0.115"), "bottles are not separated onto opposite sides", failures)
	var target_body := _function_body(source, "_condiment_pour_target_world", "_condiment_stream_material")
	_expect(target_body.contains("side * 0.035"), "sauce landing points are not separated", failures)

	var stream_body := _function_body(source, "_update_condiment_stream", "_prewarm_condiment_stream_render")
	_expect(stream_body.contains("stream.global_transform = Transform3D"), "stream does not reuse a transformed mesh", failures)
	_expect(not stream_body.contains("_make_condiment_stream_curve_mesh"), "stream still rebuilds geometry every frame", failures)

	var front_body := _function_body(source, "_set_condiment_bottle_animation_front", "_build_condiment_bottles")
	_expect(not front_body.contains("no_depth_test"), "bottle click still changes depth-test render pipelines", failures)
	_expect(not front_body.contains("depth_draw_mode"), "bottle click still changes depth-draw render pipelines", failures)
	_expect(source.contains("await _prewarm_condiment_stream_render()"), "condiment stream is not render-prewarmed", failures)
	_expect(source.contains("var _condiment_stream_materials: Dictionary = {}"), "condiment stream materials are not cached", failures)
	_expect(source.contains("var _condiment_auto_tweens: Dictionary = {}"), "per-bottle tween storage is missing", failures)
	_expect(source.contains("var _condiment_auto_streams: Dictionary = {}"), "per-bottle stream storage is missing", failures)

	if failures.is_empty():
		print("CONDIMENT_INPUT_PERFORMANCE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
