extends "res://tests/kitchen_network_fixture.gd"
var rebuilds := 0
var selections := 0
var parades := 0
func _refresh_station(_index: int) -> void:rebuilds+=1
func _select_ticket_local(customer: Node3D) -> void:selected_customer=customer;selections+=1
func _highlight_active_station() -> void:pass
func _start_burger_pals_parade(_reason: String) -> void:parades+=1
func _play_challenge_song() -> void:pass
func _stop_challenge_song() -> void:pass
func _sync_station_cheese_items(_index: int) -> void:pass

var phone_refreshes := 0
var stock_refreshes := 0
func _refresh_phone_ui() -> void:phone_refreshes+=1
func _refresh_ingredient_stock_bars(_only_id: String = "", _refresh_fridge: bool = true) -> void:stock_refreshes+=1
