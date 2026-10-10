extends SceneTree

var failures: Array[String] = []

func expect(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene := load("res://assets/lobby_pals/street_parade.tscn") as PackedScene
	if scene == null:
		quit(1)
		return
	var parade = scene.instantiate()
	root.add_child(parade)
	expect(parade._players.size() == 3, "All three MarchLoops must import")
	expect(not parade.visible and not parade.is_processing(), "Idle parade must be hidden and asleep")
	var mesh_count := 0
	for mesh in parade.find_children("*", "MeshInstance3D", true, false):
		mesh_count += 1
		expect(mesh.mesh.get_blend_shape_count() == 48, "Each surface must retain 48 poses")
		if "gloves" in mesh.name:
			expect(mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() == 48, "All eight glove cards must survive import")
	expect(mesh_count == 9, "Trio should use nine merged mesh surfaces")
	expect(parade.start_parade("challenge"), "Challenge must start march")
	parade.set_process(false)
	expect(is_equal_approx(parade.position.x, parade.start_x), "Start off screen right")
	parade.advance_parade(0.5)
	var body := parade.get_node("Actors/Burger").find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	expect(body.get_blend_shape_value(6) > 0.99, "Manual animation seek must change the actual mesh")
	expect(body.get_blend_shape_value(0) < 0.01, "Previous pose must release")
	expect(not parade.start_parade("challenge"), "Repeated challenge must not restart pass")
	expect(is_equal_approx(parade.elapsed, 0.5), "Repeated event must preserve progress")
	parade.start_parade("end_of_day")
	parade.advance_parade(19.5)
	expect(parade.active and parade.event_reason == "end_of_day", "End of day must queue behind active challenge")
	parade.set_process(false)
	parade.advance_parade(20.0)
	expect(not parade.active and not parade.visible and not parade.is_processing(), "Completion must hide and sleep")
	expect(is_equal_approx(parade.position.x, parade.finish_x), "Complete off screen left")
	parade.start_parade("challenge")
	parade.start_parade("end_of_day")
	parade.stop_parade()
	expect(parade._queued_reason.is_empty(), "Reset must discard queued event")
	if "--render-preview" in OS.get_cmdline_user_args():
		var camera := Camera3D.new()
		root.add_child(camera)
		camera.position = Vector3(0, 2.8, -9)
		camera.look_at(Vector3(0, 0.82, 0))
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 3.2625
		camera.current = true
		parade.start_parade("preview")
		parade.set_process(false)
		parade.advance_parade(10.0)
		parade._last_pose = -1
		parade.elapsed = 0.5
		parade._update_pose()
		for moment in [0.5, 1.0, 2.25]:
			parade.elapsed = moment
			parade._last_pose = -1
			parade._update_pose()
			for i in 3: await process_frame
			await RenderingServer.frame_post_draw
			var path := "res://godot_parade_%s.png" % str(moment).replace(".", "_")
			root.get_texture().get_image().save_png(path)
			print("GODOT_PREVIEW ", ProjectSettings.globalize_path(path))
	parade.free()
	if failures.is_empty(): print("LOBBY_PALS_ASSET_OK")
	quit(0 if failures.is_empty() else 1)
