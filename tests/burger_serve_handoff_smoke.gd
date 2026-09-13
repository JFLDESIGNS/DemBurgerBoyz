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
	game.call("_play_serve_fly_to_mouth",0,c,func() -> void:committed[0] = true,null,0)
	await process_frame
	expect(committed[0],"Scoring callback was delayed by presentation")
	var seen_grab := false
	var seen_eat := false
	var eat_cycles := 0
	var prior_eat_time := -1.0
	var max_error := 0.0
	var captured := {}
	var start_ms := Time.get_ticks_msec()
	while bool(game.get("_serve_fly_busy")) and Time.get_ticks_msec()-start_ms < 12000:
		await process_frame
		if not bool(game.get("_serve_fly_busy")):break
		var current := str(player.current_animation)
		var time := player.current_animation_position
		seen_grab = seen_grab or current == "burger/Take_Burger_Fast"
		seen_eat = seen_eat or current == "burger/Eat_Burger_Fast"
		if current == "burger/Eat_Burger_Fast":
			if prior_eat_time < 0.0 or time < prior_eat_time: eat_cycles += 1
			prior_eat_time = time
		expect(not departed[0],"Departure released before eating completed")
		var pool: Array = game.get("_serve_fly_root_pool")
		var stack := (pool[0] as Control).get_node("ServeFlyStack") as Control
		if (current == "burger/Take_Burger_Fast" and time>1.0) or current == "burger/Eat_Burger_Fast":
			var error := (stack.get_global_transform()*stack.pivot_offset).distance_to(camera.unproject_position(c.burger_grip_global()))
			max_error = maxf(max_error,error)
		var shot := ""
		if current == "burger/Take_Burger_Fast" and time>.95:shot = "grab"
		if current == "burger/Eat_Burger_Fast" and time>.25:shot = "lift"
		if current == "burger/Eat_Burger_Fast" and time>.65:shot = "bite"
		if render_preview and shot != "" and not captured.has(shot):
			captured[shot] = true
			var skel := c.find_child("Skeleton3D",true,false) as Skeleton3D
			var hands := (skel.get_bone_global_pose(skel.find_bone("LeftHand")).origin + skel.get_bone_global_pose(skel.find_bone("RightHand")).origin) * .5
			var world_hands := skel.to_global(hands)
			print("ALIGN ",shot," grip=",c.burger_grip_global()," wrists=",world_hands," screen=",camera.unproject_position(c.burger_grip_global())," hands_screen=",camera.unproject_position(world_hands)," pivot=",stack.pivot_offset," scale=",stack.scale," pos=",stack.global_position," canvas=",stack.get_global_transform_with_canvas())

			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://assets/character_animation/burger27/game_"+shot+".png")
	expect(eat_cycles == 3,"Customer must bring burger to mouth three times")
	expect(seen_grab and seen_eat,"Actual serving function did not play grab then eat")
	expect(departed[0],"Queued departure never released")
	expect(not bool(game.get("_serve_fly_busy")),"Serving did not finish within timeout")
	expect(max_error<4.0,"Burger detached from animated grip: " + str(max_error) + " px")
	print("BURGER_HANDOFF_MAX_ERROR_PX ",max_error)
	game.free()
	if failures.is_empty():print("BURGER_SERVE_HANDOFF_SMOKE_OK")
	quit(0 if failures.is_empty() else 1)
