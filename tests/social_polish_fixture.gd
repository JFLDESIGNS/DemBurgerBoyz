extends "res://scripts/game.gd"
var foreground: Area3D
var flips := 0
var smashes := 0
func _ready() -> void: pass
func _process(_delta: float) -> void: pass
func _physics_process(_delta: float) -> void: pass
func _raycast_patty_at_screen(_screen: Vector2) -> Area3D: return foreground
func _is_over_garbage(_screen: Vector2) -> bool: return false
func _smash_grill_patty(_patty: Area3D) -> void: smashes += 1
func _on_patty_clicked(patty: Area3D) -> void:
 if patty.can_flip():
  patty.flipped_once = true
  flips += 1
