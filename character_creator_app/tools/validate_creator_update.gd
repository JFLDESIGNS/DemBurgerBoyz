extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_root().add_child(scene)
	for frame in 4:
		await process_frame
	var character := scene.get_node("World/Character") as ModularCharacterBase
	character.eye_pupil_size = 0.31
	await process_frame
	var left_eye := character.find_child("EyeLeftGroup", true, false).get_node("Eye") as MeshInstance3D
	var eye_material := left_eye.material_override as ShaderMaterial
	assert(eye_material != null)
	assert(is_equal_approx(float(eye_material.get_shader_parameter("pupil_size")), 0.31))
	assert(eye_material.shader.code.contains("cull_disabled"))
	assert(eye_material.shader.code.contains("distance_from_eye_axis"))
	character.eye_pupil_size = 0.78
	await process_frame
	left_eye = character.find_child("EyeLeftGroup", true, false).get_node("Eye") as MeshInstance3D
	eye_material = left_eye.material_override as ShaderMaterial
	assert(is_equal_approx(float(eye_material.get_shader_parameter("pupil_size")), 0.78))
	character.eye_pupil_size = 0.55
	for style in range(1, ModularCharacterBase.TopStyle.size()):
		character.top_style = style as ModularCharacterBase.TopStyle
		await process_frame
	for style in range(1, ModularCharacterBase.BottomStyle.size()):
		character.bottom_style = style as ModularCharacterBase.BottomStyle
		await process_frame
	for style in range(1, ModularCharacterBase.GlassesStyle.size()):
		character.glasses_style = style as ModularCharacterBase.GlassesStyle
		await process_frame
	for style in range(1, ModularCharacterBase.MakeupStyle.size()):
		character.makeup_style = style as ModularCharacterBase.MakeupStyle
		await process_frame
	for style in range(1, ModularCharacterBase.JewelryStyle.size()):
		character.jewelry_style = style as ModularCharacterBase.JewelryStyle
		await process_frame
	character.hat_style = ModularCharacterBase.HatStyle.LOWPOLY_CAP
	character.hat_rotation = Vector3(12.0, 25.0, -8.0)
	character.cheek_style = ModularCharacterBase.CheekStyle.ROSY_RADIAL
	character.cheek_depth = -0.32
	character.top_style = ModularCharacterBase.TopStyle.SEAFOAM_RINGER
	character.shirt_graphic = ModularCharacterBase.ShirtGraphic.HEART
	character.shirt_graphic_depth = -0.25
	character.reset_pose_controls()
	await process_frame
	var skeleton := character.get_active_skeleton()
	var rig := character.get_node("InteractiveControlRig") as Node3D
	for control_name in ["LeftAnkleTarget", "RightAnkleTarget", "LeftToesTarget", "RightToesTarget", "LeftHipTarget", "RightHipTarget"]:
		assert(rig.has_node(control_name))
	var hand_target := rig.get_node("LeftHandTarget") as Node3D
	var hand_handle := hand_target.get_node("DragHandle") as MeshInstance3D
	var hand_material := hand_handle.material_override as StandardMaterial3D
	assert(hand_material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED)
	assert(not hand_material.no_depth_test)
	assert(hand_target.global_transform.basis.get_scale().distance_to(Vector3.ONE) < 0.01)
	var hand_index := skeleton.find_bone("LeftHand")
	var baseline := skeleton.global_transform * skeleton.get_bone_global_pose(hand_index).origin
	character.set_pose_control("left_arm_raise", 55.0)
	await process_frame
	var raised := skeleton.global_transform * skeleton.get_bone_global_pose(hand_index).origin
	var elbow_target := rig.get_node("LeftElbowTarget") as Node3D
	var elbow_index := skeleton.find_bone("LeftForeArm")
	var elbow_position := skeleton.global_transform * skeleton.get_bone_global_pose(elbow_index).origin
	assert(elbow_target.global_position.distance_to(elbow_position) < 0.001)
	character.reset_pose_controls()
	character.set_pose_control("left_arm_forward", 35.0)
	await process_frame
	var forward := skeleton.global_transform * skeleton.get_bone_global_pose(hand_index).origin
	var raise_delta := raised - baseline
	var forward_delta := forward - baseline
	print("RIG_DELTAS raise=", raise_delta, " forward=", forward_delta)
	assert(absf(raise_delta.y) > absf(raise_delta.z))
	character.reset_pose_controls()
	await process_frame
	var foot_index := skeleton.find_bone("LeftFoot")
	var rest_foot_transform := skeleton.global_transform * skeleton.get_bone_global_pose(foot_index)
	for frame in 8:
		await process_frame
	var idle_foot_transform := skeleton.global_transform * skeleton.get_bone_global_pose(foot_index)
	assert(rest_foot_transform.origin.distance_to(idle_foot_transform.origin) < 0.0001)
	assert(rest_foot_transform.basis.get_rotation_quaternion().angle_to(idle_foot_transform.basis.get_rotation_quaternion()) < 0.001)
	character.set_pose_control("left_knee_bend", 70.0)
	await process_frame
	var bent_foot := skeleton.global_transform * skeleton.get_bone_global_pose(foot_index).origin
	var knee_delta := bent_foot - rest_foot_transform.origin
	print("KNEE_DELTA=", knee_delta)
	assert(absf(knee_delta.x) < 0.04)
	assert(absf(knee_delta.z) > 0.25)
	character.reset_pose_controls()
	var right_foot_index := skeleton.find_bone("RightFoot")
	var right_rest := skeleton.global_transform * skeleton.get_bone_global_pose(right_foot_index).origin
	character.set_pose_control("right_knee_bend", 70.0)
	await process_frame
	var right_bent := skeleton.global_transform * skeleton.get_bone_global_pose(right_foot_index).origin
	var right_knee_delta := right_bent - right_rest
	print("RIGHT_KNEE_DELTA=", right_knee_delta)
	assert(absf(right_knee_delta.x) < 0.04)
	assert(absf(right_knee_delta.z) > 0.25)
	assert(absf(knee_delta.y) > 0.05)
	assert(absf(forward_delta.z) > absf(forward_delta.y))
	character.set_pose_control("left_arm_forward", 35.0)
	print("VALIDATION_OK tops=", ModularCharacterBase.TopStyle.size() - 1, " bottoms=", ModularCharacterBase.BottomStyle.size() - 1, " glasses=", ModularCharacterBase.GlassesStyle.size() - 1)
	quit()
