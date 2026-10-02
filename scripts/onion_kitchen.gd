extends Node

const Batch = preload("res://scripts/onion_batch.gd")
var game: Node
var batches: Array = []
var drag: Dictionary = {}
var chop_left := 0.0
var chop_target := Vector3.ZERO
var blade_bounds := AABB()
var blade_yaw := 0.0
var sweep_previous := Vector2.INF
var sweep_contact := 0.0

func clear() -> void:
	drag.clear()
	for batch in batches:
		if is_instance_valid(batch): batch.queue_free()
	batches.clear()

func blocked(pos: Vector3, ignore: Node = null) -> bool:
	for batch in batches:
		if is_instance_valid(batch) and batch != ignore and Vector2(pos.x-batch.position.x,pos.z-batch.position.z).length() < .28: return true
	return false

func spawn(screen: Vector2, spend: bool = true) -> bool:
	var pos: Vector3 = game._grill_plane_from_screen(screen)
	if pos == Vector3.ZERO or not game._is_on_grill_surface(pos): return false
	if game._patty_blocked_at(pos) or not game._can_fit_patty_at(pos):
		game._flash("Clear a little space for the onions", Color("FFE082")); return false
	if spend and not game._mp_spend_ingredient("onion"): return false
	var batch = Batch.new(); batch.game = game
	game.world.add_child(batch)
	batch.global_position = Vector3(pos.x,game.GRILL_SURFACE_Y+.008,pos.z)
	batches.append(batch)
	game._play_ingredient_touch_sfx("onion")
	game._flash("Onion slice — two cuts, then slide the pile",Color("FFE6B3"))
	return true

func _pick(screen: Vector2):
	var pos: Vector3 = game._grill_plane_from_screen(screen)
	if pos == Vector3.ZERO: return null
	var closest = null
	var distance := .23
	for batch in batches:
		if not is_instance_valid(batch): continue
		var d := Vector2(pos.x-batch.global_position.x,pos.z-batch.global_position.z).length()
		if d < distance: closest = batch; distance = d
	return closest

func handle_input(event: InputEvent) -> bool:
	if not game.playing or game.options_menu_open or game.shift_paused or game._boss_speech_active():
		if not drag.is_empty() and is_instance_valid(drag.batch): drag.batch.pressed = false
		drag.clear(); return false
	if drag.is_empty():
		if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed): return false
		if game.spatula_patty != null or game.dragging_patty != null or game.cheese_held or game.brush_held or game.oil_held or game.shaker_held or game.condiment_tool_held != "": return false
		if game._ui_blocks_world_click(event.position): return false
		var batch = _pick(event.position)
		if batch == null: return false
		batch.slide_velocity = Vector2.ZERO
		batch.pressed = true
		var hit: Vector3 = game._grill_plane_from_screen(event.position)
		drag = {"batch":batch,"origin":event.position,"moved":false,"direction":Vector2.ZERO,"target":Vector2(batch.global_position.x,batch.global_position.z),"offset":Vector2(batch.global_position.x-hit.x,batch.global_position.z-hit.z)}
		return true
	var batch = drag.batch
	if not is_instance_valid(batch): drag.clear(); return false
	if event is InputEventMouseMotion:
		if event.position.distance_to(drag.origin) > 5: drag.moved = true
		if drag.moved:
			var pos: Vector3 = game._grill_plane_from_screen(event.position)
			if pos != Vector3.ZERO and game._is_near_grill_for_place(pos):
				drag.target = Vector2(pos.x,pos.z)+drag.offset
		return true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var moved: bool = drag.moved; batch.pressed = false; drag.clear()
		if moved:
			if game._is_over_garbage(event.position): batches.erase(batch); batch.queue_free()
			elif game._is_build_drop_at(event.position): portion(batch)
		elif batch.chops < 2:
			if chop_left <= 0:
				chop_left = .32; chop_target = batch.global_position
				get_tree().create_timer(.14).timeout.connect(func():
					if not is_instance_valid(batch) or not game.playing or game.shift_paused or game.options_menu_open or game._boss_speech_active(): return
					batch.chop()
					if game.game_audio: game.game_audio.play_cutting_board_thud(); game.game_audio.play_smash_sizzle(.4)
				)
		elif batch.is_ready(): portion(batch)
		return true
	return false

func portion(batch: Node) -> bool:
	if not batch.is_ready(): game._flash("Finish two chops and let the onions cook",Color("FFE082")); return false
	var st: Dictionary = game.stations[game.STATION_CRAFT]
	if not st.items.has("patty") or st.items.has("onion") or game._serve_fly_busy: return false
	st.items.append("onion"); st.items = game._normalize_burger_stack(st.items)
	st["cooked_onion"] = true
	batch.portions -= 1
	game._after_station_edit(game.STATION_CRAFT)
	game._play_ingredient_touch_sfx("onion")
	game._mp_broadcast_station(game.STATION_CRAFT)
	if batch.portions <= 0: batches.erase(batch); batch.queue_free()
	else: batch.rebuild()
	return true

