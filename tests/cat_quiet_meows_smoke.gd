extends SceneTree

class CatAudio extends Node:
	var calls := 0
	func play_cat_begging_meow(_pitch: float): calls += 1

class CatGame extends Node:
	var game_audio: Node

func _initialize():
	var cat = load("res://scripts/window_cat.gd").new()
	var calls: Array = []
	cat.wants_meow.connect(func(pitch): calls.append(pitch))
	cat._state = "peek"
	cat.visible = true
	cat._update_begging_meows(11.99)
	assert(calls.is_empty())
	cat._update_begging_meows(0.02)
	assert(calls.size() == 1)
	cat._update_begging_meows(7.9)
	assert(calls.size() == 1, "No repeat begging before eight seconds")
	cat._visit_fed = true
	cat._update_begging_meows(60.0)
	assert(calls.size() == 1)
	cat.free()
	var game = CatGame.new()
	var audio = CatAudio.new()
	game.game_audio = audio
	var courier = load("res://scripts/mail_delivery_truck.gd").new()
	courier.game = game
	courier.delivery_meows_active = true
	for i in 600:
		courier._update_delivery_meows(0.1)
	assert(audio.calls == 2 and courier.meow_count == 2)
	assert(not courier.delivery_meows_active)
	courier.free()
	audio.free()
	game.free()
	assert(load("res://scripts/game.gd") != null)
	assert(load("res://sounds/cat_begging_meow.mp3") != null)
	print("CAT_QUIET_MEOWS_OK: delayed begging, spaced repeats, two delivery calls, recorded asset available")
	quit()
