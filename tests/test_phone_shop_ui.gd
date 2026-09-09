extends SceneTree


func _initialize() -> void:
	call_deferred("_run_test")


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _run_test() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		_fail("Could not load main scene")
		return
	var game := packed.instantiate()
	root.add_child(game)
	current_scene = game
	await create_timer(3.0).timeout
	game.call("_set_phone_app", "shop")
	await process_frame
	var shop := game.find_child("EquipmentShop", true, false) as Control
	if shop == null or not shop.is_visible_in_tree():
		_fail("Equipment marketplace is missing or hidden")
		return
	var ids := ["truck_buyout", "soda_machine", "icecream_machine", "fryer_machine", "grill_roomba", "fridge_upgrade", "gold_spatula"]
	var live_renders := 0
	var spin_target: Node3D = null
	for id in ids:
		var card := shop.find_child("ShopCard_%s" % id, true, false) as Control
		if card == null:
			_fail("Missing marketplace card for %s" % id)
			return
		var image := card.find_child("ShopProductPreview", true, false) as Control
		var name_label := card.find_child("ProductName", true, false) as Label
		var rating := card.find_child("ProductRating", true, false) as Label
		var description := card.find_child("ProductDescription", true, false) as Label
		var price := card.find_child("ProductPrice", true, false) as Label
		var buy := card.find_child("BuyButton", true, false) as Button
		if image == null or image.custom_minimum_size.y < 120.0:
			_fail("%s is missing its large product image" % id)
			return
		if (id == "soda_machine" or id == "icecream_machine") and image.custom_minimum_size.y < 180.0:
			_fail("%s did not receive the extra-large product viewer" % id)
			return
		if image.find_child("ProductBackdrop", true, false) == null:
			_fail("%s is missing the grey studio gradient" % id)
			return
		if name_label == null or rating == null or description == null or price == null or buy == null:
			_fail("%s is missing marketplace product details" % id)
			return
		if not rating.text.contains("★") or not rating.text.contains("("):
			_fail("%s is missing stars or review count" % id)
			return
		if description.text.length() < 35:
			_fail("%s description is too short" % id)
			return
		if card.find_child("ActualItemModel", true, false) != null:
			live_renders += 1
			var turntable := card.find_child("ProductTurntable", true, false) as Node3D
			if turntable == null:
				_fail("%s is missing its interactive 3D turntable" % id)
				return
			if spin_target == null:
				spin_target = turntable
		if id == "icecream_machine":
			var ice_camera := card.find_child("ProductCamera", true, false) as Camera3D
			if ice_camera == null or ice_camera.size > 1.75:
				_fail("Ice-cream product camera is still too zoomed out")
				return
		if id == "gold_spatula":
			var gold_model := card.find_child("ActualItemModel", true, false) as Node3D
			if gold_model == null:
				_fail("Gold spatula is not using the real 3D spatula model")
				return
		var panel_style := card.get_theme_stylebox("panel") as StyleBoxFlat
		if panel_style == null or panel_style.bg_color.get_luminance() > 0.25:
			_fail("%s product card is not using dark mode" % id)
			return
	if live_renders < 6:
		_fail("Expected six real in-game equipment renders; got %d" % live_renders)
		return
	var spin_before := spin_target.rotation.y if spin_target != null else 0.0
	await create_timer(0.35).timeout
	if spin_target == null or is_equal_approx(spin_before, spin_target.rotation.y):
		_fail("The 3D product viewer is not rotating")
		return
	print("PHONE SHOP test passed: closer ice cream, gold spatula, dark mode, and %d spinning 3D renders" % live_renders)
	game.queue_free()
	await process_frame
	quit(0)
