extends SceneTree
const Vehicle = preload("res://scripts/street_vehicle.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var pool: Array = []
	for path in Vehicle.MODEL_PATHS:
		check(ResourceLoader.exists(path), "Missing imported vehicle: " + path)
		pool.append(load(path) as PackedScene)
	var actor := Vehicle.new()
	root.add_child(actor)
	actor.set_pool(pool)
	check(actor.models.size() == 7, "Expected all seven 3D variants")
	check(actor.find_children("*", "Sprite3D", true, false).is_empty(), "Traffic still contains a 2D car")
	for i in actor.models.size():
		actor.set_variant(i)
		var model := actor.models[i]
		var meshes := model.find_children("*", "MeshInstance3D", true, false)
		var wheels: Array[Node3D] = []
		var wells: Array[Node3D] = []
		var body: Node3D
		for node in meshes:
			if str(node.name).begins_with("Wheel_"):
				wheels.append(node)
			elif str(node.name).begins_with("WheelWell_"):
				wells.append(node)
			elif "Body" in str(node.name):
				body = node
		check(wheels.size() == 4 and wells.size() == 4 and meshes.size() == 9, "Missing independent wheels or recessed wells: %d" % i)
		var bounds := actor.get_bounds()
		check(absf(bounds.position.y) < 0.01 and bounds.size.x > 3.0 and bounds.size.x < 5.0, "Incorrect exported origin or scale: %d %s" % [i, bounds])
		var player := actor.players[i]
		check(player != null and player.has_animation(Vehicle.DRIVE_CLIP), "Missing driving animation: %d" % i)
		if player == null:
			continue
		check(is_equal_approx(player.get_animation(Vehicle.DRIVE_CLIP).length, 2.0), "Incorrect loop duration")
		var initial := wheels[0].quaternion
		var rest := model.position
		var speed: float = Vehicle.WHEEL_RADII[i] * TAU * 2.0
		actor.advance_driving(0.02, speed)
		var step := initial.inverse() * wheels[0].quaternion
		check(step.get_axis().z < -0.98, "Wheel turns backwards after Blender-to-Godot axis conversion: %d" % i)
		check(absf(step.get_angle() - TAU * 2.0 * 0.02) < 0.025, "Wheel speed does not match distance: %d" % i)
		actor.advance_driving(0.23, speed)
		check(body != null and body.position.y > 0.008, "Blender suspension bounce missing")
		check(model.position.is_equal_approx(rest), "In-place loop contains root motion")
		check(wells[0].get_parent() == body, "Wheel well should follow suspension, not spin")
		player.seek(1.99, true)
		var before_seam := wheels[0].quaternion
		actor.advance_driving(0.02, speed)
		check(before_seam.angle_to(wheels[0].quaternion) < 0.30, "Driving loop jumps at seam")
		actor.reset_pose()
		actor.scale = Vector3.ONE * 0.5
		var before_scaled := wheels[0].quaternion
		actor.advance_driving(0.01, speed)
		check(absf(before_scaled.angle_to(wheels[0].quaternion) - TAU * 2.0 * 0.02) < 0.025, "Wheel speed ignores model scale")
		actor.scale = Vector3.ONE
	actor.face_direction(-1.0)
	check((actor.basis * Vector3.RIGHT).x < -0.99, "Vehicle does not face leftward world travel")
	actor.face_direction(1.0)
	check((actor.basis * Vector3.RIGHT).x > 0.99, "Vehicle does not face rightward world travel")

	# Exercise the actual game traffic callbacks without booting unrelated stations.
	var holder := Node3D.new()
	root.add_child(holder)
	var game = load("res://scripts/game.gd").new()
	game._street_car_model_cache = pool
	game._build_street_car(holder)
	check(game.street_car.models.size() == 7, "Game did not bind all seven models")
	check(is_equal_approx(float(game.GFX_DEFAULTS["street_car_size"]), 0.8), "3D car default was not reduced by 20 percent")
	var car_size_slider := HSlider.new()
	car_size_slider.step = 0.01
	car_size_slider.value = 0.64
	game.gfx_sliders["street_car_size"] = car_size_slider
	game._apply_street_car_look()
	check(is_equal_approx(game.street_car.scale.x, 0.64 * game.STREET_CAR_MODEL_SCALE), "Tuned 3D car scale was not reduced from 0.80 to 0.64: %s" % game.street_car.scale)
	game.playing = true
	game.street_car_wait = 0.0
	game._update_street_car(0.01)
	check(game.street_car_active and game.street_car.visible, "Game traffic failed to spawn")
	check(game.street_car.rotation.y > 3.0, "Game car faces the wrong way")
	var start_x: float = game.street_car.position.x
	var phase: float = game.street_car.players[game.street_car.variant_index].current_animation_position
	game._update_street_car(0.03)
	check(game.street_car.position.x < start_x, "Game car did not move down the existing lane")
	check(game.street_car.players[game.street_car.variant_index].current_animation_position != phase, "Game does not play Blender animation")
	check(is_equal_approx(game.street_car.position.y, game._street_car_wheel_y()), "Tires do not remain on road contact line")
	game.shift_paused = true
	var paused_position: Vector3 = game.street_car.position
	var paused_phase: float = game.street_car.players[game.street_car.variant_index].current_animation_position
	game._update_street_car(0.1)
	check(game.street_car.position.is_equal_approx(paused_position), "Paused traffic keeps moving")
	check(is_equal_approx(game.street_car.players[game.street_car.variant_index].current_animation_position, paused_phase), "Paused wheels keep turning")
	game.shift_paused = false
	game.options_menu_open = true
	game._update_street_car(0.1)
	check(is_equal_approx(game.street_car.players[game.street_car.variant_index].current_animation_position, paused_phase), "Tuning preview keeps animating")
	game.options_menu_open = false
	game.street_car.position.x = -30.0
	game._update_street_car(0.01)
	check(not game.street_car_active and not game.street_car.visible and game.street_car_wait > 0.0, "Completed pass does not hide and schedule the next car")
	game.street_car_wait = 0.0
	game._update_street_car(0.01)
	game.playing = false
	game._update_street_car(0.01)
	check(not game.street_car.visible and not game.street_car_exhaust.emitting, "Stopped game leaves traffic effects active")
	car_size_slider.free()
	game.free()
	holder.queue_free()
	actor.queue_free()
	await process_frame
	if failures.is_empty():
		print("STREET_VEHICLES_SMOKE_OK seven models, recessed wells, loop seam, wheel speed/direction, scaling, ground contact, traffic lifecycle and pause")
	quit(0 if failures.is_empty() else 1)
