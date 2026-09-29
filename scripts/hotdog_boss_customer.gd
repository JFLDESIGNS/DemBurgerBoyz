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
func start_eating_burger() -> void: pass
func chomp_burger() -> void: pass
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
