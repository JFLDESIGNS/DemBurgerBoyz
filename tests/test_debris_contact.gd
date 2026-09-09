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
	var spawn := Vector3(game.GRILL_CENTER_X, game.GRILL_SURFACE_Y, game.GRILL_SURFACE_Z)
	game.call("_add_scraped_debris_pile", spawn, 0.8, -1)
	if game.debris_piles.is_empty():
		_fail("Could not create a debris pile")
		return
	var pile: Dictionary = game.debris_piles.back()
	var pile_root := pile.get("root") as Node3D
	var start := pile_root.position
	## Ten centimeters toward the cook is visibly off the thin PNG and must not push it.
	game.call("_nudge_debris_piles", start + Vector3(0.0, 0.0, -0.10), Vector2(0.02, 0.0), 0.02)
	if pile_root.position.distance_to(start) > 0.0001:
		_fail("Debris still moves while the tool is visibly in front of the PNG")
		return
	## Direct contact at the pile center must still move it.
	game.call("_nudge_debris_piles", start, Vector2(0.02, 0.0), 0.02)
	if pile_root.position.distance_to(start) < 0.001:
		_fail("Debris does not move on direct contact")
		return
	print("DEBRIS CONTACT test passed: off-image tool ignored, direct contact pushes pile")
	game.queue_free()
	await process_frame
	quit(0)
