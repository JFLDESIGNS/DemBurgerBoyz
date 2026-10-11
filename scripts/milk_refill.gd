extends Node
const CARTON = preload("res://models/milk_carton_game_ready/Milk_Carton_Stripe.glb")
var pressed := false
var press_at := Vector2.ZERO
var press_time := 0
var beep_left := 0.0
var pour_left := 0.0
var game: Node
var carton: Node3D
var held := false
var refill_origin := Vector3.INF
var pending: Dictionary = {}
var serial := 0
var warn_at := 0
var handled_requests: Dictionary = {}

func reset() -> void:
	pressed = false
	pour_left = 0.0
	beep_left = 0.0
	held = false
	pending.clear()
	handled_requests.clear()

func make_carton() -> Node3D:
	var model := CARTON.instantiate() as Node3D
	model.name = "FreezerMilkCarton"
	model.scale = Vector3.ONE * .48
	return model

func _process(_delta: float) -> void:
	beep_left = maxf(0.0,beep_left-_delta)
	pour_left = maxf(0.0,pour_left-_delta)
	if not game.playing or game.shift_paused or game.options_menu_open: pressed = false; held = false
	if game.playing and not game.shift_paused and game._owns_icecream_machine() and game.icecream_mix_servings <= 0 and beep_left <= 0.0:
		beep_left = 10.0
		if game.game_audio: game.game_audio.play_roomba_done_beep()
	if pressed and (Time.get_ticks_msec()-press_time > 180 or get_viewport().get_mouse_position().distance_to(press_at)>8): held = true
	if held and is_instance_valid(game.icecream_root) and near(get_viewport().get_mouse_position(), game.icecream_root.global_position+Vector3(0,.42,0),85):
		pressed = false; held = false; request("refill")
	if not is_instance_valid(game.patty_fridge_root) or not is_instance_valid(game.icecream_root): return
	if not is_instance_valid(carton):
		carton = make_carton(); game.world.add_child(carton)

	carton.visible = game.playing and pour_left <= 0.0 and (held or game.patty_fridge_open)
	if held and is_instance_valid(game.camera):
		carton.global_position = game.camera.project_position(game._gui_to_camera_screen(get_viewport().get_mouse_position()), .85)
		carton.rotation.y = game.camera.rotation.y
	else:
		var dims: Dictionary = game._patty_fridge_cavity_dims()
		carton.global_position = game.patty_fridge_root.to_global(Vector3(-float(dims.ix)*.34,.015,-float(dims.iz)*.32))
		carton.rotation = game.patty_fridge_root.global_rotation
		carton.visible = carton.visible and (int(game.supply_stock.get("milk",0)) > 0 or game.milk_carton_refills > 0)

func near(screen: Vector2, point: Vector3, radius: float) -> bool:
	return is_instance_valid(game.camera) and not game.camera.is_position_behind(point) and game.camera.unproject_position(point).distance_to(game._gui_to_camera_screen(screen)) < radius

func handle_input(event: InputEvent) -> bool:
	if not game.playing or game.shift_paused or game.options_menu_open or game._phone_expanded: return false
	if pressed and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		pressed = false; held = false; return true
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT: return false
	if not event.pressed and pressed:
		var clicked := not held
		pressed = false; held = false
		if clicked or (is_instance_valid(game.icecream_root) and near(event.position,game.icecream_root.global_position+Vector3(0,.42,0),85)): request("refill")
		return true
	if event.pressed and is_instance_valid(carton) and carton.visible and game.patty_fridge_open and near(event.position,carton.global_position+Vector3(0,.10,0),30):
		pressed = true; press_at = event.position; press_time = Time.get_ticks_msec(); return true
	return false

func request(kind: String, cone: Node3D = null) -> void:
	serial += 1
	if is_instance_valid(cone): cone.set_meta("milk_token",serial)
	pending[serial] = weakref(cone) if is_instance_valid(cone) else null
	var origin: Vector3 = carton.global_position if is_instance_valid(carton) else Vector3.INF
	if game.mp_enabled: action.rpc_id(1,serial,kind,origin)
	else: action(serial,kind,origin)

func reserve_cone(cone: Node3D) -> bool:
	if bool(cone.get_meta("milk_reserved",false)): return true
	if bool(cone.get_meta("milk_pending",false)): return false
	if game.icecream_mix_servings <= 0:
		if Time.get_ticks_msec() > warn_at:
			game._flash("Out of milk! Buy milk on phone, then pour a freezer carton into the machine.",Color("FFDAA0")); warn_at = Time.get_ticks_msec()+2500
		return false
	cone.set_meta("milk_pending",true)
	request("cone",cone)
	return bool(cone.get_meta("milk_reserved",false))

