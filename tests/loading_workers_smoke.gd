extends SceneTree

const Food = preload("res://scripts/food_sprites.gd")
const Audio = preload("res://scripts/game_audio.gd")
const Patty = preload("res://scripts/patty.gd")

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok

func _run() -> void:
	var img := Image.create(32, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	img.fill_rect(Rect2i(7, 5, 16, 12), Color("cd8a38"))
	var tex := ImageTexture.create_from_image(img)
	var expected := Food.prep_layer_image_for_composite(img, tex.get_instance_id(), "worker_fixture")
	Food._composite_image_cache.erase(tex.get_instance_id())
	Food._composite_crop_rect_cache.erase("worker_fixture")
	await Food.prewarm_composite_async(self, tex, "worker_fixture")
	var actual := Food.prep_layer_image_for_composite(img, tex.get_instance_id(), "worker_fixture")
	if not _check(actual.get_size() == expected.get_size() and actual.get_data() == expected.get_data(), "Worker changed cropped food pixels"):
		return
	var color := Color("80522d")
	Food._patty_sheet_img = img
	Food._burger_cheese_sheet_img = img
	for cheese in [false, true]:
		var key := ("burger_cheese_%s_c0.00" if cheese else "patty_art_%s_c0.00") % color.to_html(false)
		var original: Texture2D = Food.burger_cheese_tex(color) if cheese else Food.patty_tex(color)
		Food._cache.erase(key)
		await Food.prewarm_tinted_sheet_async(self, cheese, color)
		var threaded: Texture2D = Food._cache[key]
		if not _check(original.get_image().get_data() == threaded.get_image().get_data(), "Worker changed food tint pixels"):
			return
	var prepared: Dictionary = await Patty.prepare_pool_images_async(self)
	var expected_sear: Image = prepared["sear"]
	var patty := Patty.new()
	patty.prepared_pool_images = prepared
	root.add_child(patty)
	patty.prewarm_frozen_visuals()
	if not _check(patty._sear_mat.albedo_texture.get_image().get_data() == expected_sear.get_data() and patty._frozen_ball != null, "Patty did not consume its prepared images and build frozen visuals"):
		return
	patty.queue_free()
	await process_frame
	var fridge_frost: Texture2D = await Patty.prepare_frost_texture_async(self)
	var fridge_ball := Patty.make_standalone_frozen_ball(fridge_frost)
	if not _check(fridge_ball.get_child_count() > 0, "Prepared fridge ball was empty"):
		return
	fridge_ball.free()
	var audio := Audio.new()
	root.add_child(audio)
	var maker: Callable = audio._make_soft_note.bind(72, 0.05)
	var expected_wav: AudioStreamWAV = maker.call()
	await audio._prewarm_cache_entry_async("worker_fixture", maker)
	var actual_wav: AudioStreamWAV = audio._cache["worker_fixture"]
	if not _check(actual_wav.data == expected_wav.data and audio._synthesis_tasks.is_empty(), "Worker changed PCM or left a task running"):
		return
	audio.queue_free()
	await process_frame
	print("LOADING_WORKERS_SMOKE_OK cropped pixels, tint pixels, PCM, prepared patty, task cleanup")
	quit(0)
