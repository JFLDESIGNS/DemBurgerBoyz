extends Node
signal finished
const DURATION := 6.0
const SHUTTER_START := 0.25
const SHUTTER_END := 3.35
const GARAGE_FADE_SEC := 0.8
const BUNTING_START := 3.05
const SIGN_START := 4.45
const SIGN_END := 5.12
const JINGLE_START := 4.38
const GARAGE_SOUND = preload("res://sounds/garage_shutter_open.ogg")
var game: Node
var age := 0.0
var shutter: Node3D
var blocker: Control
var lights: Array = []
var environment: Environment
var exposure := 1.0
var bunting_home := Vector3.ZERO
var bunting_rotation := Vector3.ZERO
var flags: Array[Node3D] = []
var sounded := false
var garage_sounded := false
var garage_player: AudioStreamPlayer
var done := false
var camera_mask := 0
var sign_pivot_was_processing := false
var sign_home_rotation := Vector3.ZERO

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
	if is_instance_valid(game.window_bunting_root):
		bunting_home = game.window_bunting_root.position
		bunting_rotation = game.window_bunting_root.rotation
		for child in game.window_bunting_root.get_children():
			if child is Node3D and child.get_meta("is_bunting_flag",false): flags.append(child)
	if is_instance_valid(game.open_closed_sign):
		sign_home_rotation = game.open_closed_sign.rotation
		if is_instance_valid(game.open_closed_sign_tween): game.open_closed_sign_tween.kill()
		game.open_closed_sign_tween = null
		game.open_closed_sign_busy = true
	if is_instance_valid(game.open_closed_sign_pivot):
		sign_pivot_was_processing = game.open_closed_sign_pivot.is_processing()
		game.open_closed_sign_pivot.set_process(false)
	garage_player = AudioStreamPlayer.new()
	garage_player.name = "GarageShutterOpening"
	garage_player.stream = GARAGE_SOUND
	garage_player.bus = "SFX"
	garage_player.volume_db = -6.0
	add_child(garage_player)
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
	var opening := smoothstep(SHUTTER_START,SHUTTER_END,seconds)
	shutter.scale.y = maxf(.001,1.0-opening)
	shutter.visible = opening < 1.0
	var daylight := smoothstep(.4,3.6,seconds)
	for entry in lights:
		if is_instance_valid(entry[0]): entry[0].light_energy = entry[1]*lerpf(.08,1.0,daylight)
	if environment: environment.tonemap_exposure = exposure*lerpf(.22,1.0,daylight)
	if is_instance_valid(game.window_bunting_root):
		# A short gravity-led drop, a small rope rebound, and staggered pennant flutter.
		var t := clampf((seconds-BUNTING_START)/.75,0.0,1.0)
		var after := maxf(0.0,seconds-(BUNTING_START+.75))
		var settle := 1.0-smoothstep(4.30,4.45,seconds)
		var bounce := -.055*sin(after*15.0)*exp(-after*5.5)*settle
		game.window_bunting_root.position = bunting_home + Vector3.UP*(.85*(1.0-t*t)+bounce)
		game.window_bunting_root.rotation = bunting_rotation + Vector3(0,0,deg_to_rad(.6)*sin(after*11.0)*exp(-after*5.0)*settle)
		for i in flags.size():
			var flag := flags[i]
			var local_age := seconds-BUNTING_START-float(i)*.018
			var unfold := smoothstep(0.0,.65,local_age)
			var flutter := 13.0*sin(maxf(0.0,local_age-.55)*16.0)*exp(-maxf(0.0,local_age-.55)*4.5)*settle
			flag.rotation_degrees = Vector3(lerpf(-72.0,0.0,unfold)+flutter,0.0,0.0)
			flag.position = flag.get_meta("bunting_base_pos",flag.position)
	if is_instance_valid(game.open_closed_sign):
		var flip := smoothstep(SIGN_START,SIGN_END,seconds)
		var turn := wrapf(game.OPEN_CLOSED_SIGN_YAW_OPEN-game.OPEN_CLOSED_SIGN_YAW_CLOSED,-180.0,180.0)
		game.open_closed_sign.rotation_degrees.y = game.OPEN_CLOSED_SIGN_YAW_CLOSED+turn*flip
		if seconds>=SIGN_END: game.open_closed_sign.rotation_degrees.y=game.OPEN_CLOSED_SIGN_YAW_OPEN
		for face_name in ["OpenFace","ClosedFace"]:
			var face=game.open_closed_sign.get_node_or_null(face_name)
			if face is MeshInstance3D and face.material_override is ShaderMaterial:
				face.material_override.set_shader_parameter("blur_amount",sin(flip*PI)*.55)

func _process(delta: float) -> void:
	if done or not is_instance_valid(game): return
	age = minf(DURATION,age+delta)
	sample(age)
	if age >= SHUTTER_START and not garage_sounded:
		garage_sounded = true
		garage_player.play()
	if garage_sounded and is_instance_valid(garage_player):
		var sound_end := minf(SHUTTER_END, SHUTTER_START + GARAGE_SOUND.get_length())
		var fade := smoothstep(sound_end - GARAGE_FADE_SEC, sound_end, age)
		garage_player.volume_db = linear_to_db(maxf(0.0001, db_to_linear(-6.0) * (1.0 - fade)))
		if age >= sound_end: garage_player.stop()
	if age >= JINGLE_START and not sounded:
		sounded = true
		game._setup_burgerpals_startup_sound()
		game._play_burgerpals_startup_sound()
		game._truck_opening_announced = true
	if age >= DURATION:
		done = true
		finished.emit()

func _exit_tree() -> void:
	if is_instance_valid(game) and is_instance_valid(game.camera): game.camera.cull_mask = camera_mask
	for entry in lights:
		if is_instance_valid(entry[0]): entry[0].light_energy = entry[1]
	if environment: environment.tonemap_exposure = exposure
	if is_instance_valid(game):
		if is_instance_valid(game.window_bunting_root):
			game.window_bunting_root.position = bunting_home
			game.window_bunting_root.rotation = bunting_rotation
			for flag in flags:
				if is_instance_valid(flag): flag.rotation = Vector3.ZERO
		if is_instance_valid(game.open_closed_sign):
			game.open_closed_sign_busy = false
			game.open_closed_sign.rotation = sign_home_rotation
			if done: game.open_closed_sign.rotation_degrees.y=game.OPEN_CLOSED_SIGN_YAW_OPEN
		if is_instance_valid(game.open_closed_sign_pivot): game.open_closed_sign_pivot.set_process(sign_pivot_was_processing)
	if is_instance_valid(shutter): shutter.queue_free()
	if is_instance_valid(blocker): blocker.queue_free()
