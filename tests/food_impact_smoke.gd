extends SceneTree
func _initialize(): call_deferred("run")
func run():
 create_timer(75).timeout.connect(func(): push_error("IMPACT_TIMEOUT"); quit(1))
 var scene := Node3D.new()
 root.add_child(scene)
 var floor := StaticBody3D.new()
 scene.add_child(floor)
 floor.position.y = -0.15
 var floor_mesh := MeshInstance3D.new()
 var box := BoxMesh.new()
 box.size = Vector3(4,0.2,4)
 floor_mesh.mesh = box
 floor.add_child(floor_mesh)
 var shape := CollisionShape3D.new()
 shape.shape = box.create_convex_shape()
 floor.add_child(shape)
 var env := WorldEnvironment.new()
 env.environment = Environment.new()
 env.environment.background_mode = Environment.BG_COLOR
 env.environment.background_color = Color("303747")
 env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 env.environment.ambient_light_color = Color("7094db")
 env.environment.ambient_light_energy = 0.6
 scene.add_child(env)
 var sun := DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-35,-40,0)
 sun.light_color = Color("ffe2ae")
 sun.shadow_enabled = true
 scene.add_child(sun)
 var camera := Camera3D.new()
 scene.add_child(camera)
 camera.position = Vector3(1.4,1.5,3.0)
 camera.look_at(Vector3(0,0.9,0))
 camera.current = true
 var hit = preload("res://scripts/food_impact.gd").surface(floor,Vector3(0,0.5,0),Vector3.UP)
 assert(absf(float(hit.position.y) + 0.044) < 0.01,"Impact must hit the actual mesh face")
 var c = load("res://scripts/customer.gd").new()
 var order: Array[String] = ["bun_bottom","patty","bun_top"]
 c.setup(order,Color.WHITE,45.0,0,0,0,-1,{"format_version":8,"name":"Impact Preview","body_type":"kenney_chunky_toon","skin_color":"cf895fff","top_style":2,"hair_style":1},true)
 scene.add_child(c)
 c.position = Vector3.ZERO
 c.rotation = Vector3.ZERO
 c.is_waiting = true
 c.set_process(false)
 for i in 4: await process_frame
 var target: Vector3 = c.reserve_stuck_food_world_target()
 var food = load("res://scripts/food_sprites.gd")
 c.receive_stuck_food("cheese",food.get_tex("cheese"),target,"face")
 var card = c._stuck_food_items.back()
 assert(not card.material_override.no_depth_test)
 assert(card.material_override.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL)
 var game = load("res://scripts/game.gd").new()
 var texture = game._get_condiment_smear_texture(0)
 c.receive_sauce("ketchup",texture,Color("b51d16"),"body")
 assert(c._stuck_food_items.back() is Decal)
 var smear := MeshInstance3D.new()
 smear.mesh = PlaneMesh.new()
 var mat := StandardMaterial3D.new()
 game._apply_condiment_smear_material(mat,"ketchup",0)
 smear.material_override = mat
 var original = mat.albedo_texture
 game._apply_cooked_smear_look({"mesh":smear,"charred":true,"smear_tex":0})
 assert(mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR)
 assert(mat.albedo_texture == original,"Burn must preserve the smear silhouette")
 smear.position = Vector3(-0.8,0.0,0.1)
 smear.scale = Vector3(0.3,1,0.3)
 scene.add_child(smear)
 var flag := MeshInstance3D.new()
 var quad := QuadMesh.new()
 quad.size = Vector2(.4,.4)
 flag.mesh = quad
 var flagmat := ShaderMaterial.new()
 flagmat.shader = load("res://shaders/bunting_flag.gdshader")
 flag.material_override = flagmat
 scene.add_child(flag)
 flag.position = Vector3(-.65,1.65,0)
 await create_timer(.25).timeout
 if DisplayServer.get_name() != "headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://build/light_balance_release/food_impact_preview.png")
 await create_timer(0.65).timeout
 assert(scene.find_children("FallingIngredient","RigidBody3D",true,false).size() == 1)
 game.free()
 print("FOOD_IMPACT_OK lighting, surface placement, decals, physics, burn alpha")
 quit()
