extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _run() -> void:
	var game_script := load("res://scripts/game.gd")
	var game := Node3D.new()
	game.set_script(game_script)
	game.call("_ensure_spatula_fx_pools")
	var ring_pool: Array = game.get("_spatula_tap_ring_pool")
	var spark_pool: Array = game.get("_spatula_spark_pool")
	if ring_pool.size() != 8 or spark_pool.size() != 4:
		_fail("Spatula FX pools were not fully prebuilt")
		return
	game.call("_spawn_spatula_tap_ring", Vector3(0.25, 0.0, 0.15))
	var active: Array = game.get("_spatula_tap_rings")
	if active.size() != 1 or (game.get("_spatula_tap_ring_pool") as Array).size() != 7:
		_fail("Tap ring did not come from the prebuilt pool")
		return
	var ring: Dictionary = active[0]
	var mi := ring["mi"] as MeshInstance3D
	var shared_mesh := mi.mesh
	game.call("_tick_spatula_tap_rings", 0.10)
	if mi.mesh != shared_mesh or mi.scale.x <= 0.016:
		_fail("Tap ring rebuilt its mesh instead of animating shared-mesh scale")
		return
	game.call("_tick_spatula_tap_rings", 0.30)
	if not (game.get("_spatula_tap_rings") as Array).is_empty() \
			or (game.get("_spatula_tap_ring_pool") as Array).size() != 8:
		_fail("Finished tap ring did not return to the pool")
		return
	for i in 12:
		game.call("_spawn_spatula_tap_ring", Vector3(float(i) * 0.01 + 0.01, 0.0, 0.15))
	if (game.get("_spatula_tap_rings") as Array).size() > 8:
		_fail("Rapid taps allocated beyond the fixed ring pool")
		return
	var audio_script := load("res://scripts/game_audio.gd")
	var audio = audio_script.new()
	root.add_child(audio)
	await process_frame
	await audio.call("prewarm_spatula_audio")
	var cache: Dictionary = audio.get("_cache")
	if not cache.has("tinggrill"):
		_fail("Spatula sample was not preloaded")
		return
	for voice in 3:
		for pad in 5:
			if not cache.has("hold_kit_v4_%d_%d" % [voice, pad]):
				_fail("HOLD voice %d pad %d was not pregenerated" % [voice, pad])
				return
	active.clear()
	ring.clear()
	ring_pool.clear()
	spark_pool.clear()
	mi = null
	shared_mesh = null
	game.free()
	audio.queue_free()
	game = null
	audio = null
	cache = {}
	await process_frame
	await process_frame
	print("SPATULA_SMOOTHING_SMOKE_OK")
	quit(0)
