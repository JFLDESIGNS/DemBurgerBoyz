## Phone arcade: Burger Smush. Clear 2+ groups, build falling 3+ cascades, RMB-swap neighbors.
extends Control

const FoodSpritesScript := preload("res://scripts/food_sprites.gd")

const COLS := 5
const ROWS := 7
const MIN_MATCH := 2
const POOF_PATH := "res://assets/ui/burger_smush_poof.png"
const POOF_COLS := 4
const POOF_ROWS := 4
const POOF_FRAMES := 16
const POOF_SEC := 0.42
const CLEAR_PAUSE := 0.16
const DROP_PAUSE := 0.26
const FALL_SPEED := 11.5
const ROLL_PAUSE := 0.24
const ROLL_SPEED := 7.5
const MAX_CHAIN_STEPS := 20
const ICON_FADE_START_SEC := 60.0
const ICON_EXPIRE_SEC := 120.0

const KINDS: Array[String] = [
	"bun_top", "patty", "cheese", "tomato", "lettuce", "pickle", "bacon", "onion"
]
const KIND_COLORS := {
	"bun_top": Color("E8A85C"),
	"patty": Color("6B3A2A"),
	"cheese": Color("F4D03F"),
	"tomato": Color("FF2D2D"),
	"lettuce": Color("7CB342"),
	"pickle": Color("9CCC65"),
	"bacon": Color("D85B45"),
	"onion": Color("C77DDA"),
}

var _board: Array = [] ## ROWS of COLS String
var _score: int = 0
var _combo: int = 0
var _active: bool = false
var _busy: bool = false
var _poof_frames: Array[Texture2D] = []
var _poofs: Array = [] ## {rect, t}
var _board_rect := Rect2()
var _hover_cell := Vector2i(-1, -1)
var _swap_cell := Vector2i(-1, -1)
var _right_press_cell := Vector2i(-1, -1)
var _pulse_t: float = 0.0
var _toast: String = ""
var _toast_t: float = 0.0
var _drop_offsets: Dictionary = {} ## Vector2i -> rows still falling
var _bursts: Array = [] ## {pos, text, color, t}
var _moves: int = 0
var _best_chain: int = 0
var _tile_textures: Dictionary = {}
var _bottom_roll_offset: float = 0.0 ## Horizontal cell widths remaining in reel animation.
var _bottom_roll_direction: int = 1
var _bottom_roll_count: int = 0
var _tile_ages: Array = [] ## Mirrors _board; each ingredient ages independently.


func _game_audio() -> Node:
	## SMUSH lives several controls below the main game; find its existing audio child.
	var cursor: Node = self
	while cursor != null:
		var audio := cursor.get_node_or_null("GameAudio")
		if audio != null:
			return audio
		cursor = cursor.get_parent()
	return null


func _play_existing_sound(method: StringName, args: Array = []) -> void:
	var audio := _game_audio()
	if audio != null and audio.has_method(method):
		audio.callv(method, args)


func _play_smush_sound(count: int, chain: int) -> void:
	_play_existing_sound(&"play_debris_kuhh_burst", [clampi(count, 1, 6)])
	_play_existing_sound(&"play_debris_bass_pop", [0.58 + minf(float(count), 6.0) * 0.08])
	if chain > 1:
		_play_existing_sound(&"play_tip_jar_ping")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	_load_poof_frames()
	reset_game()
	set_process(false)


func set_active(on: bool) -> void:
	_active = on
	set_process(on)
	if on:
		reset_game()
	queue_redraw()


func reset_game() -> void:
	_score = 0
	_combo = 0
	_busy = false
	_poofs.clear()
	_hover_cell = Vector2i(-1, -1)
	_swap_cell = Vector2i(-1, -1)
	_right_press_cell = Vector2i(-1, -1)
	_drop_offsets.clear()
	_bursts.clear()
	_moves = 0
	_best_chain = 0
	_bottom_roll_offset = 0.0
	_bottom_roll_direction = 1
	_bottom_roll_count = 0
	_toast = ""
	_toast_t = 0.0
	_fill_fresh_board()
	_reset_tile_ages()
	queue_redraw()


func _reset_tile_ages() -> void:
	_tile_ages.clear()
	for y in ROWS:
		var row: Array = []
		for _x in COLS:
			row.append(0.0)
		_tile_ages.append(row)


