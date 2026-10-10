extends "res://tests/side_sync_fixture.gd"
func _try_auto_serve() -> void: pass
var pending_completion: Callable
func _play_fries_fly_to_mouth(customer: Node3D, done: Callable) -> void:
	_serve_fly_busy=true
	pending_completion=done
	customer.is_waiting=false
