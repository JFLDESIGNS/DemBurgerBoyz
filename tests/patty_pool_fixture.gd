extends "res://tests/mp_smooth_fixture.gd"
var challenge_serves:=0
func _highlight_tickets()->void:pass
func _begin_serve_at(_customer:Node3D,_station:int,_force:bool,_peer:int=0,_cup:bool=false)->void:
 challenge_serves+=1
