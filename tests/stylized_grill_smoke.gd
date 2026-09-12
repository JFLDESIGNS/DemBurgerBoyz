extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	check(packed != null, "Game scene must parse and load")
	if packed == null:
		quit(1)
		return
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	var skin: Node3D = game.get("stylized_grill")
	check(is_instance_valid(skin), "Replacement grill must be installed")
	if is_instance_valid(skin):
		var surface: Node3D = game.get("grill_surface_area")
		check(skin.get_parent() == surface, "Skin must share the cooking surface transform")
		check(is_equal_approx(surface.global_position.y, 1.155), "Cooking height changed")
		check(skin.find_child("CookingSurface", true, false) == null, "Game export must not contain the reference cooking plate")
		check(not surface.get_node("GrillSplashGuard").visible, "Original guard overlaps replacement")
		var knob: Node3D = skin.get("knob")
		check(knob != null, "Export lost knob pivot")
		if knob != null:
			check(absf(knob.global_position.x - surface.global_position.x) < 0.001, "Power knob must be centered")
			check(is_equal_approx(knob.global_basis.x.length(), 1.26), "Power knob must be 30 percent smaller than the previous 1.8 scale")
			check(knob.global_position.y < surface.global_position.y, "Control must sit below cooking surface")
			var initial := knob.quaternion
			game.call("_set_grill_on", true)
			await create_timer(0.25).timeout
			check(bool(game.get("grill_on")), "Burner failed to turn on")
			check(is_equal_approx(initial.angle_to(knob.quaternion), PI * 0.5), "Knob must turn 90 degrees")
			check(skin.get("lamp_material").emission_enabled, "Heat light must illuminate")

			var flame_tip_max := -INF
			for step in [0.0, 0.13, 0.41, 1.7, 8.0]:
				game.call("_update_burner_flames", step)
				for flame: MeshInstance3D in game.get("burner_flame_tris"):
					for mesh_surface in flame.mesh.get_surface_count():
						var vertices: PackedVector3Array = flame.mesh.surface_get_arrays(mesh_surface)[Mesh.ARRAY_VERTEX]
						for vertex in vertices:
							flame_tip_max = maxf(flame_tip_max, (flame.global_transform * vertex).y)
			check(is_finite(flame_tip_max) and flame_tip_max < surface.global_position.y - 0.054, "Animated flames must stay beneath the grill fascia")
			print("FLAME_TOP_BELOW_STEEL ", surface.global_position.y - flame_tip_max)
			game.call("_set_grill_on", false)
			await create_timer(0.25).timeout
			check(initial.is_equal_approx(knob.quaternion), "Knob must return to OFF")
			check(not skin.get("lamp_material").emission_enabled, "Heat light must turn off")
			var camera: Camera3D = game.get("camera")
			var screen_pos := camera.unproject_position(knob.global_position)
			check(skin.knob_hit(camera, screen_pos), "Knob center must be clickable")
			var edge := camera.unproject_position(knob.global_position + knob.global_basis.x.normalized() * 0.0525)
			check(skin.knob_hit(camera, edge), "Enlarged knob edge must be clickable")
			check(not game.get("grill_power_row").visible, "Legacy burner row must be hidden")
			check(game.get("grill_power_row").get_child_count() == 0, "Legacy burner button must not be created")
			check(not skin.knob_hit(camera, camera.unproject_position(surface.global_position)), "Knob hit must not consume cooking surface clicks")
			game.set("playing", true)
			game.set("shift_paused", false)
			game.set("options_menu_open", false)
			game.get("start_overlay").hide()
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			click.position = screen_pos
			game.call("_input", click)
			check(bool(game.get("grill_on")), "Physical knob click must toggle existing burner")
			var hotkey := InputEventKey.new()
			hotkey.keycode = KEY_G
			hotkey.physical_keycode = KEY_G
			hotkey.pressed = true
			game.call("_unhandled_input", hotkey)
			check(not bool(game.get("grill_on")), "G key must toggle the same burner state")
			await create_timer(0.25).timeout
			check(initial.is_equal_approx(knob.quaternion), "G key must synchronize physical knob to OFF")
			check(not skin.get("lamp_material").emission_enabled, "G key must synchronize heat indicator to OFF")
			print("KNOB_SCREEN_POSITION ", screen_pos)
		check(game.get("grill_pad_mats").size() == 3, "FULL / HALF / HOLD zones must remain")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("STYLIZED_GRILL_SMOKE_OK import, alignment, heat zones, knob animation, light, physical click")
		quit(0)
	else:
		quit(1)
