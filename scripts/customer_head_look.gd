## Runs after the authored skeleton animation; only the head receives a look offset.
extends SkeletonModifier3D
var target_world := Vector3.ZERO
var look_weight := 0.0
var dance_weight := 0.0
var dance_phase := 0.0
func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null: return
	# Small twist and shoulder rock layered on the idle: feet/root never travel.
	if dance_weight > 0.001:
		for name in ["Hips","Chest"]:
			var bone := skeleton.find_bone(name)
			if bone < 0: continue
			var base := skeleton.get_bone_pose_rotation(bone)
			var amount := 0.06 if name == "Hips" else -0.10
			var twist := Quaternion(Vector3.UP,sin(dance_phase)*amount*dance_weight)
			var rock := Quaternion(Vector3.FORWARD,sin(dance_phase*0.5)*0.035*dance_weight)
			skeleton.set_bone_pose_rotation(bone,base*twist*rock)
	if look_weight < 0.001: return
	var head := skeleton.find_bone("Head")
	if head < 0: return
	var pose := skeleton.get_bone_global_pose(head)
	var direction := pose.basis.orthonormalized().inverse() * (skeleton.to_local(target_world) - pose.origin)
	if direction.z <= 0.0: return
	var yaw := clampf(atan2(direction.x,direction.z),-0.44,0.44) * look_weight
	var pitch := clampf(atan2(direction.y,Vector2(direction.x,direction.z).length()),-0.22,0.22) * look_weight
	pose.basis = pose.basis * Basis(Vector3.UP,yaw) * Basis(Vector3.RIGHT,-pitch)
	skeleton.set_bone_global_pose(head,pose)
