extends "res://scripts/game.gd"
var commits := 0
var scored_wait := -1.0
func _ready() -> void: pass
func _process(_delta: float) -> void: pass
func _physics_process(_delta: float) -> void: pass
func _complete_serve(station_index: int, customer: Node3D = null, _drink: Node3D = null) -> void:
	commits += 1
	scored_wait = customer.order_elapsed_sec
	# Simulate immediate station cleanup; pooled presentation must survive it.
	stations[station_index]["items"] = []
