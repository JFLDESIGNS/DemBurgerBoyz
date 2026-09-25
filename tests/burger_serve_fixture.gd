extends "res://scripts/game.gd"
## Real serving implementation, without starting the rest of the game.
func _ready() -> void:pass
func _process(_delta: float) -> void:pass
func _input(_event: InputEvent) -> void:pass
func _unhandled_input(_event: InputEvent) -> void:pass

var bite_bursts: int = 0
func _spawn_serve_crumb_burst(parent: Control, at: Vector2) -> void:
	bite_bursts += 1
	super._spawn_serve_crumb_burst(parent, at)
