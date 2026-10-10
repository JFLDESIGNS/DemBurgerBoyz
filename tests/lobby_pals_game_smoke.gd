extends SceneTree

var failures: Array[String] = []

func expect(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var script := load("res://tests/lobby_pals_game_fixture.gd") as GDScript
	if script == null or not script.can_instantiate():
		quit(1)
		return
	var game = script.new()
	var regex := RegEx.new()
	regex.compile("@onready var \\w+: (\\w+) = %(\\w+)")
	for result in regex.search_all(FileAccess.get_file_as_string("res://scripts/game.gd")):
		var node := ClassDB.instantiate(result.get_string(1)) as Node
		node.name = result.get_string(2)
		game.add_child(node)
		node.owner = game
		node.unique_name_in_owner = true
		if node is Control: node.visible = false
	root.add_child(game)
	var outdoor := Node3D.new()
	game.add_child(outdoor)
	game._build_burger_pals_parade(outdoor)
	var parade = game.burger_pals_parade
	game.playing = true
	game._challenge_phase = "offer"
	game._accept_challenge()
	expect(parade.active and parade.event_reason == "challenge", "Accepting challenge must launch trio")
	parade.set_process(false)
	parade.advance_parade(3.0)
	game._accept_challenge()
	expect(is_equal_approx(parade.elapsed, 3.0), "Repeated accept must not restart parade")
	game._end_day()
	expect(not game.playing, "End day must stop gameplay immediately")
	expect(parade._queued_reason == "end_of_day", "End-day event must queue behind challenge")
	expect(not game.game_over_panel.visible and game._parade_results_button.visible, "Results must leave street visible with skip button")
	parade.advance_parade(17.0)
	parade.set_process(false)
	expect(parade.event_reason == "end_of_day", "Queued end-day march must run")
	parade.advance_parade(20.0)
	expect(game.game_over_panel.visible and not game._parade_results_button.visible, "Results must appear automatically after end-day pass")
	game._start_burger_pals_parade("end_of_day")
	game._show_end_day_parade_before_results()
	game._parade_results_button.pressed.emit()
	expect(game.game_over_panel.visible, "Show results must work without waiting")
	game._stop_burger_pals_parade()
	expect(not parade.active and not parade.is_processing(), "Reset must stop animation")
	expect(not game._parade_results_button.visible, "Reset must dismiss end-day shortcut")
	game._challenge_phase = "offer"
	game.mp_challenge_state("active", 3, 3, 30.0, 30.0, 10)
	expect(parade.active, "Network active transition must launch parade")
	parade.set_process(false)
	parade.advance_parade(2.0)
	game.mp_challenge_state("active", 3, 2, 28.0, 30.0, 10)
	expect(is_equal_approx(parade.elapsed, 2.0), "Network progress must not restart parade")
	game._stop_burger_pals_parade()
	if "--render-preview" in OS.get_cmdline_user_args():
		var camera := game.camera as Camera3D
		camera.transform = Transform3D(Basis(Vector3(-1,0,0), Vector3(0,.985,.174), Vector3(0,.174,-.985)), Vector3(0,1.78,-1.65))
		camera.fov = 58.0
		camera.current = true
		var backdrop := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = game.STREET_MATTE_BASE_SIZE
		backdrop.mesh = quad
		backdrop.position = Vector3(0, game.STREET_MATTE_DEFAULT_Y, game.STREET_MATTE_BASE_Z)
		backdrop.rotation.y = PI
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_texture = load(game._current_street_background_path())
		backdrop.material_override = mat
		outdoor.add_child(backdrop)
		game.game_over_panel.hide()
		game._start_burger_pals_parade("preview")
		parade.set_process(false)
		parade.advance_parade(10.0)
		for i in 5: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://models/lobby_pals/godot_source/in_game_street_preview.png")
	game.free()
	if failures.is_empty(): print("LOBBY_PALS_GAME_EVENTS_OK")
	quit(0 if failures.is_empty() else 1)
