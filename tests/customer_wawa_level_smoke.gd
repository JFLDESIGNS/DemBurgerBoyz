extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var audio = load("res://scripts/game_audio.gd").new()
	root.add_child(audio)
	audio.sfx_levels["customers"] = 1.0
	audio.play_customer_wawa_click(0.5, "male")
	assert(audio._customer_click_wawa is AudioStreamPlayer, "Customer chatter must be non-spatial")
	assert(audio._customer_click_wawa.volume_db > -10.0, "Chatter attack must not start near silence")
	await audio._customer_click_wawa_tween.finished
	var male_db: float = audio._customer_click_wawa.volume_db
	print("MALE_WAWA_DB ", male_db)
	audio.play_customer_wawa_click(0.5, "female")
	assert(male_db > audio._female_customer_wawa.volume_db + 8.0, "Quieter male recording needs source-level compensation")
	audio.sfx_levels["world"] = 0.0
	audio.play_customer_dance_wawa(0.5, "male")
	assert(audio._customer_dance_wawa.volume_db > 0.0, "Customer speech must use Customers, not World volume")
	audio.sfx_levels["customers"] = 0.5
	assert(absf(audio._male_customer_wawa_db() - male_db + 6.0206) < 0.1)
	audio.sfx_levels["customers"] = 1.0
	audio.play_customer_angry_wawa("male")
	await audio._customer_click_wawa_tween.finished
	assert(absf(audio._customer_click_wawa.volume_db - audio._male_customer_wawa_db(1.0) - 3.0) < .1, "Angry male cue gains 3 dB through its fade")
	audio.play_customer_angry_wawa("female")
	assert(absf(audio._female_customer_wawa.volume_db - audio._sfx_db(1.72, "customers")) < .1, "Angry female cue gains 3 dB over the softer female baseline")
	audio.sfx_levels["customers"] = 0.0
	audio.play_customer_angry_wawa("male")
	await audio._customer_click_wawa_tween.finished
	assert(audio._customer_click_wawa.volume_db <= -80.0, "Customer mute must still work")
	audio.queue_free()
	await process_frame
	print("CUSTOMER_WAWA_LEVEL_OK")
	quit()
