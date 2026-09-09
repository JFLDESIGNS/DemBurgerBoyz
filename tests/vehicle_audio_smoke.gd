extends SceneTree


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	var audio_script := load("res://scripts/game_audio.gd") as Script
	assert(audio_script != null)
	var audio := Node.new()
	audio.set_script(audio_script)
	root.add_child(audio)
	await process_frame

	var keys: Array[String] = []
	for entry_var in audio.get_sfx_tuning_entries():
		keys.append(str((entry_var as Dictionary).get("key", "")))
	assert("traffic_pass" in keys)
	assert("traffic_horn" in keys)
	assert(ResourceLoader.exists("res://sounds/vehicles/car_pass_by_left_to_right.ogg"))
	assert(ResourceLoader.exists("res://sounds/vehicles/car_horn_double_beep.wav"))

	audio.play_car_pass_by()
	audio.play_car_horn()
	await process_frame
	var pass_player := audio.get_node_or_null("StreetCarPass") as AudioStreamPlayer
	var horn_player := audio.get_node_or_null("StreetCarHorn") as AudioStreamPlayer
	assert(pass_player != null and pass_player.stream != null)
	assert(horn_player != null and horn_player.stream != null)
	audio.stop_car_pass_by()
	audio.queue_free()
	await process_frame
	pass_player = null
	horn_player = null
	audio = null
	audio_script = null
	await process_frame
	print("VEHICLE_AUDIO_SMOKE_OK")
	quit(0)
