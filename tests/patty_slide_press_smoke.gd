extends SceneTree
class AudioProbe extends Node:
	var presses := 0
	func play_smash_sizzle(): presses += 1
func _initialize(): call_deferred("run")
func run():
	var g = load("res://scenes/main.tscn").instantiate()
	g.set_script(load("res://tests/main_ticket_harness.gd")); root.add_child(g); current_scene = g; g.playing = true
	var audio = AudioProbe.new(); g.add_child(audio); audio.add_to_group("game_audio")
	var patty = load("res://scripts/patty.gd").new(); g.add_child(patty); patty.set_process(false); patty.set_physics_process(false)
	patty.place_ball_waiting = false; patty.place_morphing = false
	patty.flipped_once = true; patty.first_side_time = 15.0
	var bonus = patty.smash_bonus
	g._begin_patty_drag_local(patty)
	assert(audio.presses == 1 and g.dragging_patty == patty)
	patty._slide_press_tween.custom_step(.07)
	assert(patty.scale.y < .9 and patty.scale.x > 1.05)
	patty._slide_press_tween.custom_step(.3)
	assert(patty.scale.is_equal_approx(Vector3.ONE))
	assert(patty.smash_bonus == bonus and patty.first_side_time == 15.0)
	print("PATTY_SLIDE_PRESS_OK: initial hold squashes and hisses once, cooking unchanged")
	g.queue_free(); await process_frame; quit()
