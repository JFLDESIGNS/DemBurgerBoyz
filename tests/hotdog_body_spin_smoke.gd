extends SceneTree

func _initialize():
	create_timer(30.0).timeout.connect(func(): quit(1))
	call_deferred("run")

func run() -> void:
	var boss = load("res://scripts/hotdog_boss_customer.gd").new()
	root.add_child(boss)
	assert(is_instance_valid(boss.rig) and is_instance_valid(boss.player))
	assert(boss.player.get_animation_list().size() == 14)
	assert(boss.player.has_animation("throw_hotdog"))
	var player: AnimationPlayer = boss.player
	var rig: Skeleton3D = boss.rig
	var root_bone := rig.find_bone("ROOT")
	var left := rig.find_bone("Fist.L")
	var right := rig.find_bone("Fist.R")
	var length: float = player.get_animation("ground_breakout").length
	player.play("ground_breakout")
	player.seek(length * .65, true)
	var facing := rig.get_bone_global_pose(root_bone).basis.get_rotation_quaternion()
	player.seek(length * .37, true)
	assert(rig.get_bone_global_pose(root_bone).basis.get_rotation_quaternion().angle_to(facing) > 3.0)
	player.seek(length * .50, true)
	var middle := rig.get_bone_global_pose(root_bone).basis.get_rotation_quaternion().angle_to(facing)
	assert(middle > 1.2 and middle < 1.9, "Half-turn must happen quickly during the rise")
	assert(rig.get_bone_global_pose(left).origin.distance_to(rig.get_bone_global_pose(right).origin) < 3.2, "Entrance fists should stay tucked beside body")
	player.seek(length * .63, true)
	assert(rig.get_bone_global_pose(root_bone).basis.get_rotation_quaternion().angle_to(facing) < .02)
	assert(length * .22 < .51)
	var flat_face := false
	for mesh in boss.find_children("*", "MeshInstance3D", true, false):
		for index in mesh.mesh.get_surface_count():
			var material = mesh.get_active_material(index)
			if material != null and "Flat cartoon ink" in material.resource_name:
				flat_face = material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
	assert(flat_face, "Mouth and brows should not get crinkled lighting")
	player.play("slump")
	player.seek(player.get_animation("slump").length, true)
	var head := rig.find_bone("Spine.07")
	var crown := rig.find_bone("Crown")
	var fake_head := rig.get_bone_global_pose(head).origin
	assert(rig.get_bone_global_pose(crown).origin.distance_to(fake_head) < .5)
	player.play("slump_defeat")
	player.seek(player.get_animation("slump_defeat").length, true)
	assert(rig.get_bone_global_pose(head).origin.y < fake_head.y - .3)
	assert(rig.get_bone_global_pose(crown).origin.y < .5, "Final crown must fall to the ground")
	var controller := Node.new()
	controller.set_script(load("res://scripts/hotdog_challenge.gd"))
	root.add_child(controller); controller.set_process(false); controller.phase = "sinking"
	boss.boss = controller
	var landed := rig.get_bone_global_pose(crown)
	boss.begin_ground_exit(); boss.update_ground_exit(.5)
	assert(rig.get_bone_global_pose(crown).origin.distance_to(landed.origin) < .001, "Sinking must not put the crown back on his head")
	controller.queue_free()
	print("HOTDOG_BODY_SPIN_OK duration=", length * .22, " seconds; 14 clips; fake and final slumps; fallen crown preserved")
	boss.queue_free()
	await process_frame
	quit()
