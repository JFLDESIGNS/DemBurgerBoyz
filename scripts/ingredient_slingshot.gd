extends Node2D

var game: Node
var ingredient := ""
var origin := Vector2.ZERO
var pointer := Vector2.ZERO
var pulling := false
var stretch_player: AudioStreamPlayer

static func aim_point(start: Vector2, release: Vector2, viewport_height: float) -> Vector2:
	return start + (start-release) * clampf(viewport_height/145.0,3.0,8.0)

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
					game.mp_ingredient_slingshot.rpc(id,source/get_viewport_rect().size,target/get_viewport_rect().size)
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
				stretch_player = game.game_audio.start_slingshot_stretch()
		if pulling:
			if is_instance_valid(stretch_player): stretch_player.pitch_scale = lerpf(.8,1.8,clampf(pull.length()/180,0,1))
			queue_redraw(); return true
	return false

func cancel() -> void:
	if pulling:
		game._strip_swipe_active = false
		game._strip_swipe_added.clear()
		game._clear_strip_hold_tracking()
		game._clear_pending_ingredient_throw_state(ingredient)
	if is_instance_valid(stretch_player): stretch_player.queue_free()
	stretch_player = null
	ingredient = ""; pulling = false; queue_redraw()

func _process(_delta: float) -> void:
	if pulling and (not game.playing or game.options_menu_open or game.shift_paused or game._boss_speech_active()): cancel()

func _draw() -> void:
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

func launch(id: String, source: Vector2, target: Vector2) -> void:
	if not is_instance_valid(game.camera) or not is_instance_valid(game.world): return
	if game.game_audio: game.game_audio.play_slingshot_release()
	var start: Vector3 = game.camera.project_position(game._gui_to_camera_screen(source),1.15)
	var depth := 3.0
	var found := false
	for customer in game.customers:
		if not is_instance_valid(customer) or not customer is Node3D or not customer.is_visible_in_tree(): continue
		var head: Vector3 = game._customer_head_world(customer)
		var d: float = -game.camera.to_local(head).z
		if d>1.2 and (not found or d<depth): depth=d; found=true
	var end: Vector3 = game.camera.project_position(game._gui_to_camera_screen(target),depth)
	var flyer: MeshInstance3D = game._make_thrown_ingredient_card(id,game.FoodSpritesScript.get_tex(id))
	game.world.add_child(flyer); flyer.global_position=start
	var state := {"previous":start,"hit":false}
	var tween := create_tween()
	tween.tween_method(func(t: float):
		if not is_instance_valid(flyer) or state.hit: return
		var pos := start.lerp(end,t)
		# A quick shallow arc still lands exactly on the aimed point.
		pos.y += sin(PI*t)*.10
		for customer in game.customers:
			if not is_instance_valid(customer) or not customer is Node3D or not customer.is_visible_in_tree(): continue
			var head: Vector3 = game._customer_head_world(customer)
			for spot in [head,head+Vector3(0,-.28,0)]:
				var nearest := Geometry3D.get_closest_point_to_segment(spot,state.previous,pos)
				if nearest.distance_to(spot)<.23:
					state.hit=true
					game._apply_customer_ingredient_hit(customer,id,nearest,"face" if spot==head else "body")
					tween.kill()
					flyer.queue_free(); return
		flyer.global_position=pos
		flyer.look_at(game.camera.global_position,Vector3.UP)
		flyer.rotate_object_local(Vector3.UP,PI)
		flyer.rotate_object_local(Vector3.FORWARD,t*TAU)
		state.previous=pos,
		0.0,1.0,clampf(.55-source.distance_to(target)/4000,.25,.5))
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
