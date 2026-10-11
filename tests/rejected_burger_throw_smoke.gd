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
	var script := load(get_script().resource_path.get_base_dir().path_join("rejected_burger_fixture.gd")) as GDScript
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
	var bin := Marker3D.new();game.world.add_child(bin);bin.position=Vector3(.9,.4,-1.0);game.physical_garbage_target=bin
	var committed := [false]
	var departed := [false]
	c.set_meta("burger_pending_departure",func():departed[0]=true)
	game._play_serve_fly_to_mouth(0,c,func():committed[0]=true,null,0,1)
	var began := Time.get_ticks_msec()
	var checked_hand := false
	var start_grip := Vector2.ZERO
	while game._serve_fly_busy and Time.get_ticks_msec()-began<14000:
		await process_frame
		if not game._serve_fly_busy:break
		var stack:Control=game._serve_fly_root_pool[0].get_node("ServeFlyStack")
		if c._burger_eat_phase=="complain" and Time.get_ticks_msec()-c._rejected_burger_since>200 and game.throw_samples.is_empty():
			var skel:Skeleton3D=c.find_child("Skeleton3D",true,false)
			var palm:=skel.to_global(skel.get_bone_global_pose(skel.find_bone("LeftHand")).origin)
			var grip:Vector3=c.burger_grip_global()
			expect(grip.distance_to(palm)<.1,"Rejected burger must stay at the holding hand, not the parked floor prop")
			expect(grip.y>.7,"Burger fell toward the bottom of the screen during complaint")
			start_grip=camera.unproject_position(grip)
			expect((stack.get_global_transform()*stack.pivot_offset).distance_to(start_grip)<8,"Sprite must follow the holding hand")
			checked_hand=true
		if not game.throw_samples.is_empty() and render_preview and not game.has_meta("throw_preview"):
			if float(game.throw_samples.back().progress)>.35:
				game.set_meta("throw_preview",true)
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://build/rejected_burger_release/throw_preview.png")
	expect(checked_hand,"Must exercise the real complaint animation")
	expect(committed[0] and departed[0] and not game._serve_fly_busy,"Scoring and departure must complete")
	expect(game.garbage_hits==1,"Garbage must react exactly once on arrival")
	expect(game.throw_samples.size()>2,"Must animate from hand to bin")
	if game.throw_samples.size()>2:
		var first:Dictionary=game.throw_samples.front()
		var last:Dictionary=game.throw_samples.back()
		expect(first.origin.distance_to(start_grip)<12,"Launch must start at the customer hand")
		expect(is_equal_approx(last.progress,1.0) and last.center.distance_to(last.target)<.1,"Throw must finish at the actual garbage opening")
	print("REJECTED_BURGER_THROW_OK" if failures.is_empty() else str(failures))
	game.free();quit(0 if failures.is_empty() else 1)
