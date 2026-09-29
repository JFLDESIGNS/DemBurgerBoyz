extends SceneTree
class Recorder extends Node:
	var hits: Array = []
	func play_spatula_drum(pad: int, volume: float, voice: int): hits.append([pad,volume,voice])
func _initialize(): call_deferred("run")
func run() -> void:
	var g = load("res://scenes/main.tscn").instantiate(); g.set_script(load("res://tests/main_ticket_harness.gd"))
	root.add_child(g); current_scene = g
	var audio = Recorder.new(); g.add_child(audio); g.game_audio = audio
	for pad in 5:
		g._play_grill_tap_at(g._grill_song_drum_world(pad), 1.0, 0.0, false)
		assert(audio.hits.back() == [pad,1.0,[1,0,0,0,2][pad]])
	g._play_grill_tap_at(g._grill_song_drum_world(2),1.0,g.HAND_SPATULA_ROLL_MAX,false)
	assert(audio.hits.back() == [2,1.0,2])
	g.queue_free(); await process_frame
	print("HOLD_DRUM_LAYOUT_OK: hats on edges, central kick/snare/tom, tilt hats preserved")
	quit()
