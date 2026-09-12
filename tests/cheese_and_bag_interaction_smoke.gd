extends SceneTree


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _body(source: String, first: String, next: String) -> String:
	var start := source.find("func " + first)
	var finish := source.find("\n\nfunc " + next, start)
	if start < 0 or finish < 0:
		return ""
	return source.substr(start, finish - start)


func _init() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/game.gd")
	var defaults := FileAccess.get_file_as_string("res://defaults/gfx_settings.cfg")
	var failures: Array[String] = []
	var strip := _body(source, "_handle_strip_swipe_input", "_strip_mouse_pos")
	_expect(strip.contains("get_viewport().set_input_as_handled()"), "ingredient strip does not claim its press", failures)
	_expect(strip.contains("_add_ingredient(start_id)"), "claimed strip taps are not completed directly", failures)
	var fridge := _body(source, "_try_patty_fridge_click", "_close_patty_fridge")
	_expect(fridge.contains("if _strip_ingredient_at(screen_pos) != \"\""), "freezer can still steal ingredient-tile clicks", failures)
	var cheese := _body(source, "_update_cheese_ghost", "_can_put_cheese_on_grill_patty")
	_expect(cheese.contains("cheese_ghost.rotation_degrees = Vector3.ZERO"), "held cheese is still tilted", failures)
	_expect(source.contains("hold_bag_half_v2"), "existing garbage-bag profiles are not migrated to half size", failures)
	_expect(defaults.contains("hold_bag_scale=1.265"), "shipped garbage-bag scale is not halved", failures)
	_expect(defaults.contains("hold_bag_half_v2=true"), "shipped defaults can be halved twice", failures)
	if failures.is_empty():
		print("CHEESE_AND_BAG_INTERACTION_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
