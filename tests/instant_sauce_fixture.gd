extends "res://tests/main_ticket_harness.gd"
var pours: Array[Dictionary] = []
var animate_pours := false
func _select_station(_index: int) -> void: pass
func _refresh_station(_index: int) -> void: _refresh_ticket_checkmarks()
func _start_station_freshness(_index: int) -> void: pass
func _note_melody_press(_id: String) -> void: pass
func _mp_broadcast_station(_index: int, _peer: int = 0) -> void: pass
func _refresh_supply_ui_fast(_id: String) -> void: pass
func _try_auto_serve() -> void: pass
func _start_condiment_pour(entry: Dictionary) -> void:
	if animate_pours:
		super._start_condiment_pour(entry)
		return
	pours.append(entry)
	_condiment_auto_active[entry.id] = true
