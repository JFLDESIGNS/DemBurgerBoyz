extends "mobile_packing_fixture.gd"
var test_row: Control
func _build_layer_at_screen(_pos: Vector2) -> Control:return test_row
func _restyle_station_layers(_index: int) -> void:pass
