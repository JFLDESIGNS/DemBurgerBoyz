## Full-screen PCB maze overlay. Drag along the copper from IN to OUT.
extends Control

const UiFontsScript := preload("res://scripts/ui_fonts.gd")

const BOARD_PATH := "res://assets/ui/puzzle_pcb_board.jpg"
const COLS := 17
const ROWS := 17
const TRACE := Color(0.93, 0.76, 0.16, 1.0)
const TRACE_SHADOW := Color(0.04, 0.16, 0.09, 0.58)
const TRACE_HI := Color(1.0, 0.96, 0.72, 0.42)
const DRAWN := Color(1.0, 0.90, 0.38, 1.0)
const DRAWN_CORE := Color(1.0, 0.98, 0.86, 0.95)
const VIA := Color(0.18, 0.09, 0.05, 1.0)
const PAD_RING := Color(0.78, 0.58, 0.12, 1.0)
const RESISTOR := Color(0.78, 0.18, 0.16, 1.0)

## Dense copper. Center 3x3 (cells 7-9) stays empty for the burger CPU.
var MAZES: Array[PackedStringArray] = [
	PackedStringArray([
		"...##......##....",
		".S#.#.......#.#E.",
		"#.###.......###..",
		"#.#...........#.#",
		"###...........#.#",
		"..#.#.......#.#.#",
		"###.#.......#.###",
		"#.#.#.......#.#..",
		"#.###.......###..",
		"#.#...........#..",
		"..#..#.#.#.#..#..",
		"#.#..#.#.#.#..#.#",
		"###..#.#.#.#..#.#",
		"..#..#.#.#.#..#.#",
		"###..#.#.#.#..###",
		"#.#############..",
		"##...............",
	]),
	PackedStringArray([
		".................",
		".###############.",
		".#.............#.",
		".#...........###.",
		".#...........#.#.",
		".#...........#.#.",
		".#..#.E...#..#.#.",
		".#..#.#...#.#..#.",
		".#..#.#...#.##.#.",
		".#..###...#..###.",
		".#....#...#....#.",
		".#....######.#.#.",
		".#.....#...#.###.",
		".#.....#.###...#.",
		".#.....#.#.#...#.",
		".S.....#.#.#####.",
		".......#.#.....##",
	]),
	PackedStringArray([
		".................",
		".S##############.",
		"#..............#.",
		"################.",
		".#...........#...",
		".######...##.#...",
		"..#...#####..#.#.",
		"..#.......#..#.#.",
		"..#.......#.#..#.",
		"..#.......#.#..#.",
		"..........######.",
		".....#..#......#.",
		".....#..#.#.##.#.",
		".....#..#.##.###.",
		".....#..#..#...#.",
		".E##############.",
		".................",
	]),
	PackedStringArray([
		"....##.....###...",
		".#.S.#######.#.E.",
		".#.#.#.....#.#.#.",
		".#.#.#.###.#...#.",
		".###.###...#.#.#.",
		"#..#.#.....#.#.#.",
		"##.#.#.....#.###.",
		".###.#.....#...#.",
		"#..#.#.....#...#.",
		"##.#.#.....#...#.",
		".###.#.#.###.#.#.",
		"#..#.#.#.#.#.#.#.",
		"##.#.#.#.#.#.#.#.",
		".###.###.#.###.#.",
		"...#.#.....#...#.",
		"...###.....#####.",
		"...............##",
	]),
	PackedStringArray([
		"......##.##.##...",
		"..S....#..#..#...",
		"#.#....#..#..#...",
		"#.#..##########..",
		"###..#........#..",
		"..#..#.###.####E.",
		"#.#..###...#..#..",
		"###.#.#....#..#..",
		"..#.#.#....#..#..",
		"#.#.###....#..#..",
		"###...#....#..#..",
		"..#...######..#..",
		"#.#..#......#.#.#",
		"###..##.##..#.#.#",
		"..#...#..#..#.###",
		"..#############..",
		".................",
	]),
]

signal closed
signal puzzle_solved(maze_index: int)

