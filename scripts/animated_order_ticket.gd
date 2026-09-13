extends Control
## One lazy renderer per promoted ticket. Queued tickets restore their ordinary UI.
const MODEL = preload("res://models/order_ticket/order_ticket.glb")
const BLANK = preload("res://models/order_ticket/textures/ticket_blank.png")
const PAPER_SHADER = preload("res://shaders/order_ticket_live.gdshader")
const THUMBTACK = preload("res://models/thumbtack/thumbtack_red.glb")
const FLY_SECONDS := 0.55
const PIN_SECONDS := 0.26
const UNROLL_SPEED := 1.6
const PAD := 40.0
const PIXELS_PER_METER := 1000.0
const DISPLAY_SCALE := 0.8

var active := false
var state: StringName = &"static"
var _wrap: Control
var _note: Control
var _source: SubViewport
var _view: SubViewport
var _display: TextureRect
var _model: Node3D
var _paper_material: ShaderMaterial
var _camera: Camera3D
var _player: AnimationPlayer
var _clips: Dictionary = {}
var _wind_left := 12.0
var _pending_tap := false
var _rng := RandomNumberGenerator.new()
var _logical_size := Vector2.ZERO
var _thumbtack: Node3D
var _arrival_age := 0.0
var _reopening := false
var _pin_impact_fired := false
var _audio: AudioStreamPlayer
var _tap_sound: AudioStream
var _rustle_sound: AudioStream
var _pin_whoosh: AudioStream
var _pin_tap: AudioStream
var _header_clearance: Control
var _grabbed := false
var _drag_started := false
var _press_screen := Vector2.ZERO
var _last_drag_screen := Vector2.ZERO
var _last_drag_sound_ms := 0
var _touch_id := -1
var _pin_target := Vector3(0.0, -0.008, 0.0005)
var _pin_rotation := Vector3(deg_to_rad(50.0), deg_to_rad(-18.0), deg_to_rad(-28.0))
const PIN_SCALE := 3.6
const FLY_OFFSET := Vector2(-160.0, 110.0)

func setup(wrap: Control, note: Control) -> void:
	_wrap = wrap
	_note = note
	_note.minimum_size_changed.connect(sync_layout, CONNECT_DEFERRED)
	name = "MainTicketMotion"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()
	_header_clearance = _note.find_child("ToonThumbtackClearance", true, false) as Control
	_tap_sound = load("res://sounds/ticket/paper_tap.wav") as AudioStream
	_rustle_sound = load("res://sounds/ticket/paper_rustle.wav") as AudioStream
	_pin_whoosh = load("res://sounds/ticket/pin_whoosh.wav")
	_pin_tap = load("res://sounds/ticket/pin_tap.wav")
	_audio = AudioStreamPlayer.new()
	_audio.name = "PaperFoley"
	_audio.bus = "Master"
	_audio.max_polyphony = 3
	add_child(_audio)
	set_process_input(false)
	_source = SubViewport.new()
	_source.name = "LiveOrderPrint"
	_source.disable_3d = true
	_source.transparent_bg = true
	_source.world_2d = World2D.new()
	_source.size_2d_override_stretch = true
	_source.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_source)
	_view = SubViewport.new()
	_view.name = "AnimatedPaperView"
	_view.own_world_3d = true
	_view.world_2d = World2D.new()
	_view.transparent_bg = true
	_view.msaa_3d = Viewport.MSAA_DISABLED # 2x render resolution provides clean supersampled edges.
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_view)
	_model = MODEL.instantiate() as Node3D
	_view.add_child(_model)
	_thumbtack = THUMBTACK.instantiate() as Node3D
	_thumbtack.name = "PlacedRedThumbtack"
	_thumbtack.rotation = _pin_rotation
	_thumbtack.scale = Vector3.ONE * PIN_SCALE
	_thumbtack.position = _pin_target
	_thumbtack.hide()
	_view.add_child(_thumbtack)
	var environment := Environment.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(1.0, 0.95, 0.87)
	environment.ambient_light_energy = 0.32
	var studio := WorldEnvironment.new()
	studio.environment = environment
	_view.add_child(studio)
	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-42.0, -35.0, 0.0)
	key_light.light_energy = 0.85
	key_light.shadow_enabled = true
	key_light.shadow_opacity = 0.45
	key_light.shadow_blur = 2.0
	key_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key_light.directional_shadow_max_distance = 2.0
	key_light.shadow_bias = 0.02
	key_light.shadow_normal_bias = 0.2
	_view.add_child(key_light)
	_player = _find_type(_model, "AnimationPlayer") as AnimationPlayer
	var mesh := _find_type(_model, "MeshInstance3D") as MeshInstance3D
	var material := ShaderMaterial.new()
	material.shader = PAPER_SHADER
	material.set_shader_parameter("live_print", _source.get_texture())
	material.set_shader_parameter("blank_atlas", BLANK)
	_paper_material = material
	mesh.set_surface_override_material(0, material)
	mesh.lod_bias = 128.0 # Preserve the thin front/back shell at UI scale.
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for library_name in _player.get_animation_library_list():
		var library := _player.get_animation_library(library_name).duplicate(true) as AnimationLibrary
		_player.remove_animation_library(library_name)
		_player.add_animation_library(library_name, library)
	for clip in _player.get_animation_list():
		var short_name := String(clip).get_slice("/", String(clip).get_slice_count("/") - 1)
		_clips[short_name] = clip
		var animation := _player.get_animation(clip)
		animation.loop_mode = Animation.LOOP_NONE
	# Imported rotation keys include the rig's bind orientation. Blend around
	# the flat static pose, never identity: the anchor rests at 180 degrees.
	var rest_clip := _player.get_animation(_clips["static"])
	var wind_clip := _player.get_animation(_clips["wave"])
	for track in wind_clip.get_track_count():
		if wind_clip.track_get_type(track) != Animation.TYPE_ROTATION_3D:
			continue
		var rest_track := rest_clip.find_track(wind_clip.track_get_path(track), Animation.TYPE_ROTATION_3D)
		if rest_track < 0:
			continue
		var rest_rotation: Quaternion = rest_clip.track_get_key_value(rest_track, 0)
		for key in wind_clip.track_get_key_count(track):
			var rotation: Quaternion = wind_clip.track_get_key_value(track, key)
			wind_clip.track_set_key_value(track, key, rest_rotation.slerp(rotation, 0.45))
	_player.animation_finished.connect(_on_finished)
	_player.active = false
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.near = 0.5
	_camera.far = 1.5
	_view.add_child(_camera)
	_camera.current = true
	_display = TextureRect.new()
	_display.name = "AnimatedMainTicket"
	_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_display.texture = _view.get_texture()
	_display.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_display.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(_display)
	hide()
	set_process(false)

