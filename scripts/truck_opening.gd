extends Node
signal finished
const DURATION := 6.0
var game: Node
var age := 0.0
var shutter: Node3D
var blocker: Control
var lights: Array = []
var environment: Environment
var exposure := 1.0
var bunting_home := Vector3.ZERO
var sounded := false
var done := false
var camera_mask := 0

func setup(owner_game: Node) -> void:
	game = owner_game
	camera_mask = game.camera.cull_mask
	game.camera.cull_mask &= ~game.LOADING_WARMUP_LAYER
	blocker = Control.new()
	blocker.name = "TruckOpeningInputBlocker"
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	blocker.z_index = 1000
	game.get_node("UI/Root").add_child(blocker)
	for light in game.world.find_children("*","Light3D",true,false):
		lights.append([light,light.light_energy])
	var env = game.world.find_child("WorldEnvironment",true,false)
	if env is WorldEnvironment:
		environment = env.environment
		exposure = environment.tonemap_exposure
	if is_instance_valid(game.window_bunting_root): bunting_home = game.window_bunting_root.position
	shutter = Node3D.new()
	shutter.name = "OpeningRollerShutter"
	game.world.add_child(shutter)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("353b43"); material.metallic = .65; material.roughness = .55
	for i in 22:
		var slat := MeshInstance3D.new()
		var box := BoxMesh.new(); box.size = Vector3(6.8,.103,.045)
		slat.mesh = box; slat.material_override = material
		shutter.add_child(slat); slat.position = Vector3(0,-float(i)*.105,0)
	shutter.position = Vector3(0,2.92,1.60)
	sample(0.0)

func sample(seconds: float) -> void:
	var opening := smoothstep(.45,4.1,seconds)
	# Slats gather into the header as the bottom edge lifts.
	shutter.scale.y = maxf(.001,1.0-opening)
	shutter.visible = opening < 1.0
	var daylight := smoothstep(.65,4.6,seconds)
	for entry in lights:
		if is_instance_valid(entry[0]): entry[0].light_energy = entry[1]*lerpf(.08,1.0,daylight)
	if environment: environment.tonemap_exposure = exposure*lerpf(.22,1.0,daylight)
	if is_instance_valid(game.window_bunting_root):
		var drop := clampf((seconds-3.25)/1.15,0,1)
		var settle := 1.0 + 2.70158*pow(drop-1.0,3.0) + 1.70158*pow(drop-1.0,2.0)
		game.window_bunting_root.position = bunting_home + Vector3.UP*1.35*(1.0-settle)
	if is_instance_valid(game.open_closed_sign):
		game.open_closed_sign.rotation_degrees.y = lerpf(game.OPEN_CLOSED_SIGN_YAW_CLOSED,game.OPEN_CLOSED_SIGN_YAW_OPEN,smoothstep(4.2,5.3,seconds))

func _process(delta: float) -> void:
	if done or not is_instance_valid(game): return
	age = minf(DURATION,age+delta)
	sample(age)
	if age >= 4.25 and not sounded:
		sounded = true
		game._setup_burgerpals_startup_sound()
		game._play_burgerpals_startup_sound()
	if age >= DURATION:
		done = true
		finished.emit()

func _exit_tree() -> void:
	if is_instance_valid(game) and is_instance_valid(game.camera): game.camera.cull_mask = camera_mask
	for entry in lights:
		if is_instance_valid(entry[0]): entry[0].light_energy = entry[1]
	if environment: environment.tonemap_exposure = exposure
	if is_instance_valid(game) and is_instance_valid(game.window_bunting_root): game.window_bunting_root.position = bunting_home
	if is_instance_valid(shutter): shutter.queue_free()
	if is_instance_valid(blocker): blocker.queue_free()