var _board_tex: Texture2D = null
var _maze_index: int = 0
var _repair_lock: bool = false
var _walk: Dictionary = {} ## Vector2i -> true
var _start: Vector2i = Vector2i.ZERO
var _end: Vector2i = Vector2i.ZERO
var _drawn: Array[Vector2i] = []
var _dragging: bool = false
var _solved: Array[bool] = [false, false, false, false, false]
var _just_solved: bool = false
var _pulse: float = 0.0
var _title: Label = null
var _hint: Label = null
var _status: Label = null
var _close_btn: Button = null
var _reset_btn: Button = null
var _next_btn: Button = null
var _bar: HBoxContainer = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_process(false)
	gui_input.connect(_on_gui_input)
	resized.connect(func() -> void:
		_layout_chrome()
		queue_redraw()
	)


func is_open() -> bool:
	return visible


func open() -> void:
	if _board_tex == null:
		_board_tex = load(BOARD_PATH) as Texture2D
	if get_child_count() == 0:
		_build_chrome()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_load_maze(_maze_index)
	_refresh_chrome()
	set_process(true)
	queue_redraw()


func open_random_repair() -> void:
	_repair_lock = true
	_maze_index = randi() % MAZES.size()
	_solved[_maze_index] = false
	open()


func close() -> void:
	_dragging = false
	_repair_lock = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	closed.emit()


func handle_key(event: InputEventKey) -> bool:
	if not visible or not event.pressed or event.echo:
		return false
	if event.keycode == KEY_ESCAPE or event.keycode == KEY_QUOTELEFT \
			or event.physical_keycode == KEY_QUOTELEFT:
		close()
		return true
	if event.keycode == KEY_R:
		_reset_trace()
		return true
	if _repair_lock:
		return false
	if event.keycode >= KEY_1 and event.keycode <= KEY_5:
		_load_maze(event.keycode - KEY_1)
		return true
	return false


func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()


func _build_chrome() -> void:
	UiFontsScript.ensure_loaded()
	_title = Label.new()
	_title.text = "TRACE THE TRACE"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFontsScript.apply_luckiest_label(_title, 28)
	_title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45, 1.0))
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)

	_hint = Label.new()
	_hint.text = "Drag IN to OUT. Dead ends need a backtrack. Stay on copper.  `  or Esc closes."
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFontsScript.apply_luckiest_label(_hint, 14)
	_hint.add_theme_color_override("font_color", Color(0.82, 0.92, 0.70, 0.95))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFontsScript.apply_luckiest_label(_status, 18)
	_status.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35, 1.0))
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_status)

	_close_btn = _make_btn("CLOSE", _on_close_pressed)
	add_child(_close_btn)

	_bar = HBoxContainer.new()
	_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_bar.add_theme_constant_override("separation", 10)
	add_child(_bar)

	_reset_btn = _make_btn("RESET  (R)", _reset_trace)
	_bar.add_child(_reset_btn)
	for i in range(MAZES.size()):
		var idx: int = i
		var b: Button = _make_btn(str(i + 1), func() -> void: _load_maze(idx))
		b.custom_minimum_size = Vector2(44, 36)
		b.set_meta("maze_i", i)
		_bar.add_child(b)
	_next_btn = _make_btn("NEXT", _goto_next)
	_bar.add_child(_next_btn)


func _make_btn(text: String, cb: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(88, 36)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UiFontsScript.apply_luckiest_button(b, 15)
	b.add_theme_color_override("font_color", Color(1.0, 0.93, 0.55, 1.0))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.80, 1.0))
	var n: StyleBoxFlat = StyleBoxFlat.new()
	n.bg_color = Color(0.08, 0.22, 0.12, 0.92)
	n.set_corner_radius_all(8)
	n.set_border_width_all(2)
	n.border_color = Color(0.82, 0.68, 0.18, 0.95)
	b.add_theme_stylebox_override("normal", n)
	var h: StyleBoxFlat = n.duplicate() as StyleBoxFlat
	h.bg_color = Color(0.12, 0.32, 0.16, 0.95)
	b.add_theme_stylebox_override("hover", h)
	var p: StyleBoxFlat = n.duplicate() as StyleBoxFlat
	p.bg_color = Color(0.16, 0.40, 0.18, 0.95)
	b.add_theme_stylebox_override("pressed", p)
	b.pressed.connect(cb)
	return b