func _find_type(node: Node, type_name: String) -> Node:
	if node.is_class(type_name):
		return node
	for child in node.get_children():
		var found := _find_type(child, type_name)
		if found != null:
			return found
	return null

func set_active(value: bool) -> void:
	if not value:
		if not active:
			return
		active = false
		_cancel_grab()
		_audio.stop()
		if _header_clearance != null:
			_header_clearance.custom_minimum_size.y = 29.0
		_pending_tap = false
		_thumbtack.hide()
		_model.rotation = Vector3.ZERO
		position = Vector2.ZERO
		scale = Vector2.ONE
		rotation = 0.0
		_player.stop()
		_player.active = false
		_source.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_note.reparent(_wrap, false)
		_note.modulate = _display.modulate
		hide()
		set_process(false)
		state = &"static"
		return
	if _header_clearance != null:
		_header_clearance.custom_minimum_size.y = 8.0
	# _highlight_tickets supplies the current opacity and selected rotation.
	_display.modulate = _note.modulate
	_display.pivot_offset = Vector2(PAD + 87.0, PAD + 8.0)
	_display.rotation = _note.rotation
	_note.modulate = Color.WHITE
	_note.rotation = 0.0
	_note.scale = Vector2.ONE
	_note.position = Vector2.ZERO
	if active:
		sync_layout()
		return
	active = true
	_note.reparent(_source, false)
	sync_layout()
	show()
	_player.active = true
	_source.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_pending_tap = false
	_reopening = false
	_pin_impact_fired = false
	_wind_left = _rng.randf_range(9.0, 18.0)
	_thumbtack.hide()
	_play(&"rolled", 0.0)
	_player.advance(0.0)
	_player.pause()
	state = &"fly"
	_update_roll_view()
	_arrival_age = 0.0
	pivot_offset = Vector2.ZERO
	_apply_flight_pose(0.0)
	set_process(true)

