extends Node
## Both peers run this presentation from the approved relocation event.
var game: Node
var shutter: Node3D
var blocker: ColorRect
var scenery: Array[Dictionary] = []
var garage: AudioStreamPlayer

func setup(owner_game: Node) -> void:
	game = owner_game
	blocker = ColorRect.new()
	blocker.name = "TravelInputBlocker"
	blocker.color = Color.TRANSPARENT
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blocker.z_index = 1000
	game.get_node("UI/Root").add_child(blocker)
	shutter = Node3D.new()
	shutter.name = "TravelRollerShutter"
	game.world.add_child(shutter)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("353b43")
	material.metallic = .65
	material.roughness = .55
	for i in 22:
		var slat := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(6.8, .103, .045)
		slat.mesh = box
		slat.material_override = material
		shutter.add_child(slat)
		slat.position = Vector3(0, -float(i) * .105, 0)
	shutter.position = Vector3(0, 2.92, 1.60)
	shutter.scale.y = .001
	for node in [game.street_matte, game.street_matte_body, game.park_bird_house]:
		if is_instance_valid(node): scenery.append({"node":node,"home":node.position})
	garage = AudioStreamPlayer.new()
	garage.stream = preload("res://sounds/garage_shutter_open.ogg")
	garage.bus = "SFX"
	garage.volume_db = -9.0
	add_child(garage)

func sample_departure(progress: float) -> void:
	shutter.scale.y = maxf(.001, smoothstep(0.0, 1.0, progress))
	# Scenery slips left while the truck accelerates to the right, before shut.
	var distance := .65 * pow(clampf((progress - .32) / .68, 0.0, 1.0), 2.0)
	var right: Vector3 = game.camera.global_basis.x if is_instance_valid(game.camera) else Vector3.RIGHT
	for entry in scenery:
		if is_instance_valid(entry.node): entry.node.position = entry.home - right * distance

func close_and_depart() -> void:
	garage.play()
	var tw := create_tween()
	tw.tween_method(sample_departure, 0.0, .32, .45)
	tw.tween_callback(_screech)
	tw.tween_method(sample_departure, .32, 1.0, .95)
	await tw.finished
	garage.stop()
	for entry in scenery:
		if is_instance_valid(entry.node): entry.node.position = entry.home
	scenery.clear()

func _screech() -> void:
	var player := AudioStreamPlayer.new()
	player.stream = preload("res://sounds/vehicles/mail_truck_tire_screech.mp3")
	player.bus = "SFX"
	player.volume_db = -5.0 + linear_to_db(.75)
	add_child(player)
	player.play()
	var fade := create_tween()
	fade.tween_interval(maxf(.01, player.stream.get_length() - .63))
	fade.tween_property(player, "volume_db", -60.0, .03)
	fade.tween_callback(player.queue_free)

func open_at_destination() -> void:
	garage.play()
	var tw := create_tween()
	tw.tween_property(shutter, "scale:y", .001, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	garage.stop()

func _exit_tree() -> void:
	for entry in scenery:
		if is_instance_valid(entry.node): entry.node.position = entry.home
	if is_instance_valid(shutter): shutter.queue_free()
	if is_instance_valid(blocker): blocker.queue_free()
