extends "res://tests/main_ticket_harness.gd"
var added: Array[String] = []
var pickups := 0
func _add_ingredient(id: String) -> void: added.append(id)
func _try_start_strip_hold_pickup() -> void:
	pickups += 1
	_clear_strip_hold_tracking()
func _gui_to_camera_screen(point: Vector2) -> Vector2: return point
