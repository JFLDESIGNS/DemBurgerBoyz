extends Control
## The same Blender truck stars in the menu and the first-shift loading sequence.
signal departure_darkness(amount: float)
signal departure_finished
signal warmup_finished

const TRUCK_SCENE = preload("res://assets/menu_truck/burger_pals_truck.glb")
const DEPARTURE_SECONDS := 1.60
const MENU_FRAME_PADDING := Vector2(160.0, 64.0)
const MENU_CAMERA_HEIGHT := 8.3
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
var _departure_rect := Rect2()
var _departure_done := false
var _departure_last := Vector3.ZERO
var _departure_distance := 0.0
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
	key.light_energy = 2.0 if loading_mode else 1.35
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 65.0
	world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 140, 0)
	fill.light_color = Color("b9e7ff")
	fill.light_energy = 0.65 if loading_mode else 0.45
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
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 36.0
		# Show the nose and serving window like the illustrated title concept.
		camera.position = Vector3(9.0, 1.6, 8.5)
		camera.look_at(Vector3(0.25, 2.6, 0))
		var shadow:=MeshInstance3D.new()
		shadow.name="MenuTruckGroundShadow"
		var plane:=PlaneMesh.new();plane.size=Vector2(10.5,5.0)
		shadow.mesh=plane
		var shadow_mat:=ShaderMaterial.new();shadow_mat.shader=preload("res://shaders/title_truck_shadow.gdshader")
		shadow.material_override=shadow_mat
		shadow.position=Vector3(0,.025,0)
		shadow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		truck.add_child(shadow)
		_build_menu_pals()
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
	if departing or _departure_done: return
	# Overscan every edge without shrinking the truck's on-screen presentation.
	var holder := get_parent() as Control
	if holder == null:
		return
	size = holder.size + MENU_FRAME_PADDING * 2.0
	position = Vector2((holder.size.x - size.x) * 0.5, -MENU_FRAME_PADDING.y)
	camera.size = MENU_CAMERA_HEIGHT * size.y / maxf(holder.size.y, 1.0)
	camera.fov = rad_to_deg(2.0*atan(tan(deg_to_rad(36.0)*.5)*size.y/maxf(holder.size.y,1.0)))

func _sync_visibility() -> void:
	var active := is_visible_in_tree() or _warming
	set_process(active and not _warming)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	if active and not loading_mode and not departing:
		_departure_done = false
		set_as_top_level(false)
		z_index = 0
		z_as_relative = true
		_fit_menu_width()
		truck.rotation = Vector3.ZERO
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
	var screech := AudioStreamPlayer.new()
	screech.stream = preload("res://sounds/vehicles/mail_truck_tire_screech.mp3")
	screech.bus = &"SFX"
	screech.volume_db = -5.0 + linear_to_db(0.75)
	add_child(screech)
	screech.finished.connect(screech.queue_free)
	screech.play()
	var cut := screech.create_tween()
	cut.tween_interval(maxf(.01, screech.stream.get_length() - .63))
	cut.tween_property(screech, "volume_db", -60.0, .03)
	cut.tween_callback(screech.queue_free)
	_departure_rect = get_global_rect()
	set_as_top_level(true)
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = _departure_rect.position
	size = _departure_rect.size
	z_as_relative = false
	z_index = 4095
	_departure_done = false
	_departure_last = Vector3.ZERO
	_departure_distance = 0.0
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
		sample_departure(departure_elapsed / DEPARTURE_SECONDS)
		if departure_elapsed >= DEPARTURE_SECONDS:
			departing = false
			_departure_done = true
			departure_finished.emit()
	elif not _departure_done:
		body.position.y = _body_rest.y + sin(elapsed * 3.2) * 0.015
		burger.rotation.z = sin(elapsed * 2.0) * 0.012

func sample_departure(progress: float) -> void:
	var u := clampf(progress,0.0,1.0)
	var turn := clampf((u-.38)/.62,0.0,1.0)
	var point: Vector3
	var tangent := Vector3.RIGHT
	if u < .38:
		point=Vector3(2.2*pow(u/.38,1.45),0,0)
	else:
		var t:=turn
		var a:=Vector3(2.2,0,0)
		var b:=Vector3(5.0,0,0)
		var c:=Vector3(4.8,0,2.1)
		var d:=Vector3(6.3,0,4.4)
		point=a.bezier_interpolate(b,c,d,t)
		tangent=3.0*(1-t)*(1-t)*(b-a)+6.0*(1-t)*t*(c-b)+3.0*t*t*(d-c)
	_departure_distance+=point.distance_to(_departure_last);_departure_last=point
	truck.position=point;truck.rotation.y=-atan2(tangent.z,tangent.x)
	body.rotation.z=.09*sin(turn*PI)
	burger.rotation.z=-.08*sin(u*14)*sin(u*PI)
	burger.position.y=_burger_rest.y+absf(sin(u*14))*.08
	for wheel in wheels:wheel.rotation.z=-_departure_distance/.86
	if _departure_rect.has_area():
		var expansion:=smoothstep(.04,.72,turn)
		position=_departure_rect.position.lerp(Vector2.ZERO,expansion)
		size=_departure_rect.size.lerp(get_viewport().get_visible_rect().size,expansion)
	var focus:=Vector3(.25,2.6,0).lerp(point+tangent.normalized()*2.6+Vector3(0.4*smoothstep(.45,.95,turn),1.8,0),smoothstep(.25,.90,turn))
	camera.look_at(focus)
	departure_darkness.emit(smoothstep(.82,1.0,u))


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


func _build_menu_pals() -> void:
	# Park the group outside the serving-side edge of the departure lane.
	var group := Node3D.new()
	group.name = "MenuPals"
	world.add_child(group)
	for i in 1:
		var pal = load("res://scripts/customer.gd").new()
		pal.name = "OpeningPal%d" % i
		pal.set_meta("delivery_driver", true)
		pal.is_street_pedestrian = true
		pal.setup(["bun_bottom", "patty", "bun_top"] as Array[String], Color("EF9964") if i == 0 else Color("75D5BD"), 9999.0, 0, 1, -1, -1, {}, true)
		group.add_child(pal)
		pal.set_process(false)
		pal.set_physics_process(false)
		pal.position = Vector3(3.2, 0, -5.2)
		pal.scale = Vector3.ONE * 1.32
		pal.rotation.y = .25 if i == 0 else -.2
		_menu_pal_idle.call_deferred(pal, i)
		for label in pal.find_children("*", "Label3D", true, false): label.hide()
		_menu_actor_shadow(group, pal.position, Vector2(1.1, .8))

func _menu_actor_shadow(parent: Node3D, at: Vector3, dimensions: Vector2) -> void:
	var shadow := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = dimensions
	shadow.mesh = plane
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/title_truck_shadow.gdshader")
	shadow.material_override = material
	shadow.position = at + Vector3(0, .025, 0)
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(shadow)


func _menu_pal_idle(pal: Node3D, index: int) -> void:
	pal.set_process(false)
	pal.set_physics_process(false)
	if pal._anim_player != null and pal._anim_player.has_animation("kenney/Idle"):
		pal._anim_player.play("kenney/Idle")
		pal._anim_player.seek(index * .7, true)
