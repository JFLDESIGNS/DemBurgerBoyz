extends "res://scripts/customer.gd"
## Existing ticket/food protocol with the boss model instead of a walking customer.
var boss: Node
var player: AnimationPlayer
var rig: Skeleton3D

func _ready() -> void:
	is_challenge_guest = true
	patience = 99999.0
	patience_max = 99999.0
	set_meta("hotdog_boss", true)
	var model = load("res://assets/characters/baron_brat_bg/baron_brat_bg.glb").instantiate()
	add_child(model)
	# Matte rubber avoids glittering specular/self-shadow noise on thin bent arms.
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var material = mesh.get_active_material(surface)
			if material is StandardMaterial3D and "Liquorice" in material.resource_name:
				var rubber = material.duplicate()
				rubber.roughness = 1.0; rubber.metallic_specular = 0.0
				rubber.disable_receive_shadows = true
				mesh.set_surface_override_material(surface,rubber)

	player = model.find_child("AnimationPlayer", true, false)
	rig = model.find_child("Skeleton3D", true, false)
	if rig == null:
		var rigs = model.find_children("*", "Skeleton3D", true, false)
		if not rigs.is_empty(): rig = rigs[0]
	rotation.y = PI

func _process(_delta: float) -> void: pass
func _physics_process(_delta: float) -> void: pass
func start_order_clock(_reset_elapsed: bool = true) -> void: pass
func stop_order_clock() -> void: pass
func apply_host_snapshot(_pos: Vector3, _yaw: float, _snap: bool = false) -> void: pass
func begin_catch_burger(_authored_grab: bool = false) -> void:
	if is_instance_valid(boss): boss.begin_eating()
func start_eating_burger() -> void:
	if is_instance_valid(boss): boss.eating_sound()
func chomp_burger() -> void:
	if is_instance_valid(boss): boss.eating_sound()
func finish_catch_burger() -> void: pass
func burger_animation_duration(_eating: bool) -> float: return 0.65
func mouth_global() -> Vector3:
	if is_instance_valid(rig):
		var index = rig.find_bone("Mouth")
		if index >= 0:
			return rig.to_global(rig.get_bone_global_pose(index).origin + Vector3(0, -.10, .58))
	return to_global(Vector3(0, 2.22, .58))
func burger_grip_global() -> Vector3: return mouth_global()
func burger_grip_edges() -> Array[Vector3]:
	return [mouth_global() + Vector3(-.12,0,0), mouth_global() + Vector3(.12,0,0)]
func side_food_mouth_global() -> Vector3: return mouth_global()

var exit_start_pose: Array[Transform3D] = []

func begin_ground_exit() -> void:
	exit_start_pose.clear()
	for i in rig.get_bone_count(): exit_start_pose.append(rig.get_bone_pose(i))
	player.speed_scale = 1.0
	player.play("ground_breakout",0.0)
	player.pause()
	update_ground_exit(0.0)
	# Low, rolling dust hides the seam as the fractured pavement closes.
	for i in 14:
		var puff = MeshInstance3D.new()
		var sphere = SphereMesh.new(); sphere.radius = .22; sphere.height = .30; sphere.radial_segments = 10; sphere.rings = 5
		puff.mesh = sphere
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(.63,.56,.43,.0)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.roughness = 1.0
		puff.material_override = material
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(puff)
		var direction = Vector3(cos(i*TAU/14),0,sin(i*TAU/14))
		puff.position = direction * .9 + Vector3(0,.12,0)
		var tween = puff.create_tween().set_parallel(true)
		tween.tween_property(puff,"position",direction*1.65+Vector3(0,.25,0),1.8)
		tween.tween_property(puff,"scale",Vector3(2.1,.75,2.1),1.8)
		tween.tween_property(material,"albedo_color:a",.45,.25)
		tween.chain().tween_property(material,"albedo_color:a",0.0,.3)
		tween.chain().tween_callback(puff.queue_free)

func update_ground_exit(progress: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(rig): return
	var animation = player.get_animation("ground_breakout")
	player.seek(animation.length * lerpf(.65,.12,smoothstep(0,1,progress)),true)
	# Blend out of the actual slump/slam pose instead of snapping upright first.
	var blend = smoothstep(0,.32,progress)
	if exit_start_pose.size() == rig.get_bone_count() and blend < 1.0:
		for i in rig.get_bone_count():
			rig.set_bone_pose(i,exit_start_pose[i].interpolate_with(rig.get_bone_pose(i),blend))
