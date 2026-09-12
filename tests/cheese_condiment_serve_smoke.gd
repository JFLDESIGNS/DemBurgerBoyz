extends SceneTree


func _init() -> void:
	var patty_source := FileAccess.get_file_as_string("res://scripts/patty.gd")
	var game_source := FileAccess.get_file_as_string("res://scripts/game.gd")
	assert(patty_source.contains("* 0.0368"), "Cheese preview seat must clear the patty top")
	assert(game_source.contains("root.set_meta(\"condiment_station\", station_index)"), "Sauce flight must remember its Build station")
	assert(game_source.contains("func _shoot_station_condiments_home(station_index: int)"), "Serve needs a condiment return-flight helper")
	assert(game_source.contains("_shoot_station_condiments_home(station_index)"), "Accepted burger serve must return its condiment bottles")
	print("CHEESE_CONDIMENT_SERVE_SMOKE_OK")
	quit()
