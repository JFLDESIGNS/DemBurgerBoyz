extends "res://tests/social_shift_fixture.gd"
var spent := 0
var hits := 0
func _strip_ingredient_at(p: Vector2) -> String:
	return "tomato" if Rect2(300,300,100,100).has_point(p) else ""
func _spend_ingredient(_id: String) -> bool:
	spent += 1; return true
func _mp_can_spend_ingredient(_id: String) -> bool: return true
func _apply_customer_ingredient_hit(_cust: Node3D, _id: String, _hit: Vector3 = Vector3.ZERO, _zone: String = "body") -> void:
	hits += 1
