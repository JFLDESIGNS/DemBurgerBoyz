extends SceneTree

const GameDataScript := preload("res://scripts/game_data.gd")


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _initialize() -> void:
	if GameDataScript.order_value(["bun_bottom", "patty", "bun_top"]) != 6:
		_fail("Plain single burger is not $6")
		return
	if GameDataScript.order_value(["bun_bottom", "patty", "cheese", "bun_top"]) != 7:
		_fail("Single burger does not charge exactly $1 per added ingredient")
		return
	if GameDataScript.order_value(["bun_bottom", "patty", "patty", "bun_top"]) != 10:
		_fail("Plain double burger is not $10")
		return
	if GameDataScript.order_value(["bun_bottom", "patty", "patty", "bacon", "onion", "bun_top"]) != 12:
		_fail("Double burger does not charge exactly $1 per added ingredient")
		return
	if GameDataScript.order_value(["fries"]) != 4:
		_fail("Fries are not $4")
		return
	if GameDataScript.order_value(["soda_cola"]) != 3:
		_fail("Drink is not $3")
		return
	if GameDataScript.order_value(["icecream"]) != 5:
		_fail("Ice cream is not $5")
		return
	var combo := ["bun_bottom", "patty", "pickle", "bun_top", "soda_cola", "fries", "icecream"]
	if GameDataScript.order_value(combo) != 19:
		_fail("Combined ticket prices are not additive")
		return
	if not is_equal_approx(GameDataScript.TIP_MIN_PERCENT, 0.10) \
			or not is_equal_approx(GameDataScript.TIP_MAX_PERCENT, 0.20):
		_fail("Tip range is not 10-20 percent")
		return
	var customer_source := FileAccess.get_file_as_string("res://scripts/customer.gd")
	if not customer_source.contains("if rated_stars > 4.0 and seasoned:"):
		_fail("Tip threshold is not strictly above four stars")
		return
	if customer_source.contains("TIP_OUTLIER_CHANCE"):
		_fail("Legacy random outlier tips are still active")
		return
	print("ECONOMY_PRICING_SMOKE_OK")
	quit(0)