func _on_close_pressed() -> void:
	close()


func _goto_next() -> void:
	if _repair_lock:
		return
	_load_maze((_maze_index + 1) % MAZES.size())


func _load_maze(index: int) -> void:
	if _repair_lock and index != _maze_index and _maze_index >= 0:
		return
	_maze_index = clampi(index, 0, MAZES.size() - 1)
	_walk.clear()
	_drawn.clear()
	_dragging = false
	_just_solved = _solved[_maze_index]
	var rows: PackedStringArray = MAZES[_maze_index]
	for y in range(ROWS):
		var row: String = rows[y]
		for x in range(COLS):
			var ch: String = row.substr(x, 1)
			if ch == ".":
				continue
			var cell: Vector2i = Vector2i(x, y)
			_walk[cell] = true
			if ch == "S":
				_start = cell
			elif ch == "E":
				_end = cell
	_refresh_chrome()
	queue_redraw()


func _reset_trace() -> void:
	_drawn.clear()
	_dragging = false
	if not _solved[_maze_index]:
		_just_solved = false
	_refresh_chrome()
	queue_redraw()


func _refresh_chrome() -> void:
	if _title != null:
		if _repair_lock:
			_title.text = "REPAIR TRACE   ·   ROUTE %d / %d" % [_maze_index + 1, MAZES.size()]
		else:
			_title.text = "TRACE THE TRACE   ·   ROUTE %d / %d" % [_maze_index + 1, MAZES.size()]
	if _hint != null and _repair_lock:
		_hint.text = "Fix the short — drag IN to OUT. Dead ends need a backtrack."
	if _status != null:
		if _repair_lock and (_just_solved or _solved[_maze_index]):
			_status.text = "ROUTE COMPLETE  ·  MACHINE ONLINE"
		elif _all_solved():
			_status.text = "ALL ROUTES TRACED"
		elif _just_solved or _solved[_maze_index]:
			_status.text = "ROUTE COMPLETE"
		else:
			_status.text = ""
	if _next_btn != null:
		_next_btn.visible = (not _repair_lock) and _solved[_maze_index]
	if _bar != null:
		for child in _bar.get_children():
			if child is Button and (child as Button).has_meta("maze_i"):
				(child as Button).visible = not _repair_lock
	_layout_chrome()


func _all_solved() -> bool:
	for i in range(_solved.size()):
		if not _solved[i]:
			return false
	return true


func _layout_chrome() -> void:
	var s: Vector2 = size
	if s.x < 8.0:
		return
	if _title != null:
		_title.position = Vector2(0.0, 10.0)
		_title.size = Vector2(s.x, 36.0)
	if _hint != null:
		_hint.position = Vector2(20.0, 42.0)
		_hint.size = Vector2(s.x - 40.0, 24.0)
	if _status != null:
		_status.position = Vector2(0.0, 64.0)
		_status.size = Vector2(s.x, 26.0)
	if _close_btn != null:
		_close_btn.position = Vector2(s.x - 108.0, 12.0)
		_close_btn.size = Vector2(92.0, 36.0)
	if _bar != null:
		_bar.position = Vector2(20.0, s.y - 52.0)
		_bar.size = Vector2(s.x - 40.0, 40.0)


func _board_rect() -> Rect2:
	var s: Vector2 = size
	var side: float = minf(s.x, s.y) * 0.72
	var pos: Vector2 = Vector2((s.x - side) * 0.5, (s.y - side) * 0.5 + 8.0)
	return Rect2(pos, Vector2(side, side))


