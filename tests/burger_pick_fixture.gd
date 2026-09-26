extends "res://tests/delivery_network_fixture.gd"
var served := 0
func _on_serve() -> void:served+=1
func _queue_station_review_thumbnail(_index: int) -> void:pass
func _center_build_burger_on_board() -> void:pass
func _refresh_ticket_checkmarks() -> void:pass
