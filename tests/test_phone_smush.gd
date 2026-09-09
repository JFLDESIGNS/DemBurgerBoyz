extends SceneTree

const SmushScript := preload("res://scripts/phone_smush.gd")


func _initialize() -> void:
	call_deferred("_run_test")


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _checker_board() -> Array:
	var kinds := ["bun_top", "patty", "cheese", "tomato", "lettuce", "pickle", "bacon", "onion"]
	var board: Array = []
	for y in SmushScript.ROWS:
		var row: Array = []
		for x in SmushScript.COLS:
			row.append(kinds[(x + y * 2) % kinds.size()])
		board.append(row)
	return board


func _run_test() -> void:
	seed(8128)
	var smush := SmushScript.new()
	smush.size = Vector2(236, 478)
	root.add_child(smush)
	smush.set_active(true)
	await process_frame

	if SmushScript.COLS != 5 or SmushScript.ROWS != 7:
		_fail("SMUSH board should be the 5x7 layout")
		return
	if not SmushScript.KINDS.has("bacon") or not SmushScript.KINDS.has("onion"):
		_fail("Bacon and onion are missing from SMUSH")
		return
	var bun_count := 0
	for kind in SmushScript.KINDS:
		if "bun" in kind:
			bun_count += 1
	if bun_count != 1:
		_fail("SMUSH should contain exactly one bun icon")
		return

	## A successful smush must roll the bottom reel and pay any resulting 2+ group.
	var board := _checker_board()
	var last := SmushScript.ROWS - 1
	board[last] = ["bun_top", "patty", "cheese", "onion", "bun_top"]
	board[0][0] = "bacon"
	board[0][1] = "bacon"
	smush._board = board
	smush._resolve_clear([Vector2i(0, 0), Vector2i(1, 0)], true)
	var deadline := Time.get_ticks_msec() + 5000
	while smush._busy and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	if smush._busy:
		_fail("SMUSH reel cascade resolver did not finish")
		return
	if smush._bottom_roll_count < 1 or smush._best_chain < 2 or smush._score <= 6:
		_fail("Bottom reel did not roll and auto-smush its 2+ payout: score=%d best_chain=%d rolls=%d" % [smush._score, smush._best_chain, smush._bottom_roll_count])
		return

	## Connected 3+ groups above the bottom row must not auto-pop after a smush.
	smush.reset_game()
	var stay_board := _checker_board()
	stay_board[2][2] = "cheese"
	stay_board[2][3] = "cheese"
	stay_board[2][4] = "cheese"
	stay_board[last] = ["patty", "patty", "onion", "bacon", "lettuce"]
	smush._board = stay_board
	smush._reset_tile_ages()
	smush._resolve_clear([Vector2i(0, last), Vector2i(1, last)], true)
	deadline = Time.get_ticks_msec() + 5000
	while smush._busy and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	if str(smush._board[2][2]) != "cheese" or str(smush._board[2][3]) != "cheese" or str(smush._board[2][4]) != "cheese":
		_fail("Smush auto-cleared a 3-group above the bottom row")
		return
	smush._board = _checker_board()
	if smush._remove_cells([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)], 1, true) < 21:
		_fail("Connecting 3 should pay a bonus")
		return
	smush._board = _checker_board()
	if smush._remove_cells([Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)], 1, true) < 44:
		_fail("Connecting 4 should pay a super bonus")
		return

	## A no-match right-click swap must remain on the board for strategic setup.
	smush._board = _checker_board()
	var before_a := str(smush._board[0][0])
	var before_b := str(smush._board[0][1])
	smush._perform_swap(Vector2i(0, 0), Vector2i(1, 0))
	if str(smush._board[0][0]) != before_b or str(smush._board[0][1]) != before_a:
		_fail("Right-click neighbor swap did not remain in place")
		return
	if smush.FoodSpritesScript.get_tex("tomato") == null:
		_fail("Real Burger Pals ingredient artwork is unavailable")
		return
	if smush.FoodSpritesScript.get_tex("bacon") == null or smush.FoodSpritesScript.get_tex("onion") == null:
		_fail("Bacon or onion artwork is unavailable")
		return
	## Ingredients remain solid for one minute, fade for the next, then leave blanks.
	## Gravity must collapse the column so its vacancy ends up at the top.
	smush._board = _checker_board()
	smush._reset_tile_ages()
	smush._tile_ages[0][0] = 90.0
	if smush._tile_alpha(Vector2i(0, 0)) > 0.51 or smush._tile_alpha(Vector2i(0, 0)) < 0.49:
		_fail("A 90-second icon should be halfway faded")
		return
	var expected_bottom := str(smush._board[SmushScript.ROWS - 2][0])
	smush._tile_ages[SmushScript.ROWS - 1][0] = 119.9
	smush._process(0.2)
	if str(smush._board[0][0]) != "":
		_fail("A timed-out icon did not leave its vacancy at the top")
		return
	if str(smush._board[SmushScript.ROWS - 1][0]) != expected_bottom:
		_fail("Icons did not fall down to fill a timed-out vacancy")
		return
	var playfield: Rect2 = smush._board_area()
	if playfield.end.y > smush.size.y - 18.0:
		_fail("SMUSH playfield does not leave a separate bottom status area")
		return
	if playfield.size.y < smush.size.y - 80.0:
		_fail("SMUSH playfield should use more of the phone screen")
		return
	var slot: Rect2 = smush._cell_rect(Vector2i.ZERO)
	if slot.size.x < playfield.size.x / float(SmushScript.COLS) * 0.90:
		_fail("SMUSH icons are still wasting horizontal slot space")
		return
	print("PHONE SMUSH test passed: 5x7 grid, status well, audio-safe reel, timed fade and gravity expiry")
	quit(0)
