extends SceneTree
func _initialize(): call_deferred("run")
func run():
	create_timer(60).timeout.connect(func(): quit(1))
	var patties: Array = []
	for i in 4:
		var p = load("res://scripts/patty.gd").new()
		root.add_child(p)
		p.set_process(false)
		assert(p._season_batch != null)
		p.set_meta("batch_id", p._season_batch.get_instance_id())
		patties.append(p)
	var worst_us := 0
	var total_us := 0
	for cycle in 20:
		for p in patties:
			p.reset_for_grill_spawn(0, 1, Vector3.ZERO, 0, true, false)
			assert(p._season_batch.visible_instance_count == 0)
			assert(p._season_batch.get_instance_id() == p.get_meta("batch_id"))
		for tick in 16:
			var start := Time.get_ticks_usec()
			for p in patties: p.apply_seasoning(0.1)
			var elapsed := Time.get_ticks_usec() - start
			worst_us = maxi(worst_us, elapsed)
			total_us += elapsed
		for p in patties:
			assert(is_equal_approx(p.seasoning, 1.0))
			assert(p._season_fleck_count == p.SEASON_MAX_FLECKS)
			assert(p._season_root.get_child_count() == 1)
			assert(p._season_batch.visible_instance_count == p.SEASON_MAX_FLECKS)
		await process_frame
	print("SEASONING_STRESS_OK total_us=", total_us, " worst_batch_us=", worst_us)
	quit()
