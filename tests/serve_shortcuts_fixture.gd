extends "res://tests/main_ticket_harness.gd"
var ready_burger := true
var served := 0
var taps := 0
func _station_burger_complete(_index: int) -> bool: return ready_burger
func _station_has_build_burger(_index: int) -> bool: return false
func _cursor_on_cutting_board(_point: Vector2) -> bool: return true
func _on_serve() -> void: served += 1
func _board_tap_feedback() -> void: taps += 1
func _pulse_ingredient_feedback(_id: String) -> void: pass
