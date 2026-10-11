extends "res://tests/potato_network_fixture.gd"
var acks: Array = []
var released := false
func _mp_ack_food(peer: int, kind: String, accepted: bool) -> void: acks.append([peer,kind,accepted])
func _guest_action_feedback(_peer: int, message: String) -> void: feedback.append(message)
func _begin_fries_pack_hold(_slot_idx: int = -1) -> bool: fries_pack_held=true;return true
func _release_fries_pack(_screen_pos: Vector2) -> void: fries_pack_held=false;released=true
func _refresh_ready_fries_visuals() -> void: pass