func sync_layout() -> void:
	if not active:
		return
	var wanted := Vector2(174.0, maxf(120.0, _note.get_combined_minimum_size().y))
	_note.size = wanted
	if wanted.is_equal_approx(_logical_size):
		return
	_logical_size = wanted
	_wrap.custom_minimum_size = wanted * DISPLAY_SCALE
	_source.size = Vector2i(wanted * 2.0)
	_source.size_2d_override = Vector2i(wanted)
	_view.size = Vector2i((wanted + Vector2.ONE * PAD * 2.0) * 2.0)
	_display.position = -Vector2.ONE * PAD
	_display.size = wanted + Vector2.ONE * PAD * 2.0
	_model.scale = Vector3(wanted.x / (0.18 * PIXELS_PER_METER), wanted.y / (0.28 * PIXELS_PER_METER), 1.0)
	_camera.size = (wanted.y + PAD * 2.0) / PIXELS_PER_METER
	_camera.position = Vector3(0.0, -wanted.y / (2.0 * PIXELS_PER_METER), 1.0)

func tap() -> void:
	if not active:
		return
	if state in [&"fly", &"unroll", &"pin"]:
		_pending_tap = true
		return
	if state == &"rolled":
		_reopening = true
		_play(&"unroll", 0.0)
		_play_paper_sound(true, -16.0)
		return
	if state == &"roll":
		return
	_play(&"tap", 0.05)
	_play_paper_sound(false, -3.0)
	_wind_left = _rng.randf_range(9.0, 18.0)

func _play(next: StringName, blend: float = 0.2) -> void:
	state = next
	_player.speed_scale = 0.85 if next == &"wave" else (UNROLL_SPEED if next == &"unroll" else 1.0)
	_player.play(_clips[String(next)], blend)
	_update_roll_view()

func _on_finished(_clip: StringName) -> void:
	if not active or state in [&"static", &"rolled", &"fly", &"pin"]:
		return
	if state == &"roll":
		_play(&"rolled", 0.0)
		_player.advance(0.0)
		return # Held indefinitely; no timer unfolds or retracts the ticket.
	if state == &"unroll" and _reopening:
		_reopening = false
		_play(&"static", 0.08)
		return
	if state == &"unroll":
		# The pin only appears once the paper has completely rolled out.
		_play(&"static", 0.0)
		_player.advance(0.0)
		state = &"pin"
		_arrival_age = 0.0
		_thumbtack.show()
		_pin_impact_fired = false
		_audio.stream = _pin_whoosh
		_audio.volume_db = -3.0
		_audio.play()
		_apply_pin_pose(0.0)
	else:
		_play(&"static", 0.28 if state == &"wave" else 0.1)
	_wind_left = _rng.randf_range(9.0, 18.0)

func _apply_flight_pose(t: float) -> void:
	var ease_out := 1.0 - pow(1.0 - t, 3.0)
	position = FLY_OFFSET * (1.0 - ease_out) + Vector2(0.0, -25.0 * sin(PI * t))
	scale = Vector2.ONE * DISPLAY_SCALE * lerpf(0.78, 1.0, ease_out)
	rotation = lerpf(deg_to_rad(-14.0), 0.0, ease_out)

func _apply_pin_pose(t: float) -> void:
	# A swooping, rotating approach, brief aim, quick press, then a springy settle.
	var approach := clampf(t / 0.56, 0.0, 1.0)
	var ease_out := 1.0 - pow(1.0 - approach, 3.0)
	var press := smoothstep(0.56, 0.76, t)
	var settle := clampf((t - 0.76) / 0.24, 0.0, 1.0)
	var spring := sin(settle * PI * 3.0) * exp(-settle * 4.0)
	_thumbtack.position = _pin_target + Vector3(0.052, 0.023, 0.095) * (1.0 - ease_out)
	_thumbtack.position.x -= 0.016 * sin(approach * PI)
	_thumbtack.position.z += 0.021 * (1.0 - press) - 0.002 * spring
	_thumbtack.rotation = _pin_rotation + Vector3(-0.55, 0.36, -1.3) * (1.0 - ease_out)
	_thumbtack.rotation += Vector3(0.14, 0.04, -0.1) * spring
	_thumbtack.scale = Vector3.ONE * PIN_SCALE * (lerpf(1.18, 1.0, ease_out) - 0.045 * spring)
	_model.rotation.x = 0.018 * spring
	if t >= 0.76 and not _pin_impact_fired:
		_pin_impact_fired = true
		_audio.stream = _pin_tap
		_audio.volume_db = -1.0
		_audio.play()

