extends "res://tests/grubbah_fixture.gd"
var ready_drink: Node3D
var drinks_consumed = 0
func _find_ready_drink_for_soda(_soda: String) -> Node3D: return ready_drink
func _consume_cup_for_serve(_customer: Node3D = null) -> void:
	drinks_consumed += 1; ready_drink = null
