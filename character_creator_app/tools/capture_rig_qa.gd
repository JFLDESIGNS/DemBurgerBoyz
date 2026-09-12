extends SceneTree


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	get_root().size = Vector2i(1280, 800)
	var scene := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_root().add_child(scene)
	var character := scene.get_node("World/Character") as ModularCharacterBase
	(scene.get_node("World/CameraRig/Camera3D") as Camera3D).position.z = 4.3
	for frame in 8:
		await process_frame
	character.set_pose_control("left_arm_raise", 58.0)
	character.set_pose_control("right_arm_raise", 58.0)
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("C:/Users/joe/Desktop/burgergame/build/rig_raise_qa.png")
	character.reset_pose_controls()
	character.set_pose_control("left_arm_forward", 52.0)
	character.set_pose_control("right_arm_forward", 52.0)
	(scene.get_node("World/CameraRig") as Node3D).rotation.y = PI * 0.5
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("C:/Users/joe/Desktop/burgergame/build/rig_forward_qa.png")
	print("RIG QA CAPTURED")
	quit()
