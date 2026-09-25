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
	c.is_challenge_guest = true
	game.set("_challenge_customer",c)
	game.set("_challenge_phase","active")
	game.set("_challenge_remaining",3)
	for index in 3:
		var committed := [0]
		var began := Time.get_ticks_msec()
		c.set_meta("serve_in_progress",true)
		game.call("_play_serve_fly_to_mouth",0,c,func() -> void:committed[0] += 1,null,0)
		while bool(game.get("_serve_fly_busy")) and Time.get_ticks_msec()-began < 3000:
			await process_frame
		expect(committed[0] == 1,"Challenge burger must score exactly once")
		expect(Time.get_ticks_msec()-began < 900,"Challenge handoff took too long")
		expect(not bool(c.get_meta("burger_in_flight",false)),"Challenge flight lock was not released")
		expect(not bool(c.get_meta("serve_in_progress",false)),"Challenge serving lock was not released")
		print("CHALLENGE_HANDOFF_MS ",Time.get_ticks_msec()-began)
	game.set("playing",true)
	game.set("_boss_intro_running",true)
	expect(game.call("_morning_boss_blocks_controls"),"Boss entrance must lock controls")
	game.set("_boss_intro_running",false)
	game.set("_cut_collector_kind","pep")
	game.set("_cut_collector",c)
	expect(game.call("_morning_boss_blocks_controls"),"Boss speech must lock controls")
	c.is_leaving = true
	expect(not game.call("_morning_boss_blocks_controls"),"Controls must unlock as boss leaves")
	var stats: Dictionary = game.call("_location_stats")
	expect(is_equal_approx(float(game.call("_first_customer_delay")),float(stats.get("first_delay",18.0))+10.0),"First customer delay missing ten seconds")
	var swirl := Node3D.new()
	game.add_child(swirl)
	game.call("_update_icecream_sparkles_for",swirl,1.0,0.0)
	expect(swirl.get_node("IceCreamSnowSparkles").get_child_count() == 84,"Ice cream sparkle count")
	game.free()
	if failures.is_empty():print("CHALLENGE_FAST_MORNING_SPARKLE_OK")
	quit(0 if failures.is_empty() else 1)
