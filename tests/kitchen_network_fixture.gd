extends "res://tests/grubbah_fixture.gd"
var bun_flights = 0
func _select_station(_index: int) -> void: pass
func _refresh_station(_index: int) -> void: pass
func _animate_bun_to_build_station(_id: String, _index: int = 0) -> void: bun_flights += 1
func _mp_broadcast_station(index: int, _peer: int = 0) -> void:
 if mp_enabled and get_node("/root/NetManager").is_host(): mp_sync_station.rpc(index,stations[index].items,[],false,120.0,false)
func _refresh_freshness_label(_index: int) -> void: pass
