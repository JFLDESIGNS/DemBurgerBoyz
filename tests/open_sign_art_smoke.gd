extends SceneTree
func _initialize(): call_deferred("run")
func run():
 var game = load("res://scenes/main.tscn").instantiate()
 game.set_script(load("res://tests/main_ticket_harness.gd"))
 root.add_child(game)
 current_scene = game
 for child in game.get_node("UI/Root").get_children():
  if child is CanvasItem: child.hide()
 game._build_open_closed_sign()
 var sign_root: Node3D = game.open_closed_sign
 var face: MeshInstance3D = sign_root.get_node("OpenFace")
 var tex: Texture2D = face.material_override.get_shader_parameter("artwork")
 var img := tex.get_image()
 if img.is_compressed(): img.decompress()
 assert(img.get_pixel(0,0).a == 0.0)
 assert(is_equal_approx(face.mesh.size.y/face.mesh.size.x,float(tex.get_height())/tex.get_width()))
 assert(sign_root.has_node("ClosedFace"))
 assert(sign_root.scale.is_equal_approx(Vector3.ONE * 0.7))
 game.camera.position = sign_root.global_position + Vector3(0,0,-1.05)
 game.camera.look_at(sign_root.global_position)
 game.camera.current = true
 game.service_window_closed = false
 game._sync_open_closed_sign(false)
 for i in 5: await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/light_balance_release/open_sign_preview.png")
 game.playing = true
 var click: Vector2 = game.camera.unproject_position(sign_root.global_position)
 assert(game._try_open_closed_sign_click(click))
 assert(game.open_closed_sign_pivot.dragging)
 assert(not game.service_window_closed)
 assert(game._try_open_closed_sign_click(click))
 assert(game.service_window_closed)
 await create_timer(0.55).timeout
 assert(not game.open_closed_sign_busy)
 assert(is_equal_approx(sign_root.rotation_degrees.y,game.OPEN_CLOSED_SIGN_YAW_CLOSED))
 game._open_sign_last_click_ms = Time.get_ticks_msec() - 600
 assert(game._try_open_closed_sign_click(click))
 assert(game.service_window_closed)
 var pivot = game.open_closed_sign_pivot
 var anchor: Vector3 = pivot.global_position
 var corner: Vector2 = game.camera.unproject_position(sign_root.to_global(Vector3(-0.29,-0.19,0)))
 assert(pivot.begin_drag(corner))
 var motion := InputEventMouseMotion.new()
 motion.relative = Vector2(35,0)
 pivot._input(motion)
 assert(pivot.target < 0.0)
 pivot.dragging = false
 pivot.swing = 0.4
 pivot.speed = 0.0
 for i in 30: pivot._process(0.016)
 assert(absf(pivot.swing) < 0.4)
 assert(pivot.global_position.is_equal_approx(anchor))
 print("SIGN_SWING_OK corner grab, drag input, fixed pin, spring return")
 print("OPEN_SIGN_ART_OK alpha, aspect, 70 percent scale, single click, double click, timeout, flip")
 game.free()
 quit()
