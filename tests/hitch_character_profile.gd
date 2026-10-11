extends "res://scripts/customer.gd"
func _try_attach_saved_character() -> bool:
	var began=Time.get_ticks_usec()
	var result=super._try_attach_saved_character()
	print("PROFILE saved_character_ms=",(Time.get_ticks_usec()-began)/1000.0)
	return result
func _setup_character_animations(model: Node) -> void:
	var began=Time.get_ticks_usec()
	super._setup_character_animations(model)
	print("PROFILE animations_ms=",(Time.get_ticks_usec()-began)/1000.0)
