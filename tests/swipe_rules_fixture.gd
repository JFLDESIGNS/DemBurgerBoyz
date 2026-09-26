extends "res://tests/burger_pick_fixture.gd"
var removed := ""
var returned := -1
var room := true
func _find_closest_patty_place(_at: Vector3) -> Vector3:return Vector3(0,1,1) if room else Vector3.ZERO
func _return_station_patty_to_grill(_si:int, layer:int, _at:Vector3)->bool:
 returned=layer
 return true
func _drop_patty_on_garbage(data:Variant)->void:removed=str(data.get("id",""))
