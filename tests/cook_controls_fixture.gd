extends "main_ticket_harness.gd"
func _refresh_spatula_ui() -> void: pass
func _refresh_station(_i: int) -> void: pass
func _select_station(_i: int) -> void: pass
func _refresh_ready_fries_visuals() -> void: pass
func _refresh_ticket_checkmarks() -> void: pass
func _update_hud() -> void: pass
func _note_machine_used(_id: String) -> void: pass
func _try_auto_serve() -> void: pass
func _seat_bun_piles_by_fryer() -> void: pass
func _machine_is_broken(_id: String) -> bool: return false
func _start_station_freshness(_index: int) -> void: pass
func _ensure_fryer_basket_smoke(_basket: Node3D) -> Node3D: return null

func _leave_grill_residue(_slot: int, _patty: Area3D, _announce: bool = true) -> void: pass
