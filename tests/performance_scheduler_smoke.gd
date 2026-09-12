extends SceneTree


func _init() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/game.gd")
	var failures: Array[String] = []
	_expect(source.contains("const PERF_UI_TICK_SEC := 0.10"), "missing 10 Hz UI scheduler", failures)
	_expect(source.contains("const PERF_LAYOUT_TICK_SEC := 1.0 / 30.0"), "missing 30 Hz layout scheduler", failures)
	_expect(source.contains("if mouse_moved:\n\t\t_update_physical_garbage_hover()"), "garbage hover still runs every frame", failures)
	_expect(source.contains("_update_station_freshness(delta, ui_tick)"), "freshness labels are not cadence gated", failures)
	_expect(source.contains("if _mp_station_accum >= 1.0:"), "station repair snapshots are not throttled", failures)
	_expect(not source.contains("\t\t\t## Build board absolute repair every cook tick too."), "legacy per-grill station broadcast remains", failures)
	_expect(source.contains("func _mp_broadcast_station(station_index: int, peer_id: int = 0)"), "station sync cannot target late joiners", failures)
	_expect(source.contains("_mp_broadcast_station(si, peer_id)"), "bootstrap does not force targeted station state", failures)
	_expect(source.contains("_mp_tool_pose_cool = 0.05"), "held tool stream is above 20 Hz", failures)
	_expect(not source.contains("\tmp_sync_customers.rpc(ids, pats, xs, zs, waits, leaves, clocks, sodas_handed, icecreams_handed, yaws, fries_handed, serving)\n\t_mp_send_challenge_state()"), "customer packets still bundle unrelated state", failures)
	_expect(source.contains("const PATTY_PREWARM_POOL_SIZE := 40"), "patty pool is below the gameplay capacity target", failures)
	_expect(not source.contains("\treturn PattyScript.new()"), "patty pool still allocates synchronously on exhaustion", failures)
	_expect(source.contains("_refresh_supply_ui_fast(id)"), "ingredient use still lacks the stock-only UI path", failures)
	_expect(source.contains("PATTY_FRIDGE_BURST_HOLD_SEC"), "rapid fridge placement is not debounced", failures)
	var patty_source := FileAccess.get_file_as_string("res://scripts/patty.gd")
	_expect(patty_source.contains("const COOK_VISUAL_HZ := 12.0"), "patty cook visuals are not cadence limited", failures)
	_expect(patty_source.contains("_cook_visual_accum = randf() * COOK_VISUAL_INTERVAL"), "patty visual uploads are not phase staggered", failures)
	_expect(not patty_source.contains("_update_frozen_ball_cook_visual()\n\t_update_frozen_ball_cook_visual()"), "frozen patty visual still updates twice per frame", failures)
	if failures.is_empty():
		print("PERFORMANCE_SCHEDULER_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