func _maze_inner() -> Rect2:
	var b: Rect2 = _board_rect()
	var inset: float = b.size.x * 0.12
	return Rect2(b.position + Vector2(inset, inset), b.size - Vector2(inset, inset) * 2.0)


func _maze_cell_size() -> float:
	var inner: Rect2 = _maze_inner()
	return minf(inner.size.x / float(COLS), inner.size.y / float(ROWS))


func _maze_origin() -> Vector2:
	var inner: Rect2 = _maze_inner()
	var cell: float = _maze_cell_size()
	return inner.position + Vector2(
		(inner.size.x - cell * float(COLS)) * 0.5,
		(inner.size.y - cell * float(ROWS)) * 0.5
	)


func _cell_center(cell: Vector2i) -> Vector2:
	var cs: float = _maze_cell_size()
	var origin: Vector2 = _maze_origin()
	return origin + Vector2((float(cell.x) + 0.5) * cs, (float(cell.y) + 0.5) * cs)


func _cell_at(pos: Vector2) -> Vector2i:
	var origin: Vector2 = _maze_origin()
	var cs: float = _maze_cell_size()
	var local: Vector2 = pos - origin
	var c: Vector2i = Vector2i(int(floor(local.x / cs)), int(floor(local.y / cs)))
	if not _walk.has(c):
		return Vector2i(-1, -1)
	if _cell_center(c).distance_to(pos) > cs * 0.58:
		return Vector2i(-1, -1)
	return c


func _neighbors(cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
	]
	for d in dirs:
		var n: Vector2i = cell + d
		if _walk.has(n):
			out.append(n)
	return out


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_begin_draw(mb.position)
		else:
			_dragging = false
		accept_event()
	elif event is InputEventMouseMotion:
		if _dragging:
			_continue_draw((event as InputEventMouseMotion).position)
			accept_event()


func _begin_draw(pos: Vector2) -> void:
	if _solved[_maze_index] and _drawn.size() > 0 and _drawn[_drawn.size() - 1] == _end:
		return
	var cell: Vector2i = _cell_at(pos)
	if cell.x < 0:
		return
	if _drawn.is_empty():
		if cell != _start:
			return
		_drawn.append(_start)
		_dragging = true
		queue_redraw()
		return
	var last: Vector2i = _drawn[_drawn.size() - 1]
	if cell == last:
		_dragging = true
		return
	if _drawn.size() >= 2 and cell == _drawn[_drawn.size() - 2]:
		_drawn.remove_at(_drawn.size() - 1)
		_dragging = true
		queue_redraw()
		return
	if cell in _neighbors(last) and not _drawn.has(cell):
		_drawn.append(cell)
		_dragging = true
		_check_solved()
		queue_redraw()


func _continue_draw(pos: Vector2) -> void:
	if _drawn.is_empty():
		return
	var cell: Vector2i = _cell_at(pos)
	if cell.x < 0:
		return
	var last: Vector2i = _drawn[_drawn.size() - 1]
	if cell == last:
		return
	if _drawn.size() >= 2 and cell == _drawn[_drawn.size() - 2]:
		_drawn.remove_at(_drawn.size() - 1)
		queue_redraw()
		return
	if cell in _neighbors(last) and not _drawn.has(cell):
		_drawn.append(cell)
		_check_solved()
		queue_redraw()


func _check_solved() -> void:
	if _just_solved:
		return
	if _drawn.is_empty():
		return
	if _drawn[0] != _start:
		return
	if _drawn[_drawn.size() - 1] != _end:
		return
	_solved[_maze_index] = true
	_just_solved = true
	_dragging = false
	_refresh_chrome()
	puzzle_solved.emit(_maze_index)


