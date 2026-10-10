extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var wardrobe = load("res://scripts/fitted_wardrobe.gd")
	var colors := {}
	for filename in DirAccess.get_files_at("res://defaults/characters"):
		if not filename.ends_with(".json"): continue
		var preset: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://defaults/characters/" + filename))
		var top = preset.get("top_color", "ffffffff")
		var bottom = preset.get("bottom_color", "ffffffff")
		wardrobe.migrate_preset(preset)
		assert(preset.top_color == top and preset.bottom_color == bottom)
		colors[top] = true
	assert(colors.size() > 3, "Saved customer clothing retains distinct palettes")
	var social = load("res://scripts/customer_social.gd").new()
	var mobile = load("res://scripts/mobile_ticket_owner.gd").new()
	mobile.is_waiting = true; mobile.set_meta("mobile_order", true)
	assert(not social.eligible(mobile))
	var courier = load("res://scripts/mobile_ticket_owner.gd").new()
	courier.is_waiting = true; courier.set_meta("delivery_driver", true)
	assert(not social.eligible(courier))
	social.pair_customers(mobile, courier)
	assert(not mobile.has_meta("couple_partner") and not courier.has_meta("couple_partner"))
	mobile.free(); courier.free(); social.free()
	print("CUSTOMER_PALETTE_MOBILE_OK"); quit()
