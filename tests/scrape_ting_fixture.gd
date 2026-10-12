extends "res://tests/main_ticket_harness.gd"
var dance_taps:=0
func _register_grill_dance_tap(_pos:Vector3,_roll:float)->void:dance_taps+=1
func _refresh_residue_visual(_slot:int)->void:pass