func _pose_spatula(basis: Basis, tip: Vector3) -> void:
	if not is_instance_valid(game.hand_spatula_root): return
	if blade_bounds.size == Vector3.ZERO: blade_bounds = game._shop_preview_bounds(game.hand_spatula_root)
	var origin: Vector3 = tip-basis*game.HAND_SPATULA_TIP_OFFSET
	var projected := Transform3D(basis,origin)*blade_bounds
	origin.y += maxf(0,game.GRILL_SURFACE_Y+.008-projected.position.y)
	game.hand_spatula_root.global_transform = Transform3D(basis,origin)

func apply_spatula(delta: float) -> void:
	if not drag.is_empty() and is_instance_valid(drag.batch):
		var direction: Vector2 = drag.get("direction",Vector2.ZERO)
		var tip: Vector3 = drag.batch.global_position + Vector3(0,.035,0)
		tip -= (Basis(Vector3.UP,blade_yaw)*Vector3.FORWARD)*.07
		_pose_spatula(Basis(Vector3.UP,blade_yaw),tip)
		return
	if chop_left > 0:
		chop_left = maxf(0,chop_left-delta)
		var t := 1.0-chop_left/.32
		var edge := sin(PI*t)
		var basis := Basis.from_euler(Vector3(0,blade_yaw,deg_to_rad(90*minf(1,edge*2))))
		_pose_spatula(basis,chop_target+Vector3(0,.035+absf(t-.45)*.22,0))
		return
	# A held spatula can sweep into a pile from empty steel, without grabbing it first.
	if game.spatula_grill_hold and game.spatula_patty == null and game.dragging_patty == null:
		var hit: Vector3 = game._grill_plane_from_screen(get_viewport().get_mouse_position())
		if hit != Vector3.ZERO:
			var point := Vector2(hit.x,hit.z)
			if sweep_previous.is_finite() and sweep_previous.distance_to(point) > .0001:
				var direction := (point-sweep_previous).normalized()
				for batch in batches:
					if not is_instance_valid(batch): continue
					var center := Vector2(batch.global_position.x,batch.global_position.z)
					if center.distance_to(Geometry2D.get_closest_point_to_segment(center,sweep_previous,point)) < .24:
						_move_batch(batch,center+direction*minf(.12,sweep_previous.distance_to(point)*1.2))
						batch.slide_velocity = direction*.30
						sweep_contact = .18
			sweep_previous = point
			if sweep_contact > 0: _pose_spatula(Basis(Vector3.UP,blade_yaw),hit+Vector3(0,.035,0))
	else: sweep_previous = Vector2.INF
	sweep_contact = maxf(0,sweep_contact-delta)

func _move_batch(batch: Node3D, destination: Vector2) -> void:
	var bounds: Rect2 = game._patty_place_bounds_with_hold().grow(-.10)
	var target := Vector2(clampf(destination.x,bounds.position.x,bounds.end.x),clampf(destination.y,bounds.position.y,bounds.end.y))
	var previous := Vector2(batch.global_position.x,batch.global_position.z)
	batch.global_position = Vector3(target.x,game.GRILL_SURFACE_Y+.008,target.y)
	batch.jostle(target-previous)

func push_from_burger(from: Vector2, to: Vector2) -> void:
	if from.distance_to(to) < .00001: return
	for batch in batches:
		if not is_instance_valid(batch): continue
		var center := Vector2(batch.global_position.x,batch.global_position.z)
		var nearest := Geometry2D.get_closest_point_to_segment(center,from,to)
		if center.distance_to(nearest) >= .29: continue
		var direction := (to-from).normalized()
		var away := center-to
		if away.length() > .001 and away.dot(direction) > -.1: direction = away.normalized()
		_move_batch(batch,to+direction*.31)
		batch.slide_velocity = direction*.3

func _process(delta: float) -> void:
	if not game.playing or game.options_menu_open or game.shift_paused or game._boss_speech_active():
		if not drag.is_empty() and is_instance_valid(drag.batch): drag.batch.pressed = false
		drag.clear(); return
	if not drag.is_empty() and is_instance_valid(drag.batch) and drag.moved:
		var batch = drag.batch
		var before := Vector2(batch.global_position.x,batch.global_position.z)
		var destination: Vector2 = before.lerp(drag.target,1-exp(-38*delta))
		_move_batch(batch,destination)
		var movement := Vector2(batch.global_position.x,batch.global_position.z)-before
		drag.direction = movement
		batch.slide_velocity = (movement/maxf(delta,.001)*.30).limit_length(.45)
		# Soft piles nudge each other instead of acting like rigid blocked objects.
		for other in batches:
			if not is_instance_valid(other) or other == batch: continue
			var center := Vector2(other.global_position.x,other.global_position.z)
			var away := center-destination
			var separation := away.length()
			if separation<.18:
				if separation<.001: away=Vector2.RIGHT
				_move_batch(other,center+away.normalized()*(.18-separation)*.65)
				other.slide_velocity = batch.slide_velocity*.5
	for batch in batches:
		if not is_instance_valid(batch) or batch.pressed: continue
		if batch.slide_velocity.length() < .002: continue
		var pos := Vector2(batch.global_position.x,batch.global_position.z)
		var next: Vector2 = pos+batch.slide_velocity*delta
		_move_batch(batch,next)
		batch.slide_velocity = batch.slide_velocity.move_toward(Vector2.ZERO,delta*.85)
