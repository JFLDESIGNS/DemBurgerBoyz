extends "res://tests/main_ticket_harness.gd"
func _refresh_station(_index: int) -> void: _refresh_ticket_checkmarks()
func _refresh_spatula_ui() -> void: pass
func _update_held_spatula_patty(_delta: float = .016) -> void: pass
func _update_hud() -> void: pass
func _refresh_ingredient_stock_bars(_id: String = "", _fridge: bool = true) -> void: pass
func _refresh_phone_ui() -> void: pass
func _refresh_freshness_label(_index: int) -> void: pass
func _refresh_ready_fries_visuals() -> void: pass
func _select_station(_index: int) -> void: pass
func _mp_broadcast_economy() -> void: pass
func _mp_broadcast_customers() -> void: pass
func _mp_broadcast_grill(_peer: int = 0) -> void: pass
func _mp_broadcast_station(index: int, _peer: int = 0) -> void:
	if mp_enabled and get_node("/root/NetManager").is_host():
		mp_sync_station.rpc(index, stations[index].items, [], false, 120.0, false, stations[index].get("bun_toast", {}))
func _try_auto_serve() -> void: pass
