extends SceneTree
class LastCustomer extends Node3D:
	var is_cut_collector = false
	var is_street_pedestrian = false
func _initialize(): call_deferred("run")
func run() -> void:
	create_timer(90).timeout.connect(func(): push_error("SHIFT_BOSS_TIMEOUT"); quit(1))
	var g = load("res://scenes/main.tscn").instantiate()
	g.set_script(load("res://tests/hotdog_challenge_fixture.gd"))
	root.add_child(g); current_scene = g
	g.playing = true; g._kitchen_ready = true; g._bts_day1_performance_done = true
	g.day_time = 10.2
	var last = LastCustomer.new(); g.customers_root.add_child(last); g.customers.append(last)
	g._update_shift_clock(.1)
	assert(not g._hotdog_active() and g.day_time > 10)
	g._update_shift_clock(.2)
	assert(g.day_time == 10 and not g._hotdog_active() and g._challenge_blocks_spawns())
	g._update_shift_clock(20)
	assert(g.day_time == 10, "Last customer must not use up the closing countdown")
	g.customers.erase(last)
	g._update_shift_clock(1)
	assert(not g._hotdog_active(), "Wait for the last customer to actually walk offscreen")
	g._end_day(); assert(g.playing and not is_instance_valid(g._shift_results))
	last.free()
	g._serve_fly_busy = true; g._update_shift_clock(1); assert(not g._hotdog_active())
	g._serve_fly_busy = false; g._update_shift_clock(1)
	var boss = g._hotdog_challenge; boss.set_process(false)
	assert(boss.phase == "rumble" and g._hotdog_shift_triggered and g.day_time == 10)
	var generation = boss.generation
	g._update_shift_clock(30)
	assert(boss.generation == generation and g.day_time == 10)
	g._end_day(); assert(g.playing and not is_instance_valid(g._shift_results))
	boss.cancel()
	g._update_shift_clock(3)
	assert(g.day_time == 7 and not g._hotdog_active() and g._challenge_blocks_spawns())
	g._update_shift_clock(7)
	assert(g.day_time == 0 and not g._hotdog_shift_due())
	g._hotdog_shift_triggered = false; g.day_time = 10; g.tutorial_mode = true
	g._update_shift_clock(1); assert(not g._hotdog_active())
	g.queue_free(); await process_frame
	print("HOTDOG_SHIFT_OK: ten-second cutoff, last departure, handoff, single trigger, frozen clock, blocked lights, closing countdown, tutorial exclusion")
	quit()
