extends "res://scripts/window_cat.gd"
func _ready():
 _visual=Node3D.new();add_child(_visual);enabled=true;mp_puppet=true;set_process(false)
func _update_character(_delta:float)->void:pass
func _update_begging_meows(_delta:float)->void:pass
func _apply_visual_scale()->void:pass
