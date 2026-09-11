extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _run() -> void:
	## The exact custom preset (including paint) must survive the same deep-copy
	## boundary used by the customer spawn RPC.
	var customer_script := load("res://scripts/customer.gd")
	var customer = customer_script.new()
	var paint_image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	paint_image.fill(Color(0.0, 0.0, 0.0, 0.0))
	paint_image.set_pixel(8, 8, Color(0.1, 0.2, 0.8, 0.85))
	var paint_payload := Marshalls.raw_to_base64(paint_image.save_png_to_buffer())
	var preset := {
		"format_version": 9,
		"name": "Network Tattoo Test",
		"body_type": "kenney_chunky_toon",
		"hair_style": 1,
		"top_style": 1,
		"skin_paint": paint_payload,
	}
	var empty_order: Array[String] = []
	customer.setup(empty_order, Color.WHITE, 60.0, 0, 0, 0, -1, preset, true)
	root.add_child(customer)
	await process_frame
	await process_frame
	var copied: Dictionary = customer.get_custom_character_preset()
	if (
		str(copied.get("name", "")) != "Network Tattoo Test"
		or str(copied.get("skin_paint", "")) != paint_payload
	):
		_fail("Custom character preset/paint did not survive the multiplayer payload boundary")
		return
	if (
		customer.custom_character_name != "Network Tattoo Test"
		or customer.find_child("CreatedCustomer", true, false) == null
	):
		_fail("Customer did not construct the transmitted custom character")
		return
	customer.queue_free()
	await process_frame

	## Solve a route using normal drag calls and deliberately sparse samples.
	var puzzle_script := load("res://scripts/pcb_puzzle.gd")
	var puzzle = puzzle_script.new()
	puzzle.size = Vector2(1280, 720)
	root.add_child(puzzle)
	puzzle.open()
	await process_frame
	var walk: Dictionary = puzzle.get("_walk")
	var start: Vector2i = puzzle.get("_start")
	var finish: Vector2i = puzzle.get("_end")
	var frontier: Array[Vector2i] = [start]
	var came_from: Dictionary = {start: start}
	while not frontier.is_empty() and not came_from.has(finish):
		var current: Vector2i = frontier.pop_front()
		for next: Vector2i in puzzle.call("_neighbors", current):
			if came_from.has(next):
				continue
			came_from[next] = current
			frontier.append(next)
	if not came_from.has(finish):
		_fail("Circuit maze has no path from IN to OUT")
		return
	var path: Array[Vector2i] = []
	var cursor := finish
	while cursor != start:
		path.push_front(cursor)
		cursor = came_from[cursor]
	path.push_front(start)
	puzzle.call("_begin_draw", puzzle.call("_cell_center", start))
	for i in range(1, path.size(), 3):
		puzzle.call("_continue_draw", puzzle.call("_cell_center", path[mini(i + 2, path.size() - 1)]))
	if not bool(puzzle.get("_just_solved")):
		## Branch-heavy mazes can legitimately require closer steering; verify the
		## widened path still works with one event per cell.
		puzzle.call("_reset_trace")
		puzzle.call("_begin_draw", puzzle.call("_cell_center", start))
		for cell in path:
			puzzle.call("_continue_draw", puzzle.call("_cell_center", cell))
	if not bool(puzzle.get("_just_solved")):
		_fail("Circuit route could not be completed through the drag API")
		return
	var board: Rect2 = puzzle.call("_board_rect")
	var hint = puzzle.get("_hint")
	if hint == null or hint.position.y < board.end.y:
		_fail("Circuit instructions are not below the board")
		return
	print("MULTIPLAYER_RECENT_FEATURES_SMOKE_OK")
	quit(0)
