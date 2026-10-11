extends Node2D

var game: Node
var ingredient := ""
var origin := Vector2.ZERO
var pointer := Vector2.ZERO
var pulling := false
var stretch_player: AudioStreamPlayer
var remote_pulls: Dictionary = {}
var pull_send_left := 0.0

func send_pull(active: bool) -> void:
	if game.mp_enabled and NetManager.is_online():
		game.mp_ingredient_pull.rpc(ingredient,origin/get_viewport_rect().size,pointer/get_viewport_rect().size,active)

func remote_pull(peer: int, id: String, start: Vector2, at: Vector2, active: bool) -> void:
	if not active:
		if remote_pulls.has(peer):
			var sound = remote_pulls[peer].sound
			if is_instance_valid(sound): sound.queue_free()
			remote_pulls.erase(peer)
	else:
		if not remote_pulls.has(peer):
			remote_pulls[peer] = {"sound": game.game_audio.start_slingshot_stretch(self) if game.game_audio else null}
		remote_pulls[peer].merge({"id":id,"start":start,"at":at,"expires":Time.get_ticks_msec()+1500},true)
	queue_redraw()

static func aim_point(start: Vector2, release: Vector2, viewport_height: float) -> Vector2:
	return start + (start-release) * clampf(viewport_height/120.0,3.5,9.5)

func handle_input(event: InputEvent) -> bool:
	if not game.playing or game.options_menu_open or game.shift_paused or game._boss_speech_active():
		cancel(); return false
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and pulling:
		cancel(); return true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			ingredient = game._strip_ingredient_at(event.position)
			origin = event.position; pointer = origin
			return false
		if pulling:
			var id := ingredient
			var source := pointer
			var target := aim_point(origin,pointer,get_viewport_rect().size.y)
			var fire := pointer.distance_to(origin) >= 25
			cancel()
			game._strip_swipe_active = false
			game._strip_swipe_added.clear()
			game._clear_strip_hold_tracking()
			game._clear_pending_ingredient_throw_state(id)
			if fire and game._mp_can_spend_ingredient(id):
				if game.mp_enabled:
					game.mp_ingredient_slingshot.rpc_id(1,id,source/get_viewport_rect().size,target/get_viewport_rect().size)
				elif game._spend_ingredient(id): launch(id,source,target)
			return true
		ingredient = ""
	if event is InputEventMouseMotion and ingredient != "":
		pointer = event.position
		var pull := pointer-origin
		# Upward drags and horizontal ingredient-paint swipes keep their existing path.
		if not pulling and (pull.y < -25 or bool(game._strip_swipe_added.get("_moved",false))):
			ingredient = ""; return false
		if not pulling and pull.y > 20 and pull.length() > 25 and pull.y > absf(pull.x)*.3:
			pulling = true
			game._strip_swipe_active = false
			game._clear_strip_hold_tracking()
			game._strip_did_drag = true
			game._strip_gesture_added = true
			if get_viewport().has_method("gui_cancel_drag"): get_viewport().call("gui_cancel_drag")
			if game.game_audio:
				stretch_player = game.game_audio.start_slingshot_stretch(self)
			send_pull(true)
		if pulling:
			queue_redraw(); return true
	return false

func cancel() -> void:
	if pulling:
		send_pull(false)
		game._strip_swipe_active = false
		game._strip_swipe_added.clear()
		game._clear_strip_hold_tracking()
		game._clear_pending_ingredient_throw_state(ingredient)
	if is_instance_valid(stretch_player):
		stretch_player.stop()
		stretch_player.queue_free()
	stretch_player = null
	ingredient = ""; pulling = false; queue_redraw()

func _process(_delta: float) -> void:
	if pulling and (not game.playing or game.options_menu_open or game.shift_paused or game._boss_speech_active()): cancel()
	if pulling and game.game_audio:
		if not is_instance_valid(stretch_player): stretch_player = game.game_audio.start_slingshot_stretch(self)
		elif not stretch_player.playing: stretch_player.play()
	pull_send_left -= _delta
	if pulling and pull_send_left <= 0.0:
		pull_send_left = 0.10; send_pull(true)
	for peer in remote_pulls.keys():
		if not game.playing or Time.get_ticks_msec() > int(remote_pulls[peer].expires): remote_pull(peer,"",Vector2.ZERO,Vector2.ZERO,false)

