extends SceneTree


func _initialize() -> void:
	call_deferred("_run_test")


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _run_test() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		_fail("Could not load main scene")
		return
	var game := packed.instantiate()
	root.add_child(game)
	current_scene = game
	await create_timer(2.5).timeout
	if game.debris_trap_root != null and is_instance_valid(game.debris_trap_root):
		_fail("Legacy debris trap is still being created")
		return
	var slot := 0
	var spawn := Vector3(game.GRILL_CENTER_X, game.GRILL_SURFACE_Y + 0.03, game.GRILL_SURFACE_Z)
	game.call("_leave_grill_residue_local", slot, spawn, false, "patty", 1.0)
	if float(game.grill_residue[slot]) <= 0.04:
		_fail("Could not create normal grill debris")
		return
	game.call("_scrape_finish_clean_local", slot)
	if float(game.grill_residue[slot]) > 0.0:
		_fail("Normal debris did not clean away")
		return
	if not game.debris_piles.is_empty():
		_fail("Normal debris still converts into a loose strip")
		return
	print("DEBRIS SIMPLIFICATION test passed: normal residue cleans without strip or trap")
	game.queue_free()
	await process_frame
	quit(0)
