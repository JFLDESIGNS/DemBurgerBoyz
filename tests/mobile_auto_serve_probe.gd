extends "res://scripts/grubbah.gd"
var authoritative = true
func host() -> bool: return authoritative
func publish() -> void: pass
func update_visuals(_delta: float) -> void: pass
