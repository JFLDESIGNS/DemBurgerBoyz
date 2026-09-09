## Phone arcade: Gnop. Arrow keys move the left paddle; bounce the ball past the CPU.
extends Control

const PADDLE_H := 46.0
const PADDLE_W := 7.0
const BALL := 6.0
const PADDLE_SPEED := 210.0
const BALL_SPEED := 165.0

var _player_y: float = 80.0
var _cpu_y: float = 80.0
var _ball := Vector2(80.0, 90.0)
var _vel := Vector2(BALL_SPEED, 90.0)
var _score_p: int = 0
var _score_c: int = 0
var _alive: bool = true
var _started: bool = false
var _active: bool = false
var _up: bool = false
var _down: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	reset_game()
	set_process(false)


func set_active(on: bool) -> void:
	_active = on
	set_process(on)
	_up = false
	_down = false
	if on:
		reset_game()
	queue_redraw()


func reset_game() -> void:
	_player_y = 80.0
	_cpu_y = 80.0
	_ball = Vector2(88.0, 100.0)
	_vel = Vector2(BALL_SPEED, 70.0)
	_alive = true
	_started = false
	_score_p = 0
	_score_c = 0
	queue_redraw()


func handle_key(event: InputEventKey) -> bool:
	if not _active:
		return false
	var code := event.keycode
	if code == KEY_NONE:
		code = event.physical_keycode
	if event.echo:
		return false
	match code:
		KEY_UP:
			_up = event.pressed
			if event.pressed and not _alive:
				reset_game()
			elif event.pressed:
				_started = true
			return true
		KEY_DOWN:
			_down = event.pressed
			if event.pressed and not _alive:
				reset_game()
			elif event.pressed:
				_started = true
			return true
		KEY_SPACE, KEY_ENTER:
			if event.pressed and not _alive:
				reset_game()
				return true
			return false
		_:
			return false


func _on_gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if not _alive:
			reset_game()
			accept_event()


func _process(delta: float) -> void:
	if not _active:
		return
	var field := _field()
	var max_y := maxf(0.0, field.size.y - PADDLE_H)
	_player_y = clampf(_player_y, 0.0, max_y)
	_cpu_y = clampf(_cpu_y, 0.0, max_y)
	if _alive and _started:
		if _up:
			_player_y -= PADDLE_SPEED * delta
		if _down:
			_player_y += PADDLE_SPEED * delta
		_player_y = clampf(_player_y, 0.0, max_y)
		_ball += _vel * delta
		var cpu_c := _cpu_y + PADDLE_H * 0.5
		var ball_c := _ball.y
		if cpu_c < ball_c - 4.0:
			_cpu_y += PADDLE_SPEED * 0.78 * delta
		elif cpu_c > ball_c + 4.0:
			_cpu_y -= PADDLE_SPEED * 0.78 * delta
		_cpu_y = clampf(_cpu_y, 0.0, max_y)
		if _ball.y < 0.0:
			_ball.y = 0.0
			_vel.y = absf(_vel.y)
		elif _ball.y > field.size.y - BALL:
			_ball.y = field.size.y - BALL
			_vel.y = -absf(_vel.y)
		var pr := Rect2(4.0, _player_y, PADDLE_W, PADDLE_H)
		var cr := Rect2(field.size.x - 4.0 - PADDLE_W, _cpu_y, PADDLE_W, PADDLE_H)
		var br := Rect2(_ball, Vector2(BALL, BALL))
		if br.intersects(pr) and _vel.x < 0.0:
			_ball.x = pr.end.x
			_vel.x = absf(_vel.x) * 1.04
			_vel.y += ((_ball.y + BALL * 0.5) - (pr.position.y + PADDLE_H * 0.5)) * 3.2
		elif br.intersects(cr) and _vel.x > 0.0:
			_ball.x = cr.position.x - BALL
			_vel.x = -absf(_vel.x) * 1.04
			_vel.y += ((_ball.y + BALL * 0.5) - (cr.position.y + PADDLE_H * 0.5)) * 3.2
		_vel.y = clampf(_vel.y, -240.0, 240.0)
		_vel.x = clampf(_vel.x, -280.0, 280.0)
		if _ball.x < -BALL:
			_score_c += 1
			_serve(1.0)
		elif _ball.x > field.size.x:
			_score_p += 1
			_serve(-1.0)
		if _score_p >= 5 or _score_c >= 5:
			_alive = false
			_started = false
	queue_redraw()


func _serve(dir_x: float) -> void:
	var field := _field()
	_ball = Vector2(field.size.x * 0.5 - BALL * 0.5, field.size.y * 0.5)
	_vel = Vector2(BALL_SPEED * dir_x, randf_range(-110.0, 110.0))
	_started = true


func _field() -> Rect2:
	return Rect2(6.0, 22.0, maxf(8.0, size.x - 12.0), maxf(8.0, size.y - 44.0))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.07, 0.12, 1.0), true)
	var field := _field()
	draw_rect(field, Color(0.08, 0.12, 0.20, 1.0), true)
	draw_rect(field, Color(0.55, 0.78, 1.0, 0.7), false, 1.5)
	var mid_x := field.position.x + field.size.x * 0.5
	var y := field.position.y
	while y < field.end.y:
		draw_rect(Rect2(mid_x - 1.0, y, 2.0, 8.0), Color(0.45, 0.62, 0.85, 0.55), true)
		y += 14.0
	draw_rect(Rect2(field.position + Vector2(4.0, _player_y), Vector2(PADDLE_W, PADDLE_H)), Color(0.95, 0.92, 0.55, 1.0), true)
	draw_rect(Rect2(field.position + Vector2(field.size.x - 4.0 - PADDLE_W, _cpu_y), Vector2(PADDLE_W, PADDLE_H)), Color(0.75, 0.88, 1.0, 1.0), true)
	draw_rect(Rect2(field.position + _ball, Vector2(BALL, BALL)), Color(1.0, 1.0, 0.92, 1.0), true)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(8.0, 16.0), "GNOP  %d — %d" % [_score_p, _score_c], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.85, 0.92, 1.0))
	var foot := "UP / DOWN"
	if not _started and _alive:
		foot = "ARROWS TO START"
	elif not _alive:
		if _score_p > _score_c:
			foot = "YOU WIN — TAP / ARROW"
		else:
			foot = "CPU WINS — TAP / ARROW"
	draw_string(font, Vector2(8.0, size.y - 6.0), foot, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.72, 0.84, 1.0))
