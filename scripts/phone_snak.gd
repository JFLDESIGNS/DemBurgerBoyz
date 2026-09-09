## Phone arcade: Snak. Arrow keys steer; eat dots; don't hit yourself or the wall.
extends Control

const COLS := 11
const ROWS := 16
const STEP_SEC := 0.15

var _dir := Vector2i(1, 0)
var _pending := Vector2i(1, 0)
var _snake: Array[Vector2i] = []
var _food := Vector2i(7, 8)
var _tick: float = 0.0
var _alive: bool = true
var _started: bool = false
var _score: int = 0
var _active: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	reset_game()
	set_process(false)


func set_active(on: bool) -> void:
	_active = on
	set_process(on)
	if on:
		reset_game()
	queue_redraw()


func reset_game() -> void:
	_dir = Vector2i(1, 0)
	_pending = Vector2i(1, 0)
	_snake.clear()
	_snake.append(Vector2i(3, 8))
	_snake.append(Vector2i(2, 8))
	_snake.append(Vector2i(1, 8))
	_alive = true
	_started = false
	_score = 0
	_tick = 0.0
	_place_food()
	queue_redraw()


func handle_key(event: InputEventKey) -> bool:
	if not _active:
		return false
	if not event.pressed or event.echo:
		return false
	var code := event.keycode
	if code == KEY_NONE:
		code = event.physical_keycode
	var next := Vector2i.ZERO
	match code:
		KEY_LEFT:
			next = Vector2i(-1, 0)
		KEY_RIGHT:
			next = Vector2i(1, 0)
		KEY_UP:
			next = Vector2i(0, -1)
		KEY_DOWN:
			next = Vector2i(0, 1)
		KEY_SPACE, KEY_ENTER:
			if not _alive:
				reset_game()
				return true
			return false
		_:
			return false
	if next == Vector2i.ZERO:
		return false
	if not _alive:
		reset_game()
		return true
	if next + _dir == Vector2i.ZERO:
		return true
	_pending = next
	_started = true
	return true


func _on_gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if not _alive:
			reset_game()
			accept_event()


func _process(delta: float) -> void:
	if not _active or not _alive or not _started:
		return
	_tick += delta
	var step := maxf(0.07, STEP_SEC - float(_score) * 0.004)
	if _tick < step:
		return
	_tick -= step
	_dir = _pending
	var head: Vector2i = _snake[0] + _dir
	if head.x < 0 or head.y < 0 or head.x >= COLS or head.y >= ROWS:
		_alive = false
		queue_redraw()
		return
	for i in _snake.size():
		if _snake[i] == head:
			_alive = false
			queue_redraw()
			return
	_snake.insert(0, head)
	if head == _food:
		_score += 1
		_place_food()
	else:
		_snake.pop_back()
	queue_redraw()


func _place_food() -> void:
	var tries := 0
	while tries < 80:
		var cell := Vector2i(randi() % COLS, randi() % ROWS)
		var hit := false
		for part in _snake:
			if part == cell:
				hit = true
				break
		if not hit:
			_food = cell
			return
		tries += 1
	_food = Vector2i(COLS / 2, ROWS / 2)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.04, 0.10, 0.06, 1.0), true)
	var pad := 6.0
	var board := Rect2(pad, 22.0, size.x - pad * 2.0, size.y - 44.0)
	if board.size.x < 8.0 or board.size.y < 8.0:
		return
	draw_rect(board, Color(0.07, 0.16, 0.09, 1.0), true)
	draw_rect(board, Color(0.35, 0.82, 0.42, 0.85), false, 1.5)
	var cw := board.size.x / float(COLS)
	var ch := board.size.y / float(ROWS)
	for part in _snake:
		var cell := Rect2(board.position + Vector2(float(part.x) * cw, float(part.y) * ch), Vector2(cw - 1.0, ch - 1.0))
		draw_rect(cell, Color(0.45, 0.95, 0.38, 1.0), true)
	var head_c := Rect2(board.position + Vector2(float(_snake[0].x) * cw, float(_snake[0].y) * ch), Vector2(cw - 1.0, ch - 1.0))
	draw_rect(head_c, Color(0.75, 1.0, 0.45, 1.0), true)
	var food_c := Rect2(board.position + Vector2(float(_food.x) * cw, float(_food.y) * ch), Vector2(cw - 1.0, ch - 1.0))
	draw_rect(food_c, Color(1.0, 0.78, 0.18, 1.0), true)
	var font := ThemeDB.fallback_font
	var fs := 13
	draw_string(font, Vector2(8.0, 16.0), "SNAK  %d" % _score, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.82, 1.0, 0.78))
	var foot := "ARROWS STEER"
	if not _started and _alive:
		foot = "ARROWS TO START"
	elif not _alive:
		foot = "OUCH — TAP / ARROW"
	draw_string(font, Vector2(8.0, size.y - 6.0), foot, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.75, 0.92, 0.72))
