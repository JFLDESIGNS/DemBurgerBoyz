extends Node3D
## In-world delivery cut sequence. Stock is still credited by the existing landing flow.
const TRUCK = preload("res://assets/mail_truck/mail_truck.glb")
const CAT = preload("res://assets/cat/shipping_cat.glb")
var game: Node
var truck: Node3D
var body: Node3D
var courier: Node3D
var cat_visual: Node3D
var animation: AnimationPlayer
var parcel: Node3D
var wheels: Array[Node3D] = []
var orders: Array = []
var phase := "waiting"
var elapsed := 0.0
var clock := 0.0
var ground := 0.0
var stop := Vector3.ZERO
var seat := Vector3.ZERO
var doorstep := Vector3.ZERO
var handoff := Vector3(1.38, 0.741, 1.76)
var old_cat_visible := false
var old_cat_process := true
var body_rest := Vector3.ZERO
var finished := false
var drive_audio: AudioStreamPlayer3D
var horn_audio: AudioStreamPlayer3D
var fill_light: OmniLight3D

func _ready() -> void:
	name = "MailDeliveryCutscene"
	truck = TRUCK.instantiate()
	add_child(truck)
	truck.scale = Vector3.ONE * 0.78
	truck.rotation.y = PI * 0.5
	body = truck.find_child("TruckBody", true, false)
	if body: body_rest = body.position
	for wheel_name in ["Wheel_Front_L", "Wheel_Front_R", "Wheel_Rear_L", "Wheel_Rear_R"]:
		var wheel = truck.find_child(wheel_name, true, false)
		if wheel: wheels.append(wheel)
	ground = game._street_car_wheel_y()
	stop = Vector3(-0.45, ground, maxf(5.4, game._street_car_z() - 0.8))
	truck.position = stop + Vector3(-16, 0, 0)
	courier = Node3D.new()
	add_child(courier)
	cat_visual = CAT.instantiate()
	courier.add_child(cat_visual)
	preload("res://scripts/cat_appearance.gd").apply_fur(cat_visual)
	for eye_name in ["Cat_Eye_L", "Cat_Eye_R"]:
		var eye = cat_visual.find_child(eye_name, true, false)
		if eye is MeshInstance3D:
			var eye_material := ShaderMaterial.new()
			eye_material.shader = preload("res://shaders/cat_eyes.gdshader")
			eye.material_override = eye_material
	cat_visual.scale = Vector3.ONE * 0.90
	animation = cat_visual.find_child("AnimationPlayer", true, false)
	parcel = cat_visual.find_child("Delivery_Box_Rig", true, false)
	for clip in ["01_Idle", "02_Mail_Walk"]:
		if animation and animation.has_animation(clip): animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	if is_instance_valid(game.window_cat):
		old_cat_visible = game.window_cat.visible
		old_cat_process = game.window_cat.is_processing()
		game.window_cat.set_process(false)
		game.window_cat.hide()
	truck.hide()
	courier.hide()
	drive_audio = AudioStreamPlayer3D.new()
	drive_audio.stream = preload("res://sounds/vehicles/car_pass_by_left_to_right.ogg")
	drive_audio.volume_db = -9.0
	drive_audio.max_distance = 35.0
	truck.add_child(drive_audio)
	horn_audio = AudioStreamPlayer3D.new()
	horn_audio.stream = preload("res://sounds/vehicles/car_horn_double_beep.wav")
	horn_audio.volume_db = -13.0
	horn_audio.max_distance = 35.0
	truck.add_child(horn_audio)
	fill_light = OmniLight3D.new()
	fill_light.light_color = Color(1.0, 0.94, 0.83)
	fill_light.light_energy = 2.0
	fill_light.omni_range = 8.0
	fill_light.shadow_enabled = false
	fill_light.light_cull_mask = 1 << 18
	add_child(fill_light)
	for visual_root in [truck, courier]:
		for mesh in visual_root.find_children("*", "GeometryInstance3D", true, false):
			mesh.layers |= 1 << 18
	set_process(false) # Advanced by the game so pause and shift teardown stay synchronized.

func enqueue(id: String, pack: int, kind: String) -> void:
	orders.append([id, pack, kind])

func clip(name_: String) -> void:
	if animation and animation.has_animation(name_) and animation.current_animation != name_:
		animation.play(name_, 0.12)

func set_phase(value: String) -> void:
	phase = value
	elapsed = 0.0
	if value in ["arrive", "depart"] and is_instance_valid(drive_audio): drive_audio.play()
	if value == "hop_out":
		drive_audio.stop()
		horn_audio.play()