func _tile_age(cell: Vector2i) -> float:
	if cell.y < 0 or cell.y >= _tile_ages.size():
		return 0.0
	var row: Array = _tile_ages[cell.y]
	if cell.x < 0 or cell.x >= row.size():
		return 0.0
	return float(row[cell.x])


func _tile_alpha(cell: Vector2i) -> float:
	var age := _tile_age(cell)
	if age <= ICON_FADE_START_SEC:
		return 1.0
	return 1.0 - clampf(
		(age - ICON_FADE_START_SEC) / (ICON_EXPIRE_SEC - ICON_FADE_START_SEC),
		0.0,
		1.0
	)


func handle_key(event: InputEventKey) -> bool:
	if not _active:
		return false
	if not event.pressed or event.echo:
		return false
	if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_R:
		reset_game()
		return true
	return false


func _load_poof_frames() -> void:
	_poof_frames.clear()
	if not ResourceLoader.exists(POOF_PATH):
		return
	var sheet: Texture2D = load(POOF_PATH) as Texture2D
	if sheet == null:
		return
	var fw: float = sheet.get_width() / float(POOF_COLS)
	var fh: float = sheet.get_height() / float(POOF_ROWS)
	for i in POOF_FRAMES:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.filter_clip = true
		atlas.region = Rect2(float(i % POOF_COLS) * fw, float(i / POOF_COLS) * fh, fw, fh)
		_poof_frames.append(atlas)


func _fill_fresh_board() -> void:
	_board.clear()
	for y in ROWS:
		var row: Array = []
		for x in COLS:
			row.append(_random_kind())
		_board.append(row)
	## Opening layout keeps tappable pairs, but cascades only begin after a player move.
	for _i in 180:
		var groups := _all_match_groups(3)
		if groups.is_empty():
			break
		var g: Array = groups[0]
		if g.is_empty():
			break
		var cell: Vector2i = g[randi() % g.size()]
		var old := str(_board[cell.y][cell.x])
		for _attempt in KINDS.size() * 2:
			var replacement := _random_kind()
			if replacement == old:
				continue
			_board[cell.y][cell.x] = replacement
			if _flood(cell).size() < 3:
				break
	## Guarantee at least one obvious pair to start with.
	if _all_match_groups(2).is_empty():
		_board[ROWS - 1][1] = _board[ROWS - 1][0]
		if _board[ROWS - 1][2] == _board[ROWS - 1][0]:
			_board[ROWS - 1][2] = KINDS[(KINDS.find(str(_board[ROWS - 1][0])) + 1) % KINDS.size()]


func _random_kind() -> String:
	return KINDS[randi() % KINDS.size()]


func _on_gui_input(ev: InputEvent) -> void:
	if not _active:
		return
	if ev is InputEventMouseMotion:
		var mm := ev as InputEventMouseMotion
		var next_hover := _cell_at(mm.position)
		if next_hover != _hover_cell:
			_hover_cell = next_hover
			queue_redraw()
		return
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			if _busy:
				return
			if mb.pressed:
				_begin_swap_at(mb.position)
			else:
				_finish_swap_at(mb.position)
			accept_event()
			return
		if _busy or not mb.pressed:
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_try_clear_at(mb.position)
			accept_event()


func _try_clear_at(local_pos: Vector2) -> void:
	var cell := _cell_at(local_pos)
	if cell.x < 0:
		return
	var group := _flood(cell)
	if group.size() < MIN_MATCH:
		_combo = 0
		_flash_toast("Need 2+")
		_play_existing_sound(&"play_error")
		queue_redraw()
		return
	_resolve_clear(group, true)


func _begin_swap_at(local_pos: Vector2) -> void:
	var cell := _cell_at(local_pos)
	if cell.x < 0:
		_swap_cell = Vector2i(-1, -1)
		_right_press_cell = Vector2i(-1, -1)
		queue_redraw()
		return
	_right_press_cell = cell
	if _swap_cell.x >= 0 and cell != _swap_cell and _cells_are_neighbors(_swap_cell, cell):
		var from := _swap_cell
		_right_press_cell = Vector2i(-1, -1)
		_perform_swap(from, cell)
	else:
		_swap_cell = cell
		queue_redraw()


