extends Node
# Host owns cooking decisions; peers receive only the cosmetic pickup / throw.
var game: Node
var customer: Node3D
var station := -1
var ingredient := ""
var phase := ""
var elapsed := 0.0
var snapshot: Array = []
var cooldown := 0.0

func next_ingredient(items: Array, order: Array) -> String:
	# Never alter a different recipe or invent patties / unavailable stock.
	for item in items:
		if items.count(item) > order.count(item): return ""
	if not items.has("patty") or items.count("patty") != order.count("patty"): return ""
	for id in order:
		if id in ["bun_bottom", "bun_top", "patty"]: continue
		if not items.has(id):
			if int(game.supply_stock.get(id, 0)) > 0: return id
			return ""
	return ""

func valid_job() -> bool:
	return is_instance_valid(customer) and customer.is_waiting and not customer.is_leaving \
		and not customer.get_meta("serve_review_pending", false) \
		and station >= 0 and station < game.stations.size() \
		and game.stations[station].items == snapshot

func update(delta: float) -> bool:
	cooldown = maxf(0.0, cooldown - delta)
	if game.grill_on_fire or game._serve_fly_busy or game._ingredient_fly_busy \
		or is_instance_valid(game.grill_roomba_carry_patty) or is_instance_valid(game.grill_roomba_scoop_patty):
		phase = ""
		return false
	if phase == "":
		if cooldown > 0.0: return false
		cooldown = 0.5
		customer = game._resolve_serve_customer()
		if not is_instance_valid(customer) or not customer.is_waiting or customer.is_leaving \
			or customer.get_meta("mobile_order", false) or customer.get_meta("serve_review_pending", false): return false
		station = game.active_station
		if station < 0 or station >= game.stations.size(): return false
		snapshot = game.stations[station].items.duplicate()
		var order: Array = game.GameDataScript.order_burger_items(customer.order)
		ingredient = next_ingredient(snapshot, order)
		if ingredient == "":
			if game._find_perfect_station_for(customer.order) == station and not game._station_has_melting_cheese(station):
				game._update_roomba_spatula_hinge(true, delta)
				game._submit_serve_request(customer, station)
				cooldown = 2.0
			return false
		if game._is_condiment(ingredient) and (game._condiment_bottle_busy(ingredient) or game.condiment_tool_held != ""): return false
		game._roomba_clear_patty_task()
		phase = "drive"
		elapsed = 0.0
	if not valid_job():
		phase = ""
		return false
	elapsed += delta
	var robot: Node3D = game.grill_roomba_root
	if phase == "drive":
		var source: Vector3 = game._supply_storage_location(ingredient, "ingredient")
		var target: Vector2 = game._roomba_clamp_xz_to_bounds(Vector2(source.x, source.z))
		var current := Vector2(robot.global_position.x, robot.global_position.z)
		var heading: float = game._roomba_heading_to_target(target - current)
		heading = game._roomba_patty_safe_heading(current, heading, target)
		game.grill_roomba_heading = game._roomba_smooth_heading(game.grill_roomba_heading, heading, delta)
		robot.rotation_degrees.y = game._roomba_visual_yaw_degrees()
		var step: Vector2 = game._roomba_forward_xz() * minf(0.65 * delta, current.distance_to(target))
		var next: Vector2 = game._roomba_clamp_xz_to_bounds(current + step)
		if not game._roomba_body_hits_patty(next):
			robot.global_position = Vector3(next.x, game.GRILL_SURFACE_Y + game.ROOMBA_SIT_Y, next.y)
		game.grill_roomba_vel = (next - current) / maxf(delta, 0.001)
		game._update_roomba_spatula_hinge(false, delta)
		if current.distance_to(target) < 0.15 or elapsed > 2.5:
			phase = "throw"
			elapsed = 0.0
			var fork: Vector3 = game._roomba_carry_world_pos()
			if game.mp_enabled: game.mp_robot_cook_visual.rpc(ingredient, station, source, fork)
			else: game.mp_robot_cook_visual(ingredient, station, source, fork)
	else:
		game.grill_roomba_vel = Vector2.ZERO
		game._update_roomba_spatula_hinge(elapsed > 0.65 and elapsed < 1.0, delta)
		if elapsed >= 1.25:
			# Revalidate at landing: a player may have changed the burger mid-flight.
			if valid_job(): game._add_ingredient_to_station(station, ingredient)
			phase = ""
			cooldown = 0.35
	return true

func visual(id: String, index: int, source: Vector3, fork: Vector3) -> void:
	var sauce: bool = game._is_condiment(id)
	var piece: MeshInstance3D
	var bottle: Node3D
	var stream: MeshInstance3D
	if sauce:
		piece = MeshInstance3D.new()
		var blob := SphereMesh.new()
		blob.radius = 0.045
		blob.height = 0.055
		piece.mesh = blob
		piece.material_override = game._condiment_stream_material(id)
		var original: Node3D = game.condiment_bottle_roots.get(id)
		if is_instance_valid(original):
			bottle = original.duplicate()
			add_child(bottle)
			bottle.global_transform = original.global_transform
			bottle.visible = true
			for child in bottle.find_children("*", "CollisionObject3D", true, false): child.input_ray_pickable = false
		stream = MeshInstance3D.new()
		stream.material_override = game._condiment_stream_material(id)
		add_child(stream)
	else:
		piece = game._make_thrown_ingredient_card(id, game.FoodSpritesScript.get_tex(id))
		piece.rotation_degrees.x = -50.0
	add_child(piece)
	piece.global_position = source
	var destination: Vector3 = game._condiment_pour_target_world(index)
	var tween := create_tween()
	tween.tween_method(func(t: float):
		if sauce:
			piece.global_position = fork
			piece.scale = Vector3.ONE * maxf(0.01, t)
			if is_instance_valid(bottle):
				bottle.global_position = source.lerp(fork + Vector3(0, 0.28, 0), minf(1.0, t * 2.5))
				bottle.rotation_degrees.z = lerpf(0.0, 155.0, minf(1.0, t * 2.5))
			if t > 0.4:
				stream.mesh = game._make_condiment_stream_curve_mesh(fork + Vector3(0, 0.16, 0), fork, t)
		else:
			piece.global_position = source.lerp(fork, t) + Vector3.UP * sin(PI * t) * 0.2
	, 0.0, 1.0, 0.65)
	tween.tween_callback(func():
		if is_instance_valid(stream): stream.hide()
		if is_instance_valid(game.game_audio): game.game_audio.play_build_whoosh()
	)
	tween.tween_method(func(t: float):
		piece.global_position = fork.lerp(destination, t) + Vector3.UP * sin(PI * t) * 0.5
		if not sauce: piece.rotation.z = t * TAU
		if is_instance_valid(bottle):
			bottle.global_position = (fork + Vector3(0, 0.28, 0)).lerp(source, t)
			bottle.rotation_degrees.z = lerpf(155.0, 0.0, t)
	, 0.0, 1.0, 0.6)
	tween.tween_callback(func():
		if is_instance_valid(game.game_audio): game.game_audio.play_ingredient_landing()
		queue_free()
	)
