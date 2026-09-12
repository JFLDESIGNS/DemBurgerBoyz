extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	get_root().size = Vector2i(1280, 800)
	var scene := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_root().add_child(scene)
	var character := scene.get_node("World/Character") as ModularCharacterBase
	var camera_rig := scene.get_node("World/CameraRig") as Node3D
	var camera := scene.get_node("World/CameraRig/Camera3D") as Camera3D
	character.set_control_rig_visible(false)
	camera_rig.position = Vector3(0.0, 1.75, 0.0)
	camera_rig.rotation = Vector3(-0.02, 0.0, 0.0)
	camera.position = Vector3(0.0, 0.0, 2.5)
	camera.fov = 38.0
	character.eye_pupil_size = 0.28
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("C:/Users/joe/Desktop/burgergame/build/eye_pupil_small_qa.png")
	character.eye_pupil_size = 0.78
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("C:/Users/joe/Desktop/burgergame/build/eye_pupil_large_qa.png")
	print("EYE_SHADER_QA_CAPTURED")
	quit()