func _finish_swap_at(local_pos: Vector2) -> void:
	if _right_press_cell.x < 0:
		return
	var from := _right_press_cell
	_right_press_cell = Vector2i(-1, -1)
	var cell := _cell_at(local_pos)
	if cell.x >= 0 and cell != from and _cells_are_neighbors(from, cell):
		_perform_swap(from, cell)


func _cells_are_neighbors(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) == 1


func _perform_swap(a: Vector2i, b: Vector2i) -> void:
	if _busy or not _cells_are_neighbors(a, b):
		return
	var ka := str(_board[a.y][a.x])
	var kb := str(_board[b.y][b.x])
	if ka == kb:
		_swap_cell = Vector2i(-1, -1)
		_flash_toast("Pick two different neighbors")
		queue_redraw()
		return
	_board[a.y][a.x] = kb
	_board[b.y][b.x] = ka
	if _tile_ages.size() == ROWS:
		var age_a := _tile_age(a)
		_tile_ages[a.y][a.x] = _tile_age(b)
		_tile_ages[b.y][b.x] = age_a
	_play_existing_sound(&"play_click")
	_play_existing_sound(&"play_spatula_whoosh")
	_swap_cell = Vector2i(-1, -1)
	_moves += 1
	var hit: Dictionary = {}
	for start in [a, b]:
		var g := _flood(start)
		if g.size() >= MIN_MATCH:
			for c in g:
				hit[c] = true
	if hit.is_empty():
		## Strategic swaps stay in place, allowing the player to set up a cascade.
		_combo = 0
		_flash_toast("SWAPPED · set up a chain")
		queue_redraw()
		return
	var group: Array = []
	for k in hit.keys():
		group.append(k)
	_resolve_clear(group, false)


func _remove_cells(group: Array, chain: int, from_tap: bool) -> int:
	var unique := {}
	for value in group:
		unique[value] = true
	var n := unique.size()
	if n <= 0:
		return 0
	var center := Vector2.ZERO
	for value in unique.keys():
		var rc: Vector2i = value
		center += _cell_rect(rc).get_center()
		_spawn_poof(_cell_rect(rc))
		_board[rc.y][rc.x] = ""
		if rc.y < _tile_ages.size() and rc.x < (_tile_ages[rc.y] as Array).size():
			_tile_ages[rc.y][rc.x] = 0.0
	center /= float(n)
	var multiplier := maxi(chain, 1)
	var gain := n * n * multiplier
	if n >= 4:
		gain += 28 * multiplier
	elif n == 3:
		gain += 12 * multiplier
	if from_tap and n == 2:
		gain += 2
	_score += gain
	var burst_col := Color("FFF08A")
	if n >= 4:
		burst_col = Color("FFD24A")
	elif n == 3:
		burst_col = Color("FFE29A")
	elif chain > 1:
		burst_col = Color("7FFFD4")
	_bursts.append({
		"pos": center,
		"text": "+%d" % gain,
		"color": burst_col,
		"t": 0.0,
	})
	return gain


func _groups_to_cells(groups: Array) -> Array:
	var cells := {}
	for group_value in groups:
		var group: Array = group_value
		for cell in group:
			cells[cell] = true
	return cells.keys()


