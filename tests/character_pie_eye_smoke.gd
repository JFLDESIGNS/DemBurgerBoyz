extends SceneTree
func _initialize(): call_deferred("run")
func run():
 var actor = load("res://scenes/character_creator/modular_character_base.tscn").instantiate()
 root.add_child(actor)
 await process_frame
 assert(actor.eye_specular_pie_amount == 1.0)
 actor.apply_saved_preset({"eye_pupil_size":0.6})
 var group: Node3D = actor._eyes_root.get_node("EyeLeftGroup")
 assert(not group.has_node("Specular"),"Pie eyes should replace the old dot")
 var eye: ShaderMaterial = group.get_node("Eye").material_override
 assert(eye.get_shader_parameter("pie_amount") == 1.0)
 actor.eye_specular_pie_angle = -25.0
 group = actor._eyes_root.get_node("EyeLeftGroup")
 eye = group.get_node("Eye").material_override
 assert(eye.get_shader_parameter("pie_angle") == -25.0)
 actor.apply_saved_preset({"eye_specular_pie_amount":0.0})
 assert(actor._eyes_root.get_node("EyeLeftGroup").has_node("Specular"))
 actor.apply_saved_preset({"eye_specular_pie_amount":1.0,"eye_specular_pie_width":65.0})
 assert(actor.eye_specular_pie_width == 65.0)
 actor.scale = Vector3.ONE * 100.0
 await process_frame
 var left: Node3D = actor._eyes_root.get_node("EyeLeftGroup")
 var right: Node3D = actor._eyes_root.get_node("EyeRightGroup")
 var center := (left.global_position+right.global_position)*0.5
 var distance := left.global_position.distance_to(right.global_position)*3.8
 var camera := Camera3D.new()
 root.add_child(camera)
 camera.position = center + actor._eyes_root.global_basis.z.normalized()*distance
 camera.near = maxf(0.00001,distance * 0.01)
 camera.far = maxf(1.0,distance * 20.0)
 camera.look_at(center)
 camera.current = true
 var light := DirectionalLight3D.new()
 root.add_child(light)
 light.rotation_degrees = Vector3(-25,-30,0)
 for frame in 6: await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/light_balance_release/pie_eye_preview.png")
 var creator := load("res://scripts/character_creator.gd") as GDScript
 assert(creator.can_instantiate())
 print("CHARACTER_PIE_EYE_OK defaults, legacy preset, live controls, toggle, preset fields, creator")
 actor.free()
 quit()
