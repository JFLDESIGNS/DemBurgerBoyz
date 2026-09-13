extends "res://scripts/game.gd"
func _ready() -> void: pass
func _process(_delta: float) -> void: pass
func _physics_process(_delta: float) -> void: pass
var captured: Array[String] = []
func _add_ingredient(id: String) -> void: captured.append(id)
func _strip_swipe_add(id: String) -> void:
	if _strip_swipe_added.has(id): return
	_strip_swipe_added[id] = true
	captured.append(id)
func _pointer_button_pressed(_button: int) -> bool: return true
