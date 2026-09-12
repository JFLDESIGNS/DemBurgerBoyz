extends SceneTree
const Cinematic = preload("res://scripts/truck_cinematic.gd")

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok

func _run() -> void:
	var holder := Control.new()
	holder.size = Vector2(680, 320)
	holder.position.x = (root.get_visible_rect().size.x - 680.0) * 0.5
	root.add_child(holder)
	var menu := Cinematic.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(menu)
	await process_frame
	if not _check(is_equal_approx(menu.size.x, root.get_visible_rect().size.x) and is_zero_approx(menu.global_position.x), "Menu departure viewport does not reach the real screen edge"):
		return
	menu.set_process(false)
	if not _check(menu.truck != null and menu.wheels.size() == 4, "Missing truck or animated axles"):
		return
	if not _check(menu.truck.position.is_equal_approx(Vector3.ZERO), "Menu truck was left at animation approach position"):
		return
	if not _check(is_equal_approx(menu.truck.scale.z, 1.15), "Truck side-to-side width was lost"):
		return
	menu.set_process(true)
	await menu.play_departure()
	if not _check(menu.truck.position.x > 20, "Menu departure failed to leave frame"):
		return
	if not _check(menu.wheels[0].rotation.z < -20, "Departure wheel spin runs backwards"):
		return
	menu.hide()
	if not _check(menu.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED and not menu.is_processing(), "Hidden menu still renders/processes"):
		return
	var loader := Cinematic.new()
	loader.loading_mode = true
	loader.size = Vector2(1280, 720)
	var hidden_stage := Control.new()
	hidden_stage.hide()
	root.add_child(hidden_stage)
	hidden_stage.add_child(loader)
	await loader.prewarm_hidden_render()
	if not _check(loader.warmup_complete and loader.warmup_shots.size() == 5, "Warmup did not draw all five camera shots"):
		return
	if not _check(loader.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED and not loader.smoke[0].emitting, "Hidden warmup did not shut down its rendering and smoke"):
		return
	hidden_stage.show()
	loader.set_process(false)
	loader.sample_loading(0.05)
	var wheel_before := loader.wheels[2].quaternion
	var position_before := loader.truck.position
	loader.sample_loading(0.06)
	var axle_delta := wheel_before.inverse() * loader.wheels[2].quaternion
	if not _check(axle_delta.get_axis().z < 0 and loader.truck.position.x > position_before.x, "Blender wheel rotation is incorrect for +X travel"):
		return
	loader.sample_loading(1.8)
	var burger_before := loader.burger.transform
	loader.sample_loading(2.1)
	if not _check(not burger_before.is_equal_approx(loader.burger.transform), "Burger bounce/lean was lost during export"):
		return
	loader.sample_loading(2.8)
	loader.sample_loading(3.8)
	if not _check(loader.camera_cuts >= 4 and loader.smoke[0].emitting, "Loading camera cuts or tire smoke are not active"):
		return
	loader.sample_loading(5.9)
	if not _check(loader.truck.position.length() > 70, "Authored fast exit was lost"):
		return
	loader.hide()
	if not _check(loader.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED and not loader.smoke[0].emitting, "Hidden loader leaves its effects running"):
		return
	print("TRUCK_CINEMATIC_SMOKE_OK departure, width, wheel direction, burger animation, camera cuts, smoke, shutdown")
	menu.queue_free()
	hidden_stage.queue_free()
	await process_frame
	quit(0)