func _draw() -> void:
	for pull in remote_pulls.values():
		var a: Vector2 = pull.start * get_viewport_rect().size
		var b: Vector2 = pull.at * get_viewport_rect().size
		draw_line(a+Vector2(-15,0),b,Color("D9AA64"),3,true)
		draw_line(a+Vector2(15,0),b,Color("D9AA64"),3,true)
		var texture: Texture2D = game.FoodSpritesScript.get_tex(pull.id)
		if texture: draw_texture_rect(texture,Rect2(b-Vector2(32,35),Vector2(64,70)),false)
	if not pulling: return
	var aim := aim_point(origin,pointer,get_viewport_rect().size.y)
	var power := clampf(pointer.distance_to(origin)/180,0,1)
	draw_line(origin+Vector2(-15,0),pointer,Color("D9AA64"),3,true)
	draw_line(origin+Vector2(15,0),pointer,Color("D9AA64"),3,true)
	for i in range(1,14):
		draw_circle(origin.lerp(aim,float(i)/14),2,Color(1,.88,.5,.65))
	draw_arc(aim,12,0,TAU,32,Color("FFE49A"),2,true)
	var tex: Texture2D = game.FoodSpritesScript.get_tex(ingredient)
	if tex:
		var size := Vector2(75*(1-power*.25),55*(1+power*.45))
		draw_texture_rect(tex,Rect2(pointer-size*.5,size),false)

# Screen-space assistance also covers pulls that stop a little below a face.
func catch_target(target: Vector2) -> Node3D:
	var best: Node3D = null
	var best_score := 1.0
	var screen: Vector2 = game._gui_to_camera_screen(target)
	var height: float = game.camera.get_viewport().get_visible_rect().size.y
	var targets: Array = game.customers.duplicate()
	if is_instance_valid(game.window_cat): targets.append(game.window_cat)
	for subject in targets:
		if not is_instance_valid(subject) or not subject is Node3D or not subject.is_visible_in_tree(): continue
		var head: Vector3 = subject.head_global() if subject == game.window_cat else game._customer_head_world(subject)
		if game.camera.is_position_behind(head): continue
		var offset: Vector2 = screen - game.camera.unproject_position(head)
		var score := Vector2(offset.x / (height * .13), offset.y / (height * .24)).length()
		if score < best_score:
			best_score = score
			best = subject
	return best

