extends SceneTree


func _init() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/game.gd")
	var failures: Array[String] = []
	_expect(source.contains("if _try_grill_left_click_priority(event.position):"), "left-click priority is not resolved before cutting-board handlers", failures)
	_expect(source.contains("func _try_grill_left_click_priority(screen_pos: Vector2) -> bool:"), "priority helper is missing", failures)
	_expect(source.contains("var target := _pick_patty_for_slide_or_scoop(screen_pos, false)"), "priority path still honors Build blockers", failures)
	_expect(source.contains("if target == null and not (on_steel and _cursor_on_cutting_board(screen_pos))"), "empty board/steel overlap is not constrained", failures)
	_expect(source.contains("func _pick_patty_for_slide_or_scoop(screen_pos: Vector2, respect_ui_blockers: bool = true)"), "patty picker has no explicit blocker policy", failures)
	_expect(source.contains("var blocked := respect_ui_blockers and _blocks_grill_pick(screen_pos)"), "patty blocker policy is not applied", failures)
	_expect(source.contains("if _is_grill_screen_point(screen_pos):\n\t\treturn false"), "valid steel points do not bypass Build blocking", failures)
	_expect(source.contains("const FROZEN_SMASH_MIN_PX := 58.0"), "frozen-ball smash target is not generously sized", failures)
	_expect(source.contains("const FROZEN_SMASH_WORLD := 0.26"), "frozen-ball grill-plane fallback is too strict", failures)
	var right_click_start := source.find("func _try_grill_right_click(screen_pos: Vector2)")
	var right_click_end := source.find("\n\nfunc _try_grill_left_click_priority", right_click_start)
	var right_click_body := source.substr(right_click_start, right_click_end - right_click_start)
	var smash_pick_pos := right_click_body.find("var smash_target = _pick_patty_for_smash(screen_pos)")
	var grill_edge_pos := right_click_body.find("if not _is_grill_screen_point(screen_pos)")
	_expect(
		smash_pick_pos >= 0 and grill_edge_pos >= 0 and smash_pick_pos < grill_edge_pos,
		"waiting balls are still rejected by the grill-edge check before smash picking",
		failures
	)
	var smash_start := source.find("func _pick_patty_for_smash(screen_pos: Vector2)")
	var smash_end := source.find("\n\nfunc _smash_grill_patty", smash_start)
	var smash_body := source.substr(smash_start, smash_end - smash_start)
	_expect(smash_body.contains("if not bool(p.get(\"place_ball_waiting\")):"), "forgiving smash fallback can target normal patties", failures)
	_expect(smash_body.contains("screen_d <= pick_px"), "frozen-ball screen-space fallback is missing", failures)
	if failures.is_empty():
		print("GRILL_CLICK_PRIORITY_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