func _advance_arrival(delta: float) -> void:
	if state == &"fly":
		_arrival_age += delta
		var t := clampf(_arrival_age / FLY_SECONDS, 0.0, 1.0)
		_apply_flight_pose(t)
		if t >= 1.0:
			_play(&"unroll", 0.0)
			_player.advance(0.0)
	elif state == &"pin":
		_arrival_age += delta
		var t := clampf(_arrival_age / PIN_SECONDS, 0.0, 1.0)
		_apply_pin_pose(t)
		if t >= 1.0:
			_thumbtack.position = _pin_target
			_thumbtack.rotation = _pin_rotation
			_model.rotation.x = 0.0
			if _pending_tap:
				_pending_tap = false
				_play(&"tap", 0.04)
				_play_paper_sound(false, -3.0)
			else:
				_play(&"static", 0.0)
			_wind_left = _rng.randf_range(9.0, 18.0)

func _process(delta: float) -> void:
	var on_screen := _wrap.is_visible_in_tree()
	_player.active = on_screen
	_source.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on_screen else SubViewport.UPDATE_DISABLED
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on_screen else SubViewport.UPDATE_DISABLED
	if not on_screen:
		return
	_advance_arrival(delta)
	_update_roll_view()
	if state == &"static" and not _grabbed:
		_wind_left -= delta
		if _wind_left <= 0.0:
			_play(&"wave", 0.35)


func _play_paper_sound(rustle: bool, volume: float) -> void:
	_audio.stream = _rustle_sound if rustle else _tap_sound
	_audio.volume_db = volume
	_audio.pitch_scale = _rng.randf_range(0.96, 1.04)
	_audio.play()

func toggle_roll() -> void:
	if not active or state in [&"fly", &"unroll", &"pin", &"roll"]:
		return
	_cancel_grab()
	_pending_tap = false
	if state == &"rolled":
		tap()
	else:
		_play(&"roll", 0.12)
		_play_paper_sound(true, -14.0)

func handle_ticket_input(event: InputEvent) -> bool:
	if not active:
		return false
	var pressed := false
	var twice := false
	var local := Vector2.ZERO
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = event.pressed
		twice = event.double_click
		local = event.position
	elif event is InputEventScreenTouch:
		pressed = event.pressed
		twice = event.double_tap
		local = event.position
		_touch_id = event.index
	else:
		return false
	if not pressed:
		return false
	if twice:
		toggle_roll()
		return true
	if state in [&"static", &"tap", &"wave", &"shake"] and _at_corner(get_transform().affine_inverse() * local):
		_grabbed = true
		_drag_started = false
		_press_screen = _wrap.get_global_transform_with_canvas() * local
		_last_drag_screen = _press_screen
		set_process_input(true)
	else:
		tap()
	return true

func _at_corner(local: Vector2) -> bool:
	return local.y >= _logical_size.y - 32.0 and (local.x <= 32.0 or local.x >= _logical_size.x - 32.0)

func _drag_to(screen: Vector2) -> void:
	if not _grabbed:
		return
	var distance := screen.distance_to(_press_screen)
	var now := Time.get_ticks_msec()
	if distance >= 8.0 and (not _drag_started or (screen.distance_to(_last_drag_screen) >= 18.0 and now - _last_drag_sound_ms > 220)):
		_drag_started = true
		_last_drag_screen = screen
		_last_drag_sound_ms = now
		_play(&"shake", 0.05)
		_play_paper_sound(true, -16.0)

func _release_grab() -> void:
	if not _grabbed:
		return
	var pulled := _drag_started
	_cancel_grab()
	if pulled:
		_play(&"shake", 0.05)
	else:
		tap()

func _cancel_grab() -> void:
	_grabbed = false
	_drag_started = false
	_touch_id = -1
	set_process_input(false)

func _input(event: InputEvent) -> void:
	if not _grabbed:
		return
	if event is InputEventMouseMotion:
		_drag_to(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_release_grab()
	elif event is InputEventScreenDrag and event.index == _touch_id:
		_drag_to(event.position)
	elif event is InputEventScreenTouch and event.index == _touch_id and not event.pressed:
		_release_grab()
	else:
		return
	get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _grabbed:
		_cancel_grab()


func _update_roll_view() -> void:
	# Turn the curled sheet slightly so the spiral opening reads as a tube.
	var curl := 0.0
	if state in [&"fly", &"rolled"]:
		curl = 1.0
	elif state in [&"roll", &"unroll"]:
		var progress := clampf(_player.current_animation_position / 1.2, 0.0, 1.0)
		progress = smoothstep(0.0, 1.0, progress)
		curl = progress if state == &"roll" else 1.0 - progress
	_model.rotation.y = -0.26 * curl
	# Open paper stays evenly colored; only the roll receives studio shading.
	_paper_material.set_shader_parameter("curl_lighting", smoothstep(0.0, 0.35, curl))
