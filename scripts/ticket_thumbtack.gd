## Queued paper stays 2D; its actual GLB tack renders once after a quick placement.
extends Control
const MODEL = preload("res://models/thumbtack/thumbtack_red.glb")
const WHOOSH = preload("res://sounds/ticket/pin_whoosh.wav")
const TAP = preload("res://sounds/ticket/pin_tap.wav")
const DURATION := 0.26
const ROTATION := Vector3(0.872665,-0.314159,-0.488692)
var view: SubViewport
var pin: Node3D
var display: TextureRect
var sound: AudioStreamPlayer
var note: Control
var age := 0.0
var impact := false
var animating := false
var frozen := false

func setup(paper: Control) -> void:
	note = paper
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(70,70)
	view = SubViewport.new()
	view.size = Vector2i(140,140)
	view.transparent_bg = true
	view.own_world_3d = true
	view.world_2d = World2D.new()
	add_child(view)
	pin = MODEL.instantiate()
	pin.scale = Vector3.ONE*3.6
	pin.rotation = ROTATION
	view.add_child(pin)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 0.07
	camera.position = Vector3(0,0,1)
	camera.current = true
	view.add_child(camera)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42,-35,0)
	light.light_energy = 0.85
	view.add_child(light)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(1.0,0.95,0.87)
	world.environment.ambient_light_energy = 0.32
	view.add_child(world)
	display = TextureRect.new()
	display.texture = view.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(display)
	sound = AudioStreamPlayer.new()
	sound.volume_db = -6
	add_child(sound)
	hide()
	set_process(false)

func set_queued(queued: bool) -> void:
	if not queued:
		hide()
		animating = false
		sound.stop()
		view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		set_process(false)
		return
	var first := not visible
	show()
	sync_layout()
	if first:
		age = 0.0
		impact = false
		animating = true
		frozen = false
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		sound.stream = WHOOSH
		sound.play()
		set_process(true)

func sync_layout() -> void:
	if not is_instance_valid(note): return
	scale = note.scale
	rotation = note.rotation
	pivot_offset = Vector2(35,35)
	# Paper can slide upward without moving its pinned location on the rail.
	position = note.get_transform()*Vector2(87,12)-note.position-Vector2(35,35)
	modulate = note.modulate

func _process(delta: float) -> void:
	sync_layout()
	if not animating:
		if not frozen:
			frozen = true
			view.render_target_update_mode = SubViewport.UPDATE_ONCE
			set_process(false)
		return
	age += delta
	var t := clampf(age/DURATION,0,1)
	var ease := 1.0-pow(1.0-clampf(t/0.76,0,1),3)
	pin.position = Vector3(0,-0.008,0.0005)+Vector3(0.038,0.025,0.08)*(1-ease)
	pin.rotation = ROTATION+Vector3(-0.5,0.25,-1.3)*(1-ease)
	if t>=0.76 and not impact:
		impact = true
		sound.stream = TAP
		sound.play()
	if t>=1:
		animating = false
