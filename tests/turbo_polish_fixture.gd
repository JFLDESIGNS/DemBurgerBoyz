extends "res://tests/main_ticket_harness.gd"
var tossed := 0
func _animate_click_transfer(_patty: Area3D, to_build: bool, _pos: Vector3) -> void:
	assert(to_build)
	tossed += 1
