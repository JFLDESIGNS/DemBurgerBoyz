extends SceneTree

func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _run() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/game.gd") if FileAccess.file_exists("res://scripts/game.gd") else ""
	if not source.is_empty() and not source.contains("const GAMEPLAY_LOAD_MIN_SEC := 30.0"):
		_fail("Gameplay loader does not enforce the requested 30 second minimum")
		return
	if not source.is_empty() and not source.contains("await _start_game()"):
		_fail("Multiplayer session start does not wait for local prewarming")
		return
	if source.contains("call_deferred(\"_warm_burger_assets\")"):
		_fail("Heavy gameplay warmup still runs over the title menu")
		return
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		_fail("Main scene did not load")
		return
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1280, 900)
		for i in 5:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/main_menu_truck.png")
	var overlay := game.get_node_or_null("UI/Root/GameplayLoadingScreen") as Control
	if overlay == null:
		_fail("Car loading overlay was not created")
		return
	if overlay.visible:
		_fail("Loading overlay should remain hidden on the menu")
		return
	var car := overlay.get_node_or_null("TruckCinematic") as Control
	if car == null or car.get("truck") == null:
		_fail("Live 3D loading truck is missing")
		return
	# Join the same complete renderer warmup used by an immediate Start click.
	await car.call("prewarm_hidden_render")
	if car.get("viewport").render_target_update_mode != SubViewport.UPDATE_DISABLED:
		_fail("Hidden loading viewport is rendering on the title menu")
		return
	var paths: Array = game.call("_gameplay_preload_paths")
	if paths.size() < 45:
		_fail("Gameplay preload manifest is not comprehensive")
		return
	for required in [
		"res://assets/characters/Model/characterMedium.fbx",
		"res://assets/bg/street_window.png",
		"res://models/burgerpack/try2/SM_GrillSpatula.glb",
		"res://sounds/vehicles/car_pass_by_left_to_right.ogg"
	]:
		if not paths.has(required):
			_fail("Missing required warmup resource: %s" % required)
			return
	var audio = game.get("game_audio")
	if audio == null or not audio.has_method("prewarm_all_gameplay_audio"):
		_fail("Comprehensive gameplay audio warmup is not wired")
		return
	var original_camera_mask: int = game.get("camera").cull_mask
	var original_render_scale := root.scaling_3d_scale
	var began_ms := Time.get_ticks_msec()
	await game.call("_start_game")
	var elapsed := float(Time.get_ticks_msec() - began_ms) / 1000.0
	if elapsed < 29.5:
		_fail("Gameplay loading gate ended before 30 seconds")
		return
	if not bool(game.get("_gameplay_load_complete")) or overlay.visible:
		_fail("Gameplay loading gate did not finish and hide cleanly")
		return
	if car.get("camera_cuts") < 4 or car.is_processing():
		_fail("Loading cinematic failed to cut cameras or shut down")
		return
	if not bool(game.get("playing")) or game.get("start_overlay").visible:
		_fail("Cinematic did not hand off to the playable shift")
		return
	if root.disable_3d or not is_equal_approx(root.scaling_3d_scale, original_render_scale) or game.get("camera").cull_mask != original_camera_mask:
		_fail("Loading warmup did not restore gameplay rendering settings")
		return
	var patty_pool: Array = game.get("_patty_spawn_pool")
	if patty_pool.size() < 40:
		_fail("Gameplay loading did not prewarm the full 40-patty pool")
		return
	print("STARTUP_LOADING_SMOKE_OK paths=", paths.size(), " elapsed=", elapsed)
	game.queue_free()
	await process_frame
	quit(0)
