extends Control
## The same Blender truck stars in the menu and the first-shift loading sequence.
signal departure_finished
signal warmup_finished

const TRUCK_SCENE = preload("res://assets/menu_truck/burger_pals_truck.glb")
const DEPARTURE_SECONDS := 1.35
var loading_mode := false
var viewport: SubViewport
var world: Node3D
var camera: Camera3D
var truck: Node3D
var body: Node3D
var burger: Node3D
var animation: AnimationPlayer
var clip: StringName
var wheels: Array[Node3D] = []
var smoke: Array[CPUParticles3D] = []
var elapsed := 0.0
var shot_index := -1
var camera_cuts := 0
var departing := false
var departure_elapsed := 0.0
var _cycle := -1
var _body_rest := Vector3.ZERO
var _burger_rest := Vector3.ZERO
var _skid_mesh := ImmediateMesh.new()
var _skid_material := StandardMaterial3D.new()
var _skid_points: Array[Vector3] = []
var _skid_clock := 0.0
var _exit_camera := Vector3.ZERO
var _fade: ColorRect
var warmup_complete := false
var _warming := false
var warmup_shots: Array[int] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	viewport = SubViewport.new()
	viewport.size = Vector2i(960, 540)
	viewport.own_world_3d = true
	viewport.transparent_bg = not loading_mode
	viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(viewport)
	world = Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("94b9b5")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("dce9ed")
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	world.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, -28, 0)
	key.light_color = Color("fff1d7")
	key.light_energy = 2.0
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 65.0
	world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 140, 0)
	fill.light_color = Color("b9e7ff")
	fill.light_energy = 0.65
	world.add_child(fill)
	var model := TRUCK_SCENE.instantiate()
	world.add_child(model)
	truck = model.find_child("TruckRoot", true, false) as Node3D
	body = model.find_child("BodyLean", true, false) as Node3D
	burger = model.find_child("BurgerBounce", true, false) as Node3D
	animation = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for name_part in ["WheelFrontLeft", "WheelFrontRight", "WheelRearLeft", "WheelRearRight"]:
		wheels.append(model.find_child(name_part, true, false) as Node3D)
	for candidate in animation.get_animation_list():
		if candidate != &"RESET":
			clip = candidate
			break
	animation.play(clip)
	animation.seek(0.0, true)
	animation.pause()
	_body_rest = body.position
	_burger_rest = burger.position
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 43.0
	camera.far = 350.0
	world.add_child(camera)
	if loading_mode:
		_build_driving_stage()
		_fade = ColorRect.new()
		_fade.color = Color(0.025, 0.085, 0.095, 0)
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_fade)
	else:
		truck.position = Vector3.ZERO
		truck.rotation = Vector3.ZERO
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 6.9
		camera.position = Vector3(9.5, 6.4, 18)
		camera.look_at(Vector3(0, 2.8, 0))
		if get_parent() is Control:
			set_anchors_preset(Control.PRESET_TOP_LEFT)
			get_parent().resized.connect(_fit_menu_width)
			get_viewport().size_changed.connect(_fit_menu_width)
			call_deferred("_fit_menu_width")
	visibility_changed.connect(_sync_visibility)
	_sync_visibility()
	if loading_mode:
		sample_loading(0.0)


func prewarm_hidden_render() -> void:
	# Compile every shot, transparent smoke and skid material before departure.
	# Concurrent menu/start requests share this one warmup.
	if warmup_complete or not loading_mode:
		return
	if _warming:
		await warmup_finished
		return
	_warming = true
	_sync_visibility()
	for emitter in smoke:
		emitter.preprocess = 0.6
		emitter.restart()
	for pose in [0.8, 1.9, 2.8, 3.8, 4.8, 7.9]:
		sample_loading(pose)
		if not warmup_shots.has(shot_index):
			warmup_shots.append(shot_index)
		# A process tick alone can finish before the renderer draws this pose.
		for _frame in 3:
			if DisplayServer.get_name() == "headless":
				await get_tree().process_frame
			else:
				await RenderingServer.frame_post_draw
	_warming = false
	warmup_complete = true
	for emitter in smoke:
		emitter.preprocess = 0.0
	end_hidden_prewarm()
	warmup_finished.emit()


func end_hidden_prewarm() -> void:
	restart_loading()
	_sync_visibility()

func _fit_menu_width() -> void:
	# Extend the transparent viewport to the real screen edges for the drive-off.
	var holder := get_parent() as Control
	if holder == null:
		return
	var screen_width := get_viewport_rect().size.x
	size = Vector2(screen_width, holder.size.y)
	position.x = (holder.size.x - screen_width) * 0.5

func _sync_visibility() -> void:
	var active := is_visible_in_tree() or _warming
	set_process(active and not _warming)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	if active and not loading_mode and not departing:
		truck.position = Vector3.ZERO
		body.rotation = Vector3.ZERO
		burger.position = _burger_rest
	for emitter in smoke:
		emitter.emitting = _warming
		emitter.set_process_internal(active)

func restart_loading() -> void:
	elapsed = 0.0
	_cycle = -1
	shot_index = -1
	camera_cuts = 0
	_skid_clock = 0.0
	for emitter in smoke:
		emitter.restart()
	sample_loading(0.0)

func play_departure() -> void:
	if departing:
		await departure_finished
		return
	departing = true
	departure_elapsed = 0.0
	await departure_finished