@rpc("any_peer", "call_local", "reliable")
func action(token: int, kind: String, origin: Vector3 = Vector3.INF) -> void:
	if game.mp_enabled and not NetManager.is_host(): return
	var peer := multiplayer.get_remote_sender_id()
	if peer == 0: peer = NetManager.my_id() if game.mp_enabled else 1
	var key := "%d:%d" % [peer,token]
	if handled_requests.has(key): return
	handled_requests[key] = true
	var ok := false
	var message := ""
	if not game.playing or not game._owns_icecream_machine(): message = "Ice cream machine unavailable"
	elif kind == "refill":
		if game.icecream_mix_servings > 0: message = "Use the milk already in the machine first"
		else:
			if game.milk_carton_refills <= 0 and game._try_use_supply("milk"): game.milk_carton_refills = 4
			if game.milk_carton_refills > 0:
				game.milk_carton_refills -= 1
				game.icecream_mix_servings = 6; ok = true; message = "Machine filled! %d refills left in this carton" % game.milk_carton_refills
				if not origin.is_finite() or (is_instance_valid(game.patty_fridge_root) and origin.distance_to(game.patty_fridge_root.global_position) > 4.0): origin = home_position()
				if game.mp_enabled: show_refill.rpc(origin)
				else: show_refill(origin)
			else: message = "Buy milk on the phone first"
	elif kind == "cone":
		if game.icecream_mix_servings > 0:
			game.icecream_mix_servings -= 1; ok = true
		else: message = "Out of milk - refill from freezer"
	if game.mp_enabled:
		game._mp_broadcast_economy()
		if peer != NetManager.my_id(): result.rpc_id(peer,token,ok,message); return
	result(token,ok,message)

@rpc("authority", "call_remote", "reliable")
func result(token: int, ok: bool, message: String) -> void:
	var ref = pending.get(token)
	if ref is WeakRef:
		var cone = ref.get_ref()
		if is_instance_valid(cone) and int(cone.get_meta("milk_token",-1)) == token:
			cone.set_meta("milk_pending",false); cone.set_meta("milk_reserved",ok)
	pending.erase(token)
	if not message.is_empty(): game._flash(message,Color("D6F2FF"))

func home_position() -> Vector3:
	if not is_instance_valid(game.patty_fridge_root): return Vector3.ZERO
	var dims: Dictionary = game._patty_fridge_cavity_dims()
	return game.patty_fridge_root.to_global(Vector3(-float(dims.ix)*.34,.015,-float(dims.iz)*.32))

static func flight_point(start: Vector3, end: Vector3, t: float) -> Vector3:
	var eased := t*t*(3.0-2.0*t)
	return start.lerp(end,eased)+Vector3.UP*sin(t*PI)*.24

@rpc("authority", "call_local", "reliable")
func show_refill(origin: Vector3 = Vector3.INF) -> void:
	if not is_instance_valid(game.icecream_root) or not is_instance_valid(game.patty_fridge_root): return
	pour_left = 2.35
	var flying := make_carton(); flying.name = "MilkRefillFlight"; game.world.add_child(flying)
	var start := origin if origin.is_finite() else home_position()
	var port: Vector3 = game.icecream_root.to_global(Vector3(-.15,.51,.08))
	var end := port + Vector3(-.10,.16,0)
	flying.global_position = start
	var tw := flying.create_tween()
	tw.tween_method(func(t: float):
		flying.global_position = flight_point(start,end,t)
		flying.rotation = Vector3(0,TAU*(t*t*(3.0-2.0*t)),sin(t*PI)*.2)
		flying.scale = Vector3(.48,.48,.48) * Vector3(1.0-sin(t*PI)*.10,1.0+sin(t*PI)*.17,1.0-sin(t*PI)*.10)
	,0.0,1.0,.65)
	tw.tween_property(flying,"rotation:z",-1.9,.18).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		var stream := MeshInstance3D.new(); stream.name = "MilkStream"
		var mesh := CylinderMesh.new(); mesh.top_radius=.006; mesh.bottom_radius=.009; mesh.height=1.0; mesh.radial_segments=10
		stream.mesh=mesh
		var mat := StandardMaterial3D.new(); mat.albedo_color=Color("FFF9E9"); mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		stream.material_override=mat; game.world.add_child(stream)
		var flow := stream.create_tween()
		flow.tween_method(func(t: float):
			if not is_instance_valid(flying): return
			var mouth := flying.to_global(Vector3(.025,.195,0))
			var vector := port-mouth
			stream.global_position=(mouth+port)*.5
			stream.basis=Basis(Quaternion(Vector3.UP,vector.normalized()))
			var width := minf(1.0,minf(t*12.0,(1.0-t)*12.0))*(1.0+.06*sin(t*TAU*3.0))
			stream.scale=Vector3(width,vector.length(),width)
		,0.0,1.0,.75)
		flow.tween_callback(stream.queue_free)
	)
	tw.tween_interval(.75)
	tw.tween_property(flying,"rotation:z",0.0,.17)
	tw.tween_method(func(t: float): flying.global_position=flight_point(end,home_position(),t),0.0,1.0,.50)
	tw.tween_callback(flying.queue_free)