func launch(id: String, source: Vector2, target: Vector2) -> void:
	if not is_instance_valid(game.camera) or not is_instance_valid(game.world): return
	if game.game_audio: game.game_audio.play_slingshot_release()
	var start: Vector3 = game.camera.project_position(game._gui_to_camera_screen(source),1.15)
	var depth := 3.0
	var aim_screen: Vector2 = game._gui_to_camera_screen(target)
	var best_distance := INF
	var targets: Array = game.customers.duplicate()
	if is_instance_valid(game.window_cat) and game.window_cat.is_visible_in_tree(): targets.append(game.window_cat)
	for subject in targets:
		if not is_instance_valid(subject) or not subject is Node3D or not subject.is_visible_in_tree(): continue
		var head: Vector3 = subject.head_global() if subject == game.window_cat else game._customer_head_world(subject)
		if game.camera.is_position_behind(head): continue
		var d: float = -game.camera.to_local(head).z
		var screen_distance: float = game.camera.unproject_position(head).distance_to(aim_screen)
		if d > 1.2 and screen_distance < best_distance:
			depth = d + .12
			best_distance = screen_distance
	var end: Vector3 = game.camera.project_position(game._gui_to_camera_screen(target),depth)
	var assisted := catch_target(target)
	var flyer: MeshInstance3D = game._make_thrown_ingredient_card(id,game.FoodSpritesScript.get_tex(id))
	game.world.add_child(flyer); flyer.global_position=start
	flyer.name = "ReplicatedIngredientFlight"
	flyer.look_at(game.camera.global_position,Vector3.UP)
	var duration := clampf(.55-source.distance_to(target)/4000,.25,.5)
	var whistle: AudioStreamPlayer = game.game_audio.start_ingredient_fall_whistle(duration) if game.game_audio else null
	var whistle_ref: WeakRef = weakref(whistle) if is_instance_valid(whistle) else null
	flyer.tree_exiting.connect(func():
		var sound = whistle_ref.get_ref() if whistle_ref != null else null
		if is_instance_valid(sound): sound.queue_free()
	)
	var state := {"previous":start,"hit":false}
	var tween := create_tween()
	tween.tween_method(func(t: float):
		if not is_instance_valid(flyer) or state.hit: return
		if is_instance_valid(assisted) and assisted.is_visible_in_tree():
			end = assisted.head_global() if assisted == game.window_cat else game._customer_head_world(assisted)
		var pos := start.lerp(end,t)
		# A quick shallow arc still lands exactly on the aimed point.
		pos.y += sin(PI*t)*.10
		var cat = game.window_cat
		if (not game.mp_enabled or NetManager.is_host()) and is_instance_valid(cat) and cat.is_visible_in_tree():
			var cat_head: Vector3 = cat.head_global()
			var cat_nearest := Geometry3D.get_closest_point_to_segment(cat_head, state.previous, pos)
			if cat_nearest.distance_to(cat_head) < .32:
				state.hit = true
				game._apply_cat_ingredient_hit(id, cat_nearest)
				tween.kill()
				flyer.queue_free()
				return
		for customer in game.customers:
			if game.mp_enabled and not NetManager.is_host(): break
			if not is_instance_valid(customer) or not customer is Node3D or not customer.is_visible_in_tree(): continue
			var head: Vector3 = game._customer_head_world(customer)
			for spot in [head,head+Vector3(0,-.28,0)]:
				var nearest := Geometry3D.get_closest_point_to_segment(spot,state.previous,pos)
				if nearest.distance_to(spot)<.31:
					state.hit=true
					game._apply_customer_ingredient_hit(customer,id,nearest,"face" if spot==head else "body")
					tween.kill()
					flyer.queue_free(); return
		flyer.global_position=pos
		flyer.look_at(game.camera.global_position,Vector3.UP)
		flyer.rotate_object_local(Vector3.UP,PI)
		flyer.rotate_object_local(Vector3.FORWARD,t*TAU)
		state.previous=pos,
		0.0,1.0,duration)
	tween.tween_callback(func():
		if is_instance_valid(flyer):
			var fall := flyer.create_tween()
			fall.tween_property(flyer,"position:y",flyer.position.y-1.5,.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			fall.parallel().tween_property(flyer,"scale",Vector3.ZERO,.4)
			fall.tween_callback(flyer.queue_free))

func impact(customer: Node3D, at: Vector3, id: String) -> void:
	if game.game_audio: game.game_audio.play_ingredient_plap()
	if customer.has_method("food_hit_reaction"): customer.food_hit_reaction()
	var color := Color("FFD478")
	if id in ["tomato","ketchup"]: color=Color("FF6A3D")
	elif id in ["lettuce","pickle"]: color=Color("A6DC54")
	for i in 9:
		var bit := MeshInstance3D.new(); var mesh := SphereMesh.new()
		mesh.radius=.012; mesh.height=.024; mesh.radial_segments=8; mesh.rings=4; bit.mesh=mesh
		var mat := StandardMaterial3D.new(); mat.albedo_color=color; mat.roughness=.4
		bit.material_override=mat; game.world.add_child(bit); bit.global_position=at
		var direction := Vector3(randf_range(-1,1),randf_range(.25,1),randf_range(-.7,.7)).normalized()
		var tw := bit.create_tween()
		tw.tween_property(bit,"position",at+direction*randf_range(.15,.32),.19).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(bit,"position:y",at.y-.25,.24)
		tw.parallel().tween_property(bit,"scale",Vector3.ZERO,.24)
		tw.tween_callback(bit.queue_free)

func _exit_tree() -> void:
	for peer in remote_pulls.keys(): remote_pull(peer,"",Vector2.ZERO,Vector2.ZERO,false)
	if is_instance_valid(stretch_player):
		stretch_player.stop()
		stretch_player.queue_free()
	stretch_player = null
