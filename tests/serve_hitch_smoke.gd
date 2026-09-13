extends SceneTree

const CustomerScript := preload("res://scripts/customer.gd")
const FoodSpritesScript := preload("res://scripts/food_sprites.gd")


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _initialize() -> void:
	var tex := FoodSpritesScript.get_tex("bun_top")
	if tex == null:
		_fail("Could not load review-photo ingredient art")
		return
	var cache_before := FoodSpritesScript._composite_image_cache.size()
	var first_started := Time.get_ticks_usec()
	var first := FoodSpritesScript.prep_layer_image_for_composite(tex.get_image(), tex.get_instance_id(), "bun_top")
	var first_usec := Time.get_ticks_usec() - first_started
	var cache_after_first := FoodSpritesScript._composite_image_cache.size()
	var cached_started := Time.get_ticks_usec()
	var second := FoodSpritesScript.prep_layer_image_for_composite(tex.get_image(), tex.get_instance_id(), "bun_top")
	var cached_usec := Time.get_ticks_usec() - cached_started
	if first == null or second == null or first.get_size() != second.get_size():
		_fail("Cached review-photo image changed or disappeared")
		return
	if cache_after_first != cache_before + 1 or FoodSpritesScript._composite_image_cache.size() != cache_after_first:
		_fail("Review-photo source was rescanned instead of cached")
		return
	var variant_img: Image = tex.get_image().duplicate()
	var family_started := Time.get_ticks_usec()
	var family_variant := FoodSpritesScript.prep_layer_image_for_composite(variant_img, "bun_top_variant", "bun_top")
	var family_usec := Time.get_ticks_usec() - family_started
	if family_variant == null or family_variant.get_size() != first.get_size():
		_fail("Texture variant did not reuse its family's silhouette bounds")
		return

	var customer = CustomerScript.new()
	root.add_child(customer)
	customer.prewarm_review_card()
	var first_card: Texture2D = customer._make_review_card_texture()
	var second_customer = CustomerScript.new()
	root.add_child(second_customer)
	second_customer.prewarm_review_card()
	var second_card: Texture2D = second_customer._make_review_card_texture()
	if first_card == null or first_card != second_card:
		_fail("Customers are not sharing the prebuilt review-card texture")
		return
	if customer._review_card_root == null or customer._review_card_root.visible:
		_fail("Review-card nodes were not prepared invisibly before serve")
		return

	var game_source := FileAccess.get_file_as_string("res://scripts/game.gd").replace("\r\n", "\n")
	var clear_start := game_source.find("func _clear_station(index: int, defer_visual: bool = false)")
	var clear_end := game_source.find("\n\nfunc _clear_all_stations", clear_start)
	var clear_body := game_source.substr(clear_start, clear_end - clear_start)
	if clear_body.contains("_seed_cutting_board_buns(index)"):
		_fail("Station cleanup still performs a second full refresh while serving")
		return
	## Two textual refresh sites are the mutually-exclusive deferred/immediate branches.
	if clear_body.count("_refresh_station(index)") != 2 or clear_body.count("_mp_broadcast_station(index)") != 1:
		_fail("Station cleanup branches do not use one refresh and one broadcast per call")
		return
	if not clear_body.contains("call_deferred(\"_refresh_station_after_serve\", index)"):
		_fail("Serve station redraw is not deferred away from the completion frame")
		return
	if not game_source.contains("func _update_hud_money_climb(delta: float)") \
			or not game_source.contains("const HUD_MONEY_DRAW_HZ := 20.0"):
		_fail("Money counter is still rebuilding its label every render frame")
		return
	if not game_source.contains("customer.release_serve_completion()") \
			or not game_source.contains("for _i in 4:"):
		_fail("Customer, payment, and review work is not frame-staged")
		return
	print("SERVE_HITCH_SMOKE_OK first_crop=%.3fms cached_crop=%.3fms family_variant=%.3fms" % [float(first_usec) / 1000.0, float(cached_usec) / 1000.0, float(family_usec) / 1000.0])
	quit(0)
