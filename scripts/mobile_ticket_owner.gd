extends "res://scripts/customer.gd"
# A ticket owner only: no body, AI, queue slot, or walk-up handoff.
func _ready() -> void:pass
func _process(delta:float) -> void:
 if _order_clock_on and not is_leaving:order_elapsed_sec+=delta
func _physics_process(_delta:float) -> void:pass
