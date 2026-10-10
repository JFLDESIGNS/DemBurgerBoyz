extends "res://tests/main_ticket_harness.gd"
var placed_at := Vector2.ZERO
var throws := 0
func _try_feed_held_patty_to_cat(_point: Vector2) -> bool: return false
func _is_over_garbage(_point: Vector2) -> bool: return false
func _try_place_spatula_on_grill(point: Vector2) -> bool:
	placed_at = point
	return true
func _throw_held_patty_to_build() -> void: throws += 1
func _throw_held_patty_to_grill() -> void: throws += 1