func _resolve_clear(group: Array, from_tap: bool) -> void:
	if _busy or group.size() < MIN_MATCH:
		return
	_busy = true
	_combo = 1
	var n := group.size()
	var gain := _remove_cells(group, 1, from_tap)
	_play_smush_sound(n, 1)
	_moves += 1 if from_tap else 0
	if n >= 4:
		_flash_toast("SUPER BONUS +%d" % gain)
	elif n == 3:
		_flash_toast("BONUS +%d" % gain)
	elif not from_tap:
		_flash_toast("SWAP +%d" % gain)
	else:
		_flash_toast("SMUSH +%d" % gain)
	queue_redraw()
	await get_tree().create_timer(CLEAR_PAUSE).timeout
	if not _active:
		_busy = false
		return
	_drop_and_fill()
	queue_redraw()
	await get_tree().create_timer(DROP_PAUSE).timeout
	if not _active:
		_busy = false
		return
	var chain := 1
	var chain_steps := 0
	while chain_steps < MAX_CHAIN_STEPS:
		chain_steps += 1
		## Every successful smush advances the bottom row like a slot reel.
		_roll_bottom_row()
		_flash_toast("BOTTOM REEL!")
		queue_redraw()
		await get_tree().create_timer(ROLL_PAUSE).timeout
		if not _active:
			_busy = false
			return

		## Only the bottom row pays. Connected tiles above stay put.
		var next_matches := _bottom_match_groups()
		if next_matches.is_empty():
			break
		chain += 1
		_combo = chain
		_best_chain = maxi(_best_chain, chain)
		var cascade_cells := _groups_to_cells(next_matches)
		var chain_n := cascade_cells.size()
		var chain_gain := _remove_cells(cascade_cells, chain, false)
		_play_smush_sound(chain_n, chain)
		if chain_n >= 4:
			_flash_toast("SUPER BONUS x%d  +%d" % [chain, chain_gain])
		elif chain_n == 3:
			_flash_toast("BONUS x%d  +%d" % [chain, chain_gain])
		else:
			_flash_toast("REEL SMUSH x%d  +%d" % [chain, chain_gain])
		queue_redraw()
		await get_tree().create_timer(CLEAR_PAUSE).timeout
		if not _active:
			_busy = false
			return
		_drop_and_fill()
		queue_redraw()
		await get_tree().create_timer(DROP_PAUSE).timeout
		if not _active:
			_busy = false
			return
	_busy = false
	if chain == 1:
		_combo = 0
	queue_redraw()


func _flash_toast(msg: String) -> void:
	_toast = msg
	_toast_t = 0.85


func _spawn_poof(cell_r: Rect2) -> void:
	_poofs.append({"rect": cell_r.grow(6.0), "t": 0.0})


func _drop_and_fill() -> void:
	_drop_offsets.clear()
	for x in COLS:
		var stack: Array = []
		for y in range(ROWS - 1, -1, -1):
			var kind := str(_board[y][x])
			if kind != "":
				stack.append({"kind": kind, "from_y": y, "age": _tile_age(Vector2i(x, y))})
		var spawn_index := 0
		for y in range(ROWS - 1, -1, -1):
			var idx: int = ROWS - 1 - y
			if idx < stack.size():
				var item: Dictionary = stack[idx]
				_board[y][x] = str(item["kind"])
				_tile_ages[y][x] = float(item.get("age", 0.0))
				var rows_fallen := float(y - int(item["from_y"]))
				if rows_fallen > 0.0:
					_drop_offsets[Vector2i(x, y)] = rows_fallen
			else:
				_board[y][x] = _random_kind()
				_tile_ages[y][x] = 0.0
				_drop_offsets[Vector2i(x, y)] = float(y + spawn_index + 1)
				spawn_index += 1
	_play_existing_sound(&"play_bun_thud", [0.34])


func _collapse_to_bottom() -> void:
	## Timed-out ingredients leave permanent vacancies, but gravity keeps those
	## vacancies at the top of each column. Unlike _drop_and_fill(), this does
	## not create replacement ingredients.
	_drop_offsets.clear()
	var moved := false
	for x in COLS:
		var stack: Array = []
		for y in range(ROWS - 1, -1, -1):
			var kind := str(_board[y][x])
			if kind != "":
				stack.append({"kind": kind, "from_y": y, "age": _tile_age(Vector2i(x, y))})
		for y in range(ROWS - 1, -1, -1):
			var idx: int = ROWS - 1 - y
			if idx < stack.size():
				var item: Dictionary = stack[idx]
				_board[y][x] = str(item["kind"])
				_tile_ages[y][x] = float(item.get("age", 0.0))
				var rows_fallen := float(y - int(item["from_y"]))
				if rows_fallen > 0.0:
					_drop_offsets[Vector2i(x, y)] = rows_fallen
					moved = true
			else:
				_board[y][x] = ""
				_tile_ages[y][x] = 0.0
	if moved:
		_play_existing_sound(&"play_bun_thud", [0.26])


