extends "res://tests/delivery_network_fixture.gd"
func _clear_station(index:int,defer_visual:bool=false)->void:
 stations[index].items=[];stations[index].patties=[]
func _make_review_burger_snapshot(_index:int)->Texture2D:return null
func _station_stack_screen_center(_index:int)->Vector2:return Vector2(960,760)
func _station_has_melting_cheese(_index:int)->bool:return false
func _mp_broadcast_station(_index:int,_peer:int=0)->void:pass

func _crown_serve_burger(index:int)->bool:
 if stations[index].items.has("bun_top"):return false
 stations[index].items.append("bun_top");return true
