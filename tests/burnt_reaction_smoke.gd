extends SceneTree
const Customer = preload("res://scripts/customer.gd")
var failures: Array[String] = []
var render_preview := false

func expect(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:call_deferred("run")

func run() -> void:
	render_preview = "--render-preview" in OS.get_cmdline_user_args()
	var gameplay := load("res://scripts/game.gd") as GDScript
	if gameplay == null or not gameplay.can_instantiate():
		push_error("Gameplay cannot compile")
		quit(1)
		return
	var script := load(get_script().resource_path.get_base_dir().path_join("burger_serve_fixture.gd")) as GDScript
	var game := script.new() as Node3D
	# Supply the real script's unique-node references without loading the kitchen.
	var regex := RegEx.new()
	regex.compile("@onready var \\w+: (\\w+) = %(\\w+)")
	for result in regex.search_all(FileAccess.get_file_as_string(get_script().resource_path.get_base_dir().get_base_dir().path_join("scripts/game.gd"))):
		var node := ClassDB.instantiate(result.get_string(1)) as Node
		node.name = result.get_string(2)
		game.add_child(node)
		node.owner = game
		node.unique_name_in_owner = true
		if node is Control:(node as Control).visible = false
	var ui := CanvasLayer.new()
	ui.name = "UI"
	game.add_child(ui)
	var controls := Control.new()
	controls.name = "Root"
	ui.add_child(controls)
	controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var station := Control.new()
	station.position = Vector2(120,500)
	station.size = Vector2(180,100)
	controls.add_child(station)
	game.set("stations",[{"items":["bun_bottom","patty","lettuce","tomato","bun_top"],"preview":station,"plate":station}])
	root.add_child(game)
	var camera: Camera3D = game.get("camera")
	camera.position = Vector3(2.2,2.5,-6)
	camera.look_at(Vector3(0,1.1,0))
	camera.current = true
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("24323d")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = .7
	game.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35,-30,0)
	light.light_energy = 1.2
	game.add_child(light)
	var c := Customer.new()
	c.setup(["bun_bottom","patty","bun_top"],Color.WHITE,45.0,0,0,0,-1,{} if "--plain" in OS.get_cmdline_user_args() else {"format_version":8,"name":"Serve Preview","body_type":"kenney_chunky_toon","skin_color":"cf895fff","top_style":2},true)
	game.add_child(c)
	c.set_process(false)
	c.is_waiting = true
	c.position = Vector3.ZERO
	c.rotation_degrees.y = 180.0
	var player: AnimationPlayer = c.get("_anim_player")
	var committed := [false]
	var departed := [false]
	c.set_meta("burger_pending_departure",func() -> void:departed[0] = true)
	game.call("_play_serve_fly_to_mouth",0,c,func() -> void:committed[0] = true,null,0,1)
	await process_frame
	expect(committed[0],"Scoring callback was delayed by presentation")
	var seen_point := false
	var seen_mad := false
	var start_ms := Time.get_ticks_msec()
	while bool(game.get("_serve_fly_busy")) and Time.get_ticks_msec()-start_ms < 14000:
		await process_frame
		if not bool(game.get("_serve_fly_busy")):break
		seen_point = seen_point or str(player.current_animation) == "burger/Point_Finger_Yell"
		seen_mad = seen_mad or c.get("_mood") == "mad"
		expect(not departed[0], "Departure interrupted rejection")
	expect(seen_point and seen_mad, "Missing angry reaction or finger pointing")
	expect(int(game.get("bite_bursts")) == 1, "Rejected burger must have exactly one bite")
	expect(departed[0], "Rejection never released departure")
	expect(not bool(game.get("_serve_fly_busy")), "Rejection timed out")
	var reused_root: Control = game.get("_serve_fly_root_pool")[0]
	game.call("_build_serve_fly_stack", reused_root, 0)
	expect(reused_root.get_node("ServeFlyStack").visible, "Next burger must become visible when the sprite is reused")

	game.free()
	if failures.is_empty():print("BURNT_REACTION_SMOKE_OK")
	quit(0 if failures.is_empty() else 1)