func _roll_bottom_row() -> void:
	if _board.size() != ROWS or _board[ROWS - 1].size() != COLS:
		return
	var row: Array = _board[ROWS - 1]
	var age_row: Array = _tile_ages[ROWS - 1] if _tile_ages.size() == ROWS else []
	if _bottom_roll_direction > 0:
		row.push_front(row.pop_back())
		if age_row.size() == COLS:
			age_row.push_front(age_row.pop_back())
		_bottom_roll_offset = -1.0
	else:
		row.push_back(row.pop_front())
		if age_row.size() == COLS:
			age_row.push_back(age_row.pop_front())
		_bottom_roll_offset = 1.0
	_board[ROWS - 1] = row
	if age_row.size() == COLS:
		_tile_ages[ROWS - 1] = age_row
	_bottom_roll_direction *= -1
	_bottom_roll_count += 1
	_play_existing_sound(&"play_spatula_whoosh")


func _bottom_match_groups() -> Array:
	## Horizontal 2+ runs on the bottom row only. Same-kind tiles above are ignored.
	var result: Array = []
	var seen := {}
	var y := ROWS - 1
	if _board.size() != ROWS:
		return result
	var row: Array = _board[y]
	for x in COLS:
		var start := Vector2i(x, y)
		if seen.has(start):
			continue
		if x >= row.size():
			continue
		var kind := str(row[x])
		if kind == "":
			continue
		var group: Array = []
		var q: Array = [start]
		seen[start] = true
		while not q.is_empty():
			var c: Vector2i = q.pop_back()
			group.append(c)
			for dx in [-1, 1]:
				var n := Vector2i(c.x + dx, y)
				if n.x < 0 or n.x >= COLS or seen.has(n):
					continue
				if n.x >= row.size():
					continue
				if str(row[n.x]) != kind:
					continue
				seen[n] = true
				q.append(n)
		if group.size() >= MIN_MATCH:
			result.append(group)
	return result


func _flood(start: Vector2i) -> Array:
	if start.x < 0 or start.y < 0 or start.x >= COLS or start.y >= ROWS:
		return []
	var kind := str(_board[start.y][start.x])
	if kind == "":
		return []
	var seen := {}
	var out: Array = []
	var q: Array = [start]
	seen[start] = true
	while not q.is_empty():
		var c: Vector2i = q.pop_back()
		out.append(c)
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= COLS or n.y >= ROWS:
				continue
			if seen.has(n):
				continue
			if str(_board[n.y][n.x]) != kind:
				continue
			seen[n] = true
			q.append(n)
	return out


func _all_match_groups(min_n: int) -> Array:
	var seen := {}
	var groups: Array = []
	for y in ROWS:
		for x in COLS:
			var cell := Vector2i(x, y)
			if seen.has(cell):
				continue
			var g := _flood(cell)
			for c in g:
				seen[c] = true
			if g.size() >= min_n:
				groups.append(g)
	return groups


func _process(delta: float) -> void:
	if not _active:
		return
	_pulse_t += delta
	var dirty := false
	## Age only while SMUSH is open. Expired ingredients leave real empty spaces;
	## gravity moves those spaces to the tops of their columns.
	var expired_any := false
	if _tile_ages.size() == ROWS and _board.size() == ROWS:
		for y in ROWS:
			if (_tile_ages[y] as Array).size() != COLS or (_board[y] as Array).size() != COLS:
				continue
			for x in COLS:
				if str(_board[y][x]) == "":
					continue
				var age := float(_tile_ages[y][x]) + delta
				_tile_ages[y][x] = age
				if age >= ICON_EXPIRE_SEC:
					_board[y][x] = ""
					_tile_ages[y][x] = 0.0
					expired_any = true
					dirty = true
				elif age >= ICON_FADE_START_SEC:
					dirty = true
	if expired_any:
		_collapse_to_bottom()
	if _toast_t > 0.0:
		_toast_t = maxf(0.0, _toast_t - delta)
		dirty = true
	for cell in _drop_offsets.keys():
		var remaining := maxf(0.0, float(_drop_offsets[cell]) - delta * FALL_SPEED)
		if remaining <= 0.001:
			_drop_offsets.erase(cell)
		else:
			_drop_offsets[cell] = remaining
		dirty = true
	if absf(_bottom_roll_offset) > 0.001:
		_bottom_roll_offset = move_toward(_bottom_roll_offset, 0.0, delta * ROLL_SPEED)
		dirty = true
	else:
		_bottom_roll_offset = 0.0
	var i := 0
	while i < _poofs.size():
		var p: Dictionary = _poofs[i]
		p["t"] = float(p.get("t", 0.0)) + delta
		if float(p["t"]) >= POOF_SEC:
			_poofs.remove_at(i)
			dirty = true
			continue
		_poofs[i] = p
		i += 1
		dirty = true
	i = 0
	while i < _bursts.size():
		var burst: Dictionary = _bursts[i]
		burst["t"] = float(burst.get("t", 0.0)) + delta
		if float(burst["t"]) >= 0.72:
			_bursts.remove_at(i)
			dirty = true
			continue
		_bursts[i] = burst
		i += 1
		dirty = true
	if _swap_cell.x >= 0 or dirty:
		queue_redraw()


