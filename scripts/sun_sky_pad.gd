## Interactive sun compass for L-mode lighting profiles.
## Right = camera-right (world −X). Up = service window (world +Z).
class_name SunSkyPad
extends Control

signal sky_changed(azim: float, elev: float)

const AZ_MIN := -15.0
const AZ_MAX := 110.0
const EL_MIN := 16.0
const EL_MAX := 58.0

var azim: float = 26.0
var elev: float = 36.0
var dragging: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(168, 168)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_MOVE
	tooltip_text = "Sun sky — drag to orbit. Right = camera-right, up = window."


func set_sky(a: float, e: float) -> void:
	azim = clampf(a, AZ_MIN, AZ_MAX)
	elev = clampf(e, EL_MIN, EL_MAX)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		dragging = mb.pressed
		if mb.pressed:
			_from_local(mb.position)
		accept_event()
	elif event is InputEventMouseMotion and dragging:
		_from_local((event as InputEventMouseMotion).position)
		accept_event()


func _from_local(p: Vector2) -> void:
	var c: Vector2 = size * 0.5
	var v: Vector2 = p - c
	var az: float = rad_to_deg(atan2(-v.y, v.x))
	var max_r: float = minf(size.x, size.y) * 0.42
	var t: float = clampf(v.length() / maxf(max_r, 0.001), 0.0, 1.0)
	var el: float = lerpf(90.0, 0.0, t)
	azim = clampf(az, AZ_MIN, AZ_MAX)
	elev = clampf(el, EL_MIN, EL_MAX)
	sky_changed.emit(azim, elev)
	queue_redraw()


func _azel_to_local() -> Vector2:
	var c: Vector2 = size * 0.5
	var max_r: float = minf(size.x, size.y) * 0.42
	var t: float = clampf(1.0 - (elev / 90.0), 0.0, 1.0)
	var r: float = t * max_r
	var rad: float = deg_to_rad(azim)
	return c + Vector2(cos(rad) * r, -sin(rad) * r)


func _draw() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	var c: Vector2 = size * 0.5
	var rad: float = minf(size.x, size.y) * 0.46
	var max_r: float = minf(size.x, size.y) * 0.42
	draw_circle(c, rad, Color(0.06, 0.10, 0.16, 1.0))
	draw_arc(c, rad, 0.0, TAU, 48, Color(0.55, 0.72, 0.92, 0.85), 2.0, true)
	var inner_t: float = clampf(1.0 - (EL_MAX / 90.0), 0.0, 1.0)
	var outer_t: float = clampf(1.0 - (EL_MIN / 90.0), 0.0, 1.0)
	draw_arc(c, inner_t * max_r, 0.0, TAU, 40, Color(1.0, 0.82, 0.35, 0.28), 1.0, true)
	draw_arc(c, outer_t * max_r, 0.0, TAU, 40, Color(0.70, 0.80, 0.92, 0.35), 1.0, true)
	## Compass: +X on the pad is camera-right, up is the service window.
	var font: Font = ThemeDB.fallback_font
	var fs: int = 11
	if font:
		draw_string(font, Vector2(size.x - 28.0, c.y + 4.0), "R", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.86, 0.45, 0.95))
		draw_string(font, Vector2(c.x - 14.0, 16.0), "WIN", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.82, 0.90, 1.0, 0.9))
	var handle: Vector2 = _azel_to_local()
	draw_line(c, handle, Color(1.0, 0.78, 0.35, 0.9), 2.0, true)
	draw_circle(handle, 9.0, Color(1.0, 0.84, 0.32, 1.0))
	draw_arc(handle, 9.0, 0.0, TAU, 24, Color(0.12, 0.08, 0.02, 0.9), 1.5, true)
	for i in 8:
		var a: float = float(i) * TAU / 8.0
		var d: Vector2 = Vector2(cos(a), sin(a))
		draw_line(handle + d * 12.0, handle + d * 17.0, Color(1.0, 0.90, 0.45, 0.8), 1.5, true)
