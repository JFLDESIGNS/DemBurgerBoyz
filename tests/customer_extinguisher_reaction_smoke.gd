extends SceneTree

const Customer := preload("res://scripts/customer.gd")
var failures: Array[String] = []

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for custom in [false, true]:
		var customer := Customer.new()
		var preset := {"format_version": 8, "name": "Spray Test", "body_type": "kenney_chunky_toon", "skin_color": "cf895fff", "top_color": "7259d9ff"} if custom else {}
		customer.setup(["bun_bottom", "patty", "bun_top"], Color.WHITE, 45.0, 0, 0, 0, -1, preset, true)
		root.add_child(customer)
		customer.set_process(false)
		customer.is_waiting = true
		customer.position = Vector3(customer.target_x, Customer.STAND_Y, Customer.WAIT_Z)
		var player: AnimationPlayer = customer.get("_anim_player")
		_expect(player != null, "Customer must have an AnimationPlayer")
		if player == null:
			customer.free()
			continue
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		_expect(player.has_animation(Customer.EXTINGUISHER_REACTION_ANIM), "Reaction library missing")
		var animation := player.get_animation(Customer.EXTINGUISHER_REACTION_ANIM)
		_expect(is_equal_approx(animation.length, 4.0), "Full four-second reaction must play")
		_expect(animation.loop_mode == Animation.LOOP_NONE, "Reaction must not loop")
		for track in animation.get_track_count():
			_expect(animation.track_get_type(track) in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D], "Asset must contain bone transforms only")
		var meshes: Array = customer.get("_char_meshes")
		var appearances: Array = []
		for mesh: MeshInstance3D in meshes:
			appearances.append([mesh.mesh, mesh.material_override, mesh.get_active_material(0)])
		customer.call("_cache_skeleton")
		var skeleton: Skeleton3D = customer.get("_skeleton")
		var left_foot := skeleton.find_bone("LeftFoot")
		var head := skeleton.find_bone("Head")
		var finger := skeleton.find_bone("LeftHandIndex3_end")
		var origin_before := customer.global_position
		_expect(customer.receive_ext_powder("face"), "First spray should start reaction")
		_expect(customer.get("_powder_uses_tantrum"), "Spray should choose imported animation")
		_expect(player.current_animation == Customer.EXTINGUISHER_REACTION_ANIM, "Wrong spray animation")
		player.advance(0.0)
		var ground := (skeleton.global_transform * skeleton.get_bone_global_pose(left_foot)).origin.y
		var hop_heights: Array[float] = []
		for frame in [26, 52, 77]:
			var time := float(frame - 1) / 30.0
			player.seek(time, true)
			var foot_y := (skeleton.global_transform * skeleton.get_bone_global_pose(left_foot)).origin.y
			hop_heights.append(foot_y - ground)
			_expect(foot_y > ground + 0.10, "Hop %s must visibly lift foot (custom=%s, height=%s)" % [frame, custom, foot_y - ground])
			var head_y := (skeleton.global_transform * skeleton.get_bone_global_pose(head)).origin.y
			var finger_y := (skeleton.global_transform * skeleton.get_bone_global_pose(finger)).origin.y
			_expect(finger_y > head_y + 0.20, "Hands must be raised during hops")
		player.seek(0.8, true)
		customer.call("_update_powder_stand", 0.8)
		var pose_before := skeleton.get_bone_pose_rotation(head)
		var elapsed: float = customer.get("_powder_stand_t")
		_expect(not customer.receive_ext_powder("body"), "Repeated spray must not retrigger")
		_expect(is_equal_approx(float(customer.get("_powder_stand_t")), elapsed), "Repeated hit restarted reaction timer")
		_expect(is_equal_approx(player.current_animation_position, 0.8), "Repeated hit restarted animation")
		customer.call("_play_anim", "idle")
		_expect(player.current_animation == Customer.EXTINGUISHER_REACTION_ANIM, "Idle overrode active reaction")
		_expect(skeleton.get_bone_pose_rotation(head).is_equal_approx(pose_before), "Procedural pose overrode authored head shake")
		customer.call("_update_powder_stand", 1.9)
		_expect(not customer.is_leaving, "Reaction was cut off at the old 2.6 second timeout")
		_expect(customer.global_position.distance_to(origin_before) < 0.01, "Animation displaced the gameplay queue node")
		customer.call("_update_powder_stand", 1.31)
		_expect(customer.is_leaving and not customer.get("_powdering"), "Customer should leave after reaction")
		_expect(player.active, "Walking animation remained disabled")
		customer.call("_update_sidewalk_leave", 0.5)
		customer.call("_update_sidewalk_leave", 0.1)
		_expect(player.current_animation != Customer.EXTINGUISHER_REACTION_ANIM, "Reaction did not release animation control")
		for i in meshes.size():
			var mesh: MeshInstance3D = meshes[i]
			_expect(mesh.mesh == appearances[i][0] and mesh.material_override == appearances[i][1] and mesh.get_active_material(0) == appearances[i][2], "Spray animation replaced a customer mesh or material")
		print("EXTINGUISHER_VARIANT_OK custom=", custom, " hop_heights=", hop_heights, " walk=", player.current_animation)
		customer.queue_free()
		await process_frame
	if failures.is_empty():
		print("CUSTOMER_EXTINGUISHER_REACTION_SMOKE_OK")
		quit(0)
	else:
		quit(1)