func _process(delta: float) -> void:
	elapsed += delta
	if loading_mode:
		sample_loading(elapsed)
		return
	if departing:
		departure_elapsed += delta
		var t := minf(departure_elapsed, DEPARTURE_SECONDS)
		# +X is the truck's nose. Blender +Y axle spin becomes Godot -Z.
		truck.position.x = 1.5 * t + 13.0 * t * t
		body.rotation.z = 0.085 * sin(minf(t / 0.8, 1.0) * PI)
		burger.rotation.z = -0.10 * sin(t * 8.0) * exp(-t)
		burger.position.y = _burger_rest.y + absf(sin(t * 8.0)) * 0.09
		for wheel in wheels:
			wheel.rotation.z = -truck.position.x / 0.86
		if departure_elapsed >= DEPARTURE_SECONDS:
			departing = false
			departure_finished.emit()
	else:
		body.position.y = _body_rest.y + sin(elapsed * 3.2) * 0.015
		burger.rotation.z = sin(elapsed * 2.0) * 0.012

func sample_loading(time: float) -> void:
	var length := animation.get_animation(clip).length
	var cycle := int(time / length)
	var t := fmod(time, length)
	if cycle != _cycle:
		_cycle = cycle
		_skid_clock = time - 0.05
		_skid_points.clear()
		_skid_mesh.clear_surfaces()
		for emitter in smoke:
			emitter.restart()
	animation.seek(t, true)
	var focus := truck.global_position + Vector3(0, 2.35, 0)
	var next_shot := 0 if t < 1.72 else (1 if t < 2.50 else (2 if t < 3.45 else (3 if t < 4.6 else 4)))
	if next_shot != shot_index:
		shot_index = next_shot
		camera_cuts += 1
		if shot_index == 4:
			_exit_camera = camera.position
	# Deliberate cuts: low chase, overhead drift, countersteering close-up, exit.
	match shot_index:
		0:
			camera.position = focus + Vector3(11, 3.9, 15.5)
			camera.look_at(focus)
		1:
			var orbit_focus := truck.global_position * 0.55 + Vector3(0, 1.7, 0)
			camera.position = orbit_focus + Vector3(3 if cycle % 2 == 0 else -4, 24, 9)
			camera.look_at(orbit_focus)
		2:
			camera.position = focus + Vector3(-12, 5.5, 15)
			camera.look_at(focus)
		3:
			camera.position = focus + Vector3(10, 4.2, 17)
			camera.look_at(focus)
		4:
			camera.position = _exit_camera
	for emitter in smoke:
		emitter.emitting = t > 0.65 and t < 4.4 and (is_visible_in_tree() or _warming)
	# Fade hides the clip reset after the truck has sped away.
	_fade.color.a = maxf(1.0 - t / 0.18, clampf((t - length + 0.20) / 0.20, 0.0, 1.0))
	if t > 1.72 and t < 3.95 and time - _skid_clock > 0.045:
		_skid_clock = time
		for side in [-1.0, 1.0]:
			var point := truck.to_global(Vector3(-2.75, 0, side * 1.2))
			point.y = 0.025
			_skid_points.append(point)
		_update_skids()

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material

func _build_driving_stage() -> void:
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(500, 500)
	floor_mesh.mesh = plane
	floor_mesh.position.y = -0.015
	floor_mesh.material_override = _material(Color("376269"))
	world.add_child(floor_mesh)
	# A painted practice lot gives the drift scale and a stable visual reference.
	for i in 32:
		var marker := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.14, 0.015, 1.0)
		marker.mesh = box
		var angle := TAU * float(i) / 32.0
		marker.position = Vector3(cos(angle) * 11, 0, sin(angle) * 11)
		marker.rotation.y = -angle
		marker.material_override = _material(Color("e8ce8a"))
		world.add_child(marker)
	var skid := MeshInstance3D.new()
	skid.mesh = _skid_mesh
	_skid_material.albedo_color = Color("21383e")
	_skid_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	world.add_child(skid)
	for side in [-1.0, 1.0]:
		var particles := CPUParticles3D.new()
		particles.name = "TireSmokeLeft" if side > 0 else "TireSmokeRight"
		particles.position = Vector3(-2.8, 0.30, 1.25 * side)
		particles.amount = 35
		particles.lifetime = 1.25
		particles.local_coords = false
		particles.direction = Vector3(-1, 0.6, 0)
		particles.spread = 35.0
		particles.gravity = Vector3(0, 1.2, 0)
		particles.initial_velocity_min = 0.8
		particles.initial_velocity_max = 2.0
		particles.scale_amount_min = 0.6
		particles.scale_amount_max = 1.8
		var growth := Curve.new()
		growth.add_point(Vector2(0, 0.35))
		growth.add_point(Vector2(1, 1.0))
		particles.scale_amount_curve = growth
		var gradient := Gradient.new()
		gradient.set_color(0, Color(0.85, 0.89, 0.88, 0.8))
		gradient.set_color(1, Color(0.9, 0.94, 0.92, 0))
		particles.color_ramp = gradient
		var puff := SphereMesh.new()
		puff.radius = 0.32
		puff.height = 0.64
		puff.radial_segments = 8
		puff.rings = 4
		var material := _material(Color.WHITE)
		material.vertex_color_use_as_albedo = true
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		puff.material = material
		particles.mesh = puff
		particles.emitting = false
		truck.add_child(particles)
		smoke.append(particles)

func _update_skids() -> void:
	if _skid_points.size() < 4:
		return
	_skid_mesh.clear_surfaces()
	_skid_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _skid_material)
	for i in range(2, _skid_points.size()):
		var a := _skid_points[i - 2]
		var b := _skid_points[i]
		var width := (b - a).normalized().cross(Vector3.UP) * 0.12
		for point in [a - width, b - width, b + width, a - width, b + width, a + width]:
			_skid_mesh.surface_add_vertex(point)
	_skid_mesh.surface_end()
