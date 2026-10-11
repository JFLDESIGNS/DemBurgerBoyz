extends SceneTree
class VoiceSubject extends Node3D:
	var voice := "female"
	func get_customer_voice(): return voice
class VoiceAudio extends Node:
	var calls: Array = []
	func play_customer_wawa_click(_impatience: float, voice: String): calls.append(voice)
func _initialize(): call_deferred("run")
func run():
	var c=load("res://scripts/customer.gd").new()
	c._body=Node3D.new();c.add_child(c._body);c._base_body_y=.3
	for phase in [0.0,1.0,2.0,3.0]:
		c._bobble_phase=phase;c._apply_bobble(true)
		assert(is_equal_approx(c._body.position.y,.3))
		assert(c._body.rotation.is_zero_approx())
	c.free()
	var g=load("res://scenes/main.tscn").instantiate()
	g.set_script(load("res://tests/social_shift_fixture.gd"));root.add_child(g);current_scene=g
	for selected in [true,false]:
		assert(is_equal_approx(g._ticket_note_modulate(selected).a,.95))
	g.ticket_opacity=1.0
	assert(is_equal_approx(g._ticket_note_modulate(true).a,.95))
	g._show_customer_review_ui(5.0,"Good burger")
	await create_timer(.3).timeout
	assert(is_equal_approx(g._review_toast.modulate.a,.8))
	var social=load("res://scripts/customer_social.gd").new();social.game=g;g.add_child(social)
	g.game_audio=VoiceAudio.new();g.add_child(g.game_audio)
	var speaker:=VoiceSubject.new();g.add_child(speaker);social.wawa(speaker)
	speaker.voice="male";social.wawa(speaker)
	assert(g.game_audio.calls==["female","male"], "Queue chatter uses the regular voice path for both voices")
	assert(speaker.get_child_count()==0, "Queue chatter must not attach spatial audio")
	print("CUSTOMER_MOTION_OPACITY_OK")
	g.queue_free();await process_frame;quit()
