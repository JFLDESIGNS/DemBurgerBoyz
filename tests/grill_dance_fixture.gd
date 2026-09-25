extends "res://tests/main_ticket_harness.gd"
func _grill_zone_at(at: Vector3) -> Dictionary:
	return {"id": "hold" if at.x < 0.0 else "cook"}
