extends SceneTree
class Mobile extends "res://scripts/grubbah.gd":
	func publish() -> void: pass
	func update_visuals(_delta: float) -> void: pass
func _initialize(): call_deferred("run")
func run() -> void:
	create_timer(45).timeout.connect(func(): quit(1))
	var g = load("res://scenes/main.tscn").instantiate()
	g.set_script(load("res://tests/hotdog_challenge_fixture.gd"))
	root.add_child(g); current_scene = g; g.playing = true; g._kitchen_ready = true
	var boss = g._ensure_hotdog_challenge(); boss.set_process(false)
	var mobile = Mobile.new(); g.add_child(mobile); mobile.game = g; mobile.set_process(false)
	mobile.props = Node3D.new(); mobile.add_child(mobile.props); mobile.was_playing = true
	mobile.wait_time = .5
	assert(boss.start())
	for phase in ["rumble", "emerge", "ready", "feeding", "slump", "revive", "revive_smash_first", "revive_smash_second", "victory", "results"]:
		boss.phase = phase
		mobile._process(2.0)
		mobile.new_order()
		assert(mobile.state.is_empty() and mobile.next_number == 1)
		assert(mobile.wait_time == .5, "Boss must pause mobile arrival countdown")
	boss.cancel()
	mobile._process(.6)
	assert(not mobile.state.is_empty() and mobile.next_number == 2, "Mobile orders resume after challenge")
	mobile.state = {}; g._challenge_phase = "active"
	mobile.new_order(); assert(mobile.state.is_empty())
	g.queue_free(); await process_frame
	print("BOSS_MOBILE_ORDERS_OK: automatic and direct arrivals blocked throughout encounter, countdown preserved and resumes")
	quit()
