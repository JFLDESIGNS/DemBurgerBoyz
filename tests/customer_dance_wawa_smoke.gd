extends SceneTree


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _init() -> void:
	var customer_source := FileAccess.get_file_as_string("res://scripts/customer.gd")
	var audio_source := FileAccess.get_file_as_string("res://scripts/game_audio.gd")
	var failures: Array[String] = []
	_expect(customer_source.contains("const LEAVE_DANCE_MAX_SEC := 3.0"), "customer dance is not capped at three seconds", failures)
	_expect(customer_source.contains("dur = minf(dur, LEAVE_DANCE_MAX_SEC)"), "animation duration does not honor the dance cap", failures)
	_expect(customer_source.contains("audio.play_customer_dance_wawa(dur)"), "dance does not start the wa-wa voice", failures)
	_expect(customer_source.contains("audio.stop_customer_dance_wawa()"), "dance cancellation does not stop its voice", failures)
	_expect(audio_source.contains("const DANCE_WAWA_PITCH := 1.42"), "dance wa-wa is not pitched higher", failures)
	_expect(audio_source.contains("func play_customer_dance_wawa"), "dedicated dance voice player is missing", failures)
	_expect(audio_source.contains("duration_sec, 0.05, DANCE_WAWA_CLIP_SEC"), "dance voice is not hard-capped", failures)
	if failures.is_empty():
		print("CUSTOMER_DANCE_WAWA_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
