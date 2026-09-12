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
	var badge_body := _function_body(source, "_add_soda_flavor_graphic_plane", "_add_soda_ice_graphic")
	var fallback_body := _function_body(source, "_add_soda_ice_graphic", "_make_soda_flavor_panel_backing_mat")
	_expect(badge_body.contains("BILLBOARD_DISABLED"), "soda badge still faces the camera", failures)
	_expect(badge_body.contains("mat.no_depth_test = false"), "soda badge still ignores machine depth", failures)
	_expect(not badge_body.contains("BILLBOARD_ENABLED"), "soda badge contains an enabled billboard mode", failures)
	_expect(fallback_body.contains("BILLBOARD_DISABLED"), "fallback ICE badge still faces the camera", failures)
	_expect(fallback_body.contains("ice_art.no_depth_test = false"), "fallback ICE badge still ignores machine depth", failures)
	if failures.is_empty():
		print("SODA_BADGE_ORIENTATION_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
