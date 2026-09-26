## Phone arcade: Snak. Arrow keys steer; eat dots; don't hit yourself or the wall.
extends Control
var party = null
var party_id := ""

const COLS := 11
const ROWS := 16
const STEP_SEC := 0.15

var partner := false
var _snake2: Array[Vector2i] = []
var _dir2 := Vector2i.LEFT
var _pending2 := Vector2i.LEFT
var _alive2 := true
var _foods: Array[Vector2i] = []
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
	if _active == on: return
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
	_snake2.clear();_foods.clear();_alive2=true;_dir2=Vector2i.LEFT;_pending2=_dir2
	if partner: join_second()
	for i in 3: _place_food()
	queue_redraw()


func handle_key(event: InputEventKey) -> bool:
	if party != null and party.input_event(self,event): return true
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
	if party != null and party.input_event(self,ev): accept_event();return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if not _alive:
			reset_game()
			accept_event()


func _process(delta: float) -> void:
	if party != null and party.online() and not party.host(): queue_redraw();return
	if not _active or not _alive or not _started:
		return
	_tick += delta
	var step := maxf(0.07, STEP_SEC - float(_score) * 0.004)
	if _tick < step:
		return
	_tick -= step
	_dir = _pending
	_dir2 = _pending2
	var next1: Vector2i = _snake[0]+_dir
	var next2: Vector2i = _snake2[0]+_dir2 if partner and not _snake2.is_empty() else Vector2i(-99,-99)
	var hit1 := _blocked(next1,_snake,_snake2 if partner else [])
	var hit2 := _blocked(next2,_snake2,_snake) if partner else false
	if partner and next1==next2:hit1=true;hit2=true
	if hit1 or hit2:
		_alive=false;_alive2=not hit2;queue_redraw();return
	_snake.push_front(next1)
	if next1 in _foods:_foods.erase(next1);_score+=1;_place_food()
	else:_snake.pop_back()
	if partner:
		_snake2.push_front(next2)
		if next2 in _foods:_foods.erase(next2);_score+=1;_place_food()
		else:_snake2.pop_back()
	queue_redraw()

func _blocked(cell: Vector2i, own: Array, other: Array) -> bool:
	return cell.x<0 or cell.y<0 or cell.x>=COLS or cell.y>=ROWS or cell in own or cell in other
func join_second():
	if not partner or not _snake2.is_empty():return
	for y in range(2,ROWS-2):
		var cells: Array[Vector2i]=[Vector2i(8,y),Vector2i(9,y),Vector2i(10,y)]
		if cells[0] not in _snake and cells[1] not in _snake and cells[2] not in _snake:
			_snake2=cells;return
func second_key(key: int, pressed: bool):
	if not pressed:return
	if not _alive:reset_game();return
	var direction: Vector2i={KEY_UP:Vector2i.UP,KEY_DOWN:Vector2i.DOWN,KEY_LEFT:Vector2i.LEFT,KEY_RIGHT:Vector2i.RIGHT}.get(key,Vector2i.ZERO)
	if direction!=Vector2i.ZERO and direction+_dir2!=Vector2i.ZERO:_pending2=direction;_started=true


func _place_food() -> void:
	var empty: Array[Vector2i]=[]
	for y in ROWS:
		for x in COLS:
			var cell:=Vector2i(x,y)
			if cell not in _snake and cell not in _snake2 and cell not in _foods:empty.append(cell)
	if not empty.is_empty():_foods.append(empty.pick_random())


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
	if partner:
		for part in _snake2:
			draw_rect(Rect2(board.position+Vector2(part)*Vector2(cw,ch),Vector2(cw-1,ch-1)),Color("77CCFF"))
	for food in _foods:
		draw_circle(board.position+(Vector2(food)+Vector2(.5,.5))*Vector2(cw,ch),minf(cw,ch)*.35,Color("FF644B"))
	var font := ThemeDB.fallback_font
	var fs := 13
	draw_string(font, Vector2(8.0, 16.0), "SNAK  %d" % _score, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.82, 1.0, 0.78))
	var foot := "ARROWS STEER"
	if not _started and _alive:
		foot = "ARROWS TO START"
	elif not _alive:
		foot = "OUCH — TAP / ARROW"
	if party!=null and party.online() and _alive:foot=party.status(party_id)
	draw_string(font, Vector2(8.0, size.y - 6.0), foot, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.75, 0.92, 0.72))
