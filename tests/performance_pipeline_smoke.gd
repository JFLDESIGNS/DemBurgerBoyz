extends SceneTree


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _init() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/game.gd")
	var failures: Array[String] = []
	_expect(source.contains("func _ensure_serve_fx_pools()"), "serve FX pool is missing", failures)
	_expect(source.contains("const SERVE_CRUMB_POOL_SIZE := 30"), "crumb pool is missing", failures)
	_expect(not source.contains("ctw.tween_property(crumb"), "crumb burst still creates per-crumb tweens", failures)
	_expect(source.contains("func _ensure_station_layer_control"), "station layer pool is missing", failures)
	var refresh_start := source.find("func _refresh_station(index: int)")
	var refresh_end := source.find("\n\nfunc _station_patty_has_cheese", refresh_start)
	var refresh_body := source.substr(refresh_start, refresh_end - refresh_start)
	_expect(not refresh_body.contains("child.queue_free()"), "station refresh still deletes preview layers", failures)
	_expect(source.contains("func _queue_station_review_thumbnail"), "review thumbnail cache is missing", failures)
	_expect(source.contains("call_deferred(\"_finish_serve_deferred\""), "serve tail is not deferred", failures)
	_expect(source.contains("func _mp_queue_frame_state"), "multiplayer frame batch is missing", failures)
	_expect(source.contains("_perf_hot_end(\"multiplayer_serialize\""), "multiplayer serialization is not timed", failures)
	_expect(source.contains("_perf_hot_end(\"fridge_open\""), "fridge opening is not timed", failures)
	_expect(source.contains("_perf_hot_end(\"patty_acquisition\""), "patty acquisition is not timed", failures)
	_expect(source.contains("_perf_hot_end(\"supply_refresh\""), "supply refresh is not timed", failures)
	_expect(source.contains("_perf_hot_end(\"serve_commit\""), "serve commit is not timed", failures)
	_expect(source.contains("_perf_hot_end(\"review_encoding\""), "review encoding is not timed", failures)
	_expect(source.contains("patty_fridge_root.global_position = camera.global_position"), "fridge is not camera-staged during prewarm", failures)
	if failures.is_empty():
		print("PERFORMANCE_PIPELINE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