func _board_area() -> Rect2:
	var pad := 3.0
	## Fill almost the whole phone glass; keep a slim header and footer.
	return Rect2(pad, 26.0, size.x - pad * 2.0, maxf(140.0, size.y - 62.0))


func _cell_rect(cell: Vector2i) -> Rect2:
	var board := _board_area()
	var cw := board.size.x / float(COLS)
	var ch := board.size.y / float(ROWS)
	## Use the full slot instead of centering a tiny square inside a wide column.
	return Rect2(
		board.position + Vector2(float(cell.x) * cw, float(cell.y) * ch),
		Vector2(cw, ch)
	).grow(-0.25)


func _cell_at(local_pos: Vector2) -> Vector2i:
	var board := _board_area()
	if not board.has_point(local_pos):
		return Vector2i(-1, -1)
	var cw := board.size.x / float(COLS)
	var ch := board.size.y / float(ROWS)
	var x := clampi(int((local_pos.x - board.position.x) / cw), 0, COLS - 1)
	var y := clampi(int((local_pos.y - board.position.y) / ch), 0, ROWS - 1)
	return Vector2i(x, y)


func _draw() -> void:
	## Deep teal counter backdrop with warm arcade glow.
	draw_rect(Rect2(Vector2.ZERO, size), Color("071C21"), true)
	var band_h := maxf(size.y / 12.0, 1.0)
	for band in 12:
		var mix := float(band) / 11.0
		var band_color := Color("0E3540").lerp(Color("07161D"), mix)
		draw_rect(Rect2(0.0, float(band) * band_h, size.x, band_h + 1.0), band_color, true)
	## Header and score card.
	draw_rect(Rect2(0.0, 0.0, size.x, 28.0), Color("102A32"), true)
	var board := _board_area()
	_board_rect = board
	draw_rect(board.grow(3.0), Color(0.0, 0.0, 0.0, 0.34), true)
	draw_rect(board, Color("020304"), true)
	if _board.size() != ROWS:
		return
	var hover_group: Array = []
	if _hover_cell.x >= 0:
		var hg := _flood(_hover_cell)
		if hg.size() >= MIN_MATCH:
			hover_group = hg
	var font := ThemeDB.fallback_font
	for y in ROWS:
		var row: Array = _board[y]
		for x in COLS:
			if x >= row.size():
				continue
			var kind := str(row[x])
			if kind == "":
				continue
			var cell := Vector2i(x, y)
			var rect := _cell_rect(cell).grow(-1.0)
			if _drop_offsets.has(cell):
				var cell_h := board.size.y / float(ROWS)
				rect.position.y -= float(_drop_offsets[cell]) * cell_h
			if y == ROWS - 1 and absf(_bottom_roll_offset) > 0.001:
				var cell_w := board.size.x / float(COLS)
				rect.position.x += _bottom_roll_offset * cell_w
			if _tile_age(cell) >= ICON_FADE_START_SEC:
				rect.position.y += sin(_pulse_t * 3.2 + float(x) * 0.9 + float(y) * 0.45) * 2.4
			var lit := hover_group.has(cell)
			var picked := cell == _swap_cell
			_draw_ingredient(rect, kind, lit, picked, _tile_alpha(cell))
	for p in _poofs:
		_draw_poof(p)
	for burst_value in _bursts:
		var burst: Dictionary = burst_value
		var bt := float(burst.get("t", 0.0))
		## Point popups report in the status well, never over ingredient art.
		var burst_pos := Vector2(size.x - 70.0, board.end.y + 12.0 - bt * 4.0)
		var burst_col: Color = burst.get("color", Color.WHITE)
		burst_col.a = 1.0 - clampf(bt / 0.72, 0.0, 1.0)
		draw_string(font, burst_pos - Vector2(18.0, 0.0), str(burst.get("text", "+0")), HORIZONTAL_ALIGNMENT_CENTER, 36.0, 13, burst_col)
	draw_string(font, Vector2(6.0, 12.0), "BURGER SMUSH", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("FFB000"))
	draw_string(font, Vector2(size.x - 96.0, 12.0), str(_score), HORIZONTAL_ALIGNMENT_RIGHT, 90.0, 13, Color.WHITE)
	## One compact status line under the board.
	var status_text := _toast if _toast_t > 0.0 and _toast != "" else ("CHAIN x%d!" % _combo if _combo > 1 else "")
	if status_text != "":
		var status_alpha := clampf(_toast_t / 0.35, 0.0, 1.0) if _toast_t > 0.0 else 1.0
		draw_string(
			font,
			Vector2(8.0, size.y - 22.0),
			status_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			size.x - 16.0,
			11,
			Color(0.50, 1.0, 0.84, status_alpha)
		)
	var stats := "MOVES %d" % _moves
	if _best_chain > 1:
		stats += "   BEST x%d" % _best_chain
	if status_text == "":
		draw_string(font, Vector2(8.0, size.y - 22.0), stats, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("8FC4CE"))
	draw_string(
		font,
		Vector2(8.0, size.y - 8.0),
		"LMB SMUSH 2+  ·  RMB SWAP  ·  R RESET",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		9,
		Color("D5E8EC")
	)