func _draw() -> void:
	var s: Vector2 = size
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.01, 0.04, 0.02, 0.78), true)
	var board: Rect2 = _board_rect()
	if _board_tex != null:
		draw_texture_rect(_board_tex, board, false)
	else:
		draw_rect(board, Color(0.12, 0.32, 0.16, 1.0), true)
	var copper: Array[Vector2i] = []
	for key in _walk.keys():
		copper.append(key)
	_draw_network(copper, TRACE_SHADOW, 1.0, Vector2(2.4, 3.0))
	_draw_network(copper, TRACE, 1.0, Vector2.ZERO)
	_draw_network(copper, TRACE_HI, 0.42, Vector2(-1.1, -1.2))
	_draw_junction_pads()
	if _drawn.size() >= 1:
		_draw_network(_drawn, Color(0.15, 0.12, 0.02, 0.35), 1.08, Vector2(1.6, 2.0))
		_draw_network(_drawn, DRAWN, 1.08, Vector2.ZERO)
		_draw_network(_drawn, DRAWN_CORE, 0.38, Vector2.ZERO)
	_draw_io_pads()
	_draw_resistor_deco()


func _draw_network(cells: Array[Vector2i], color: Color, width_mul: float, offset: Vector2) -> void:
	if cells.is_empty():
		return
	var cs: float = _maze_cell_size()
	var half: float = cs * 0.30 * width_mul
	var present: Dictionary = {}
	for cell in cells:
		present[cell] = true
	for cell in cells:
		var a: Vector2 = _cell_center(cell) + offset
		draw_circle(a, half, color, true, -1.0, true)
		if present.has(cell + Vector2i(1, 0)):
			draw_line(a, _cell_center(cell + Vector2i(1, 0)) + offset, color, half * 2.0, true)
		if present.has(cell + Vector2i(0, 1)):
			draw_line(a, _cell_center(cell + Vector2i(0, 1)) + offset, color, half * 2.0, true)


func _draw_junction_pads() -> void:
	var cs: float = _maze_cell_size()
	for key in _walk.keys():
		var cell: Vector2i = key
		if cell == _start or cell == _end:
			continue
		var n: int = _neighbors(cell).size()
		if n != 1 and n != 3 and n != 4:
			continue
		var p: Vector2 = _cell_center(cell)
		var r: float = cs * (0.20 if n == 1 else 0.24)
		draw_circle(p + Vector2(1.6, 2.0), r, TRACE_SHADOW)
		draw_circle(p, r, TRACE)
		draw_circle(p, r * 0.38, VIA)


func _draw_io_pads() -> void:
	var cs: float = _maze_cell_size()
	var glow: float = 1.0 + 0.06 * sin(_pulse * 4.0)
	_draw_one_pad(_start, cs * 0.34 * (glow if _drawn.is_empty() else 1.0), "IN")
	_draw_one_pad(_end, cs * 0.34, "OUT")


func _draw_one_pad(cell: Vector2i, radius: float, tag: String) -> void:
	var p: Vector2 = _cell_center(cell)
	draw_circle(p + Vector2(2.0, 2.6), radius, TRACE_SHADOW)
	draw_circle(p, radius, TRACE)
	draw_circle(p, radius * 0.78, PAD_RING)
	draw_circle(p, radius * 0.32, VIA)
	var font: Font = UiFontsScript.luckiest
	if font == null:
		return
	var fs: int = clampi(int(radius * 0.72), 9, 14)
	var sz: Vector2 = font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs)
	draw_string(
		font,
		p + Vector2(-sz.x * 0.5, radius + fs + 2.0),
		tag,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		fs,
		Color(0.95, 0.90, 0.55, 0.95)
	)


func _draw_resistor_deco() -> void:
	## Tiny red component in leftover green so the board reads as a PCB.
	var board: Rect2 = _board_rect()
	var p: Vector2 = board.position + Vector2(board.size.x * 0.18, board.size.y * 0.86)
	var body: Rect2 = Rect2(p, Vector2(board.size.x * 0.07, board.size.y * 0.018))
	draw_rect(Rect2(body.position + Vector2(1.5, 2.0), body.size), Color(0.05, 0.16, 0.08, 0.45), true, -1.0, true)
	draw_rect(body, RESISTOR, true, -1.0, true)
	draw_rect(Rect2(body.position, Vector2(body.size.x, body.size.y * 0.35)), Color(1.0, 0.55, 0.45, 0.35), true)