func delivery_origin_global() -> Vector3:
	return parcel.to_global(Vector3(0, 0.13, 0)) if parcel else courier.global_position + Vector3(0, 0.6, 0)

func advance(delta: float) -> void:
	if finished: return
	clock += delta
	elapsed += delta
	if phase == "waiting":
		# Let any car already on the road leave naturally before entering its lane.
		if game.street_car_active: return
		truck.show(); courier.show(); set_phase("arrive")
	fill_light.global_position = truck.global_position + Vector3(0, 3.3, -2.2)
	fill_light.visible = truck.visible
	var driving := phase in ["arrive", "depart"]
	if body:
		body.position = body_rest + Vector3(0, sin(clock * 11.0) * (0.023 if driving else 0.005), 0)
		body.rotation.z = sin(clock * 7.0) * (0.013 if driving else 0.003)
	for wheel in wheels:
		if driving: wheel.rotate_x(delta * 10.0)
	if parcel: parcel.visible = phase in ["hop_out", "walk", "deliver"]
	match phase:
		"arrive":
			var u := clampf(elapsed / 3.4, 0, 1)
			truck.position = (stop + Vector3(-16, 0, 0)).lerp(stop, 1.0 - pow(1.0-u, 2.0))
			seat = truck.to_global(Vector3(0.59, 1.13, 0.56))
			courier.global_position = seat
			courier.rotation.y = PI * 0.5
			clip("01_Idle")
			if body: body.rotation.x = sin(u * PI) * 0.025
			if u >= 1:
				doorstep = truck.to_global(Vector3(1.95, 0.05, 0.50))
				set_phase("hop_out")
		"hop_out":
			var u := clampf(elapsed / 0.85, 0, 1)
			cat_visual.scale = Vector3.ONE * lerpf(0.90, 1.25, u)
			courier.global_position = seat.lerp(doorstep, u) + Vector3(0, sin(u*PI)*0.48, 0)
			courier.rotation.y = PI
			clip("04_Happy_Hop")
			if body: body.position.y += sin(elapsed * 16) * exp(-elapsed*3) * 0.055
			if u >= 1: set_phase("walk")
		"walk", "return":
			cat_visual.scale = Vector3.ONE * 1.25
			var u := clampf(elapsed / 2.6, 0, 1)
			var from := doorstep if phase == "walk" else handoff
			var to := handoff if phase == "walk" else doorstep
			courier.global_position = from.lerp(to, smoothstep(0, 1, u)) + Vector3(0, absf(sin(elapsed*12))*0.045, 0)
			courier.rotation.y = atan2(to.x-from.x, to.z-from.z)
			courier.rotation.z = sin(elapsed*12) * 0.075
			clip("02_Mail_Walk")
			if u >= 1:
				courier.rotation.z = 0
				if phase == "walk":
					set_phase("deliver")
					for order in orders: game._throw_cat_supply_delivery(order[0], order[1], order[2])
					orders.clear()
				else: set_phase("hop_in")
		"deliver":
			courier.rotation.y = PI
			clip("03_Box_Delivery")
			if not orders.is_empty():
				for order in orders: game._throw_cat_supply_delivery(order[0], order[1], order[2])
				orders.clear(); elapsed = 0
			if elapsed >= 4.8 and game.supply_delivery_fx.is_empty(): set_phase("return")
		"hop_in":
			var u := clampf(elapsed / 0.85, 0, 1)
			cat_visual.scale = Vector3.ONE * lerpf(1.25, 0.90, u)
			courier.global_position = doorstep.lerp(seat, u) + Vector3(0, sin(u*PI)*0.45, 0)
			clip("04_Happy_Hop")
			if u >= 1: set_phase("depart")
		"depart":
			var u := clampf(elapsed / 3.0, 0, 1)
			truck.position = stop + Vector3(17*u*u, 0, 0)
			courier.global_position = truck.to_global(Vector3(0.59,1.13,0.56))
			courier.rotation.y = PI*0.5
			clip("01_Idle")
			if u >= 1:
				if orders.is_empty():
					finished = true; hide(); restore_cat()
				else:
					truck.hide();courier.hide();set_phase("waiting")

func restore_cat() -> void:
	if is_instance_valid(game) and is_instance_valid(game.window_cat):
		game.window_cat.set_process(old_cat_process)
		game.window_cat.visible = old_cat_visible

func _exit_tree() -> void:
	restore_cat()
