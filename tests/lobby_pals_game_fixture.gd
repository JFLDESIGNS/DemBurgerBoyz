extends "res://tests/burger_serve_fixture.gd"

# Exercise real challenge/end-day transitions without spawning the kitchen/NPCs.
func _spawn_challenge_customer() -> void: pass
func _flash(_text: String, _color: Color, _hold_sec: float = 1.1) -> void: pass
