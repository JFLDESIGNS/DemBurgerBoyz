extends SceneTree
func _initialize():call_deferred("run")
func run():
 var g=load("res://scenes/main.tscn").instantiate()
 g.set_script(load("res://tests/delivery_network_fixture.gd"));root.add_child(g)
 var pack=Node3D.new();g.add_child(pack);g._populate_fry_pack(pack)
 for mesh in pack.find_children("*","MeshInstance3D",true,false):
  print("FRY_MESH ",mesh.name," ",mesh.mesh.get_aabb()," basis ",mesh.global_basis," material ",mesh.material_override)
  assert(mesh.material_override is ShaderMaterial)
 assert(pack.find_child("BurgerPalsFriesLogo",true,false)==null)
 var bot=Node3D.new();g.add_child(bot);g._add_roomba_top_highlights(bot)
 assert(bot.get_child_count()==2)
 var cream=MeshInstance3D.new();cream.mesh=SphereMesh.new();cream.set_script(load("res://scripts/motion_glints.gd"))
 var mat=ShaderMaterial.new();mat.shader=load("res://shaders/icecream_diamond_glints.gdshader");cream.material_override=mat;g.add_child(cream)
 await process_frame;await process_frame
 assert(is_zero_approx(float(mat.get_shader_parameter("motion_amount"))))
 cream.position.x+=.1;cream._process(.016)
 assert(float(mat.get_shader_parameter("motion_amount"))>.9)
 cream._process(.016);assert(is_zero_approx(float(mat.get_shader_parameter("motion_amount"))))
 if DisplayServer.get_name()!="headless":
  g.get_node("UI").hide()
  var camera=Camera3D.new();g.add_child(camera);camera.position=Vector3(0,.2,-.45);camera.look_at(Vector3(0,.08,0));camera.current=true
  var light=DirectionalLight3D.new();g.add_child(light);light.rotation_degrees=Vector3(-30,150,0);light.light_energy=1.5
  await create_timer(2).timeout
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://build/food_fx_checked.png")
 print("FOOD_FX_REGRESSION_OK");quit()