func _draw_ingredient(cell: Rect2, kind: String, lit: bool, picked: bool, icon_alpha: float = 1.0) -> void:
	var c := cell.get_center()
	## Clean black arcade cells keep all attention on the large ingredient artwork.
	draw_rect(cell, Color("030405"), true)
	draw_rect(cell, Color("22282C"), false, 1.0)
	if lit:
		draw_rect(cell.grow(1.0), Color("FFE066"), false, 2.5)
	if picked:
		var pulse := 2.2 + sin(_pulse_t * 8.0) * 0.8
		draw_rect(cell.grow(pulse), Color("FFB000"), false, 3.0)
	var tex: Texture2D = _tile_textures.get(kind)
	if tex == null:
		tex = FoodSpritesScript.get_tex(kind)
		_tile_textures[kind] = tex
	if tex != null:
		var aspect := float(tex.get_height()) / maxf(float(tex.get_width()), 1.0)
		var art_w := cell.size.x * 0.98
		## Fill the larger playfield slots so ingredients read bigger on the phone.
		var art_h := art_w * aspect * 1.28
		if art_h > cell.size.y * 0.98:
			art_h = cell.size.y * 0.98
			art_w = art_h / maxf(aspect, 0.01)
		art_h = maxf(art_h, cell.size.y * 0.62)
		var art_rect := Rect2(c - Vector2(art_w, art_h) * 0.5, Vector2(art_w, art_h))
		draw_texture_rect(tex, Rect2(art_rect.position + Vector2(1.5, 2.0), art_rect.size), false, Color(0.0, 0.0, 0.0, 0.28 * icon_alpha))
		var art_tint := Color(1.28, 0.92, 0.92) if kind == "tomato" else Color.WHITE
		art_tint.a = icon_alpha
		draw_texture_rect(tex, art_rect, false, art_tint)


func _draw_poof(p: Dictionary) -> void:
	var t: float = float(p.get("t", 0.0))
	var rect: Rect2 = p.get("rect", Rect2())
	if _poof_frames.is_empty():
		var a := 1.0 - clampf(t / POOF_SEC, 0.0, 1.0)
		draw_circle(rect.get_center(), rect.size.x * 0.35 * (1.0 + t * 2.0), Color(1, 1, 1, a * 0.85))
		return
	var idx := clampi(int(t / POOF_SEC * float(POOF_FRAMES)), 0, POOF_FRAMES - 1)
	var tex: Texture2D = _poof_frames[idx]
	draw_texture_rect(tex, rect, false)
