extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _run() -> void:
	var game_script := load("res://scripts/game.gd") as Script
	var game := Node3D.new()
	game.set_script(game_script)
	var payment_world := Node3D.new()
	root.add_child(payment_world)
	game.set("world", payment_world)
	game.call("_ensure_payment_bill_assets")
	var pool: Array = game.get("_payment_bill_pool")
	var cache: Dictionary = game.get("_payment_bill_mesh_cache")
	if pool.size() != 24:
		_fail("Payment bill pool was not fully prebuilt")
		return
	if cache.size() < 15:
		_fail("All HUD, tip-flight, and settled crinkle variants were not prebuilt")
		return
	var cached_mesh_ids: Dictionary = {}
	for mesh_value in cache.values():
		cached_mesh_ids[(mesh_value as ArrayMesh).get_instance_id()] = true
	var acquired: Array[MeshInstance3D] = []
	for i in 12:
		var size_mul := 1.615 if i == 11 else 2.04
		var bill: MeshInstance3D = game.call("_acquire_payment_bill", size_mul, i, "SmokeBill")
		if bill == null or not cached_mesh_ids.has(bill.mesh.get_instance_id()):
			_fail("Payout created an uncached bill mesh")
			return
		acquired.append(bill)
	if (game.get("_payment_bill_pool") as Array).size() != 12:
		_fail("Payout did not borrow nodes from the fixed pool")
		return
	for bill in acquired:
		game.call("_recycle_payment_bill", bill)
	if not (game.get("_payment_bill_active") as Array).is_empty() \
			or (game.get("_payment_bill_pool") as Array).size() != 24:
		_fail("Finished payout bills did not fully return to the pool")
		return
	var moving: MeshInstance3D = game.call("_acquire_payment_bill", 2.04, 2, "MovingSmokeBill")
	moving.set_meta("fly_from", Vector3.ZERO)
	moving.set_meta("fly_mid", Vector3(0.0, 1.0, 0.0))
	moving.set_meta("fly_dest", Vector3(1.0, 0.0, 0.0))
	game.call(
		"_start_payment_bill_motion", moving, 0.0, 1.0, Vector3.ONE * 0.22,
		Vector3(0.0, 180.0, 10.0), false, "cubic"
	)
	game.call("_update_payment_bills", 0.5)
	if moving.global_position.y <= 0.1 or moving.scale.x >= 1.0:
		_fail("Shared bill updater did not animate the arc and scale")
		return
	game.call("_update_payment_bills", 0.6)
	if moving.visible or not (game.get("_payment_bill_active") as Array).is_empty() \
			or (game.get("_payment_bill_pool") as Array).size() != 24:
		_fail("Shared bill updater did not recycle the completed visual")
		return
	var audio_script := load("res://scripts/game_audio.gd") as Script
	var audio := Node.new()
	audio.set_script(audio_script)
	root.add_child(audio)
	await process_frame
	audio.call("prewarm_payment_audio")
	var audio_cache: Dictionary = audio.get("_cache")
	if not audio_cache.has("chaching") or not audio_cache.has("score_climb"):
		_fail("Payment audio was not fully prewarmed")
		return
	if audio.get_node_or_null("ChaChing") == null:
		_fail("Cha-ching player was still deferred until first payment")
		return
	acquired.clear()
	moving = null
	pool.clear()
	cache.clear()
	cached_mesh_ids.clear()
	audio_cache.clear()
	game.free()
	payment_world.queue_free()
	audio.queue_free()
	await process_frame
	await process_frame
	print("PAYMENT_BILL_POOL_SMOKE_OK")
	quit(0)
