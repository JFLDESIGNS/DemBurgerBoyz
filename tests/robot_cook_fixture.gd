extends "res://tests/turbo_polish_fixture.gd"
var served_count := 0
var visual_count := 0
func _resolve_serve_customer(): return selected_customer
func _find_perfect_station_for(order: Array) -> int:
	return 0 if GameDataScript.compare_orders(stations[0].items, order).get("perfect", false) else -1
func _station_has_melting_cheese(_index: int) -> bool: return false
func _submit_serve_request(_customer: Node3D, _index: int) -> void:
	served_count += 1
	selected_customer.is_waiting = false
func _add_ingredient_to_station(index: int, id: String, _sfx: bool = true) -> void:
	if supply_stock.get(id, 0) <= 0: return
	supply_stock[id] -= 1
	stations[index].items.append(id)
func _supply_storage_location(_id: String, _kind: String) -> Vector3: return grill_roomba_root.position
func _roomba_body_hits_patty(_xz: Vector2, _extra: float = 0.0) -> bool: return false
func _roomba_patty_safe_heading(_p: Vector2, heading: float, _target: Vector2, _patty: Area3D = null, _drive: bool = false) -> float: return heading
func _update_roomba_spatula_hinge(_active: bool, _delta: float) -> void: pass
func mp_robot_cook_visual(_id: String, _index: int, _source: Vector3, _fork: Vector3) -> void: visual_count += 1

func _condiment_pour_target_world(_index: int, _id: String = "") -> Vector3: return Vector3(1, 1, 0)
