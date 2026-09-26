extends SceneTree
func _initialize():call_deferred("run")
func run():
 var g=load("res://scenes/main.tscn").instantiate()
 g.set_script(load("res://tests/delivery_network_fixture.gd"));root.add_child(g);current_scene=g
 g.get_node("UI/Root").hide()
 var canvas:=CanvasLayer.new();root.add_child(canvas)
 var bg:=ColorRect.new();bg.color=Color("28343A");bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);canvas.add_child(bg)
 var viewport:=SubViewport.new();viewport.size=Vector2i(450,600);viewport.transparent_bg=true;viewport.own_world_3d=true;root.add_child(viewport)
 var pack:=Node3D.new();viewport.add_child(pack);g._populate_fry_pack(pack)
 assert(pack.get_node("BurgerPalsFriesLogo").material_override is ShaderMaterial)
 var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=.62;camera.position=Vector3(0,.35,-1);viewport.add_child(camera);camera.look_at(Vector3(0,.16,0));camera.current=true
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,160,0);viewport.add_child(light)
 var photo:=TextureRect.new();photo.texture=viewport.get_texture();photo.position=Vector2(15,25);photo.size=Vector2(450,600);canvas.add_child(photo)
 var patty:=TextureRect.new();patty.texture=load("res://scripts/food_sprites.gd").build_patty_state_tex(0,false);patty.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;patty.position=Vector2(540,420);patty.size=Vector2(380,198);canvas.add_child(patty)
 var heat=load("res://scripts/build_patty_heat.gd").new();canvas.add_child(heat);heat.setup(g,null);heat.position=Vector2(350,-200);heat.size=Vector2(760,760)
 var bubbles=load("res://scripts/build_patty_bubbles.gd").new();patty.add_child(bubbles);bubbles.heat=heat;bubbles.size=patty.size
 await create_timer(2).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/light_balance_release/logo_heat_detail.png")
 g._build_challenge_ui()
 g.get_node("UI/Root").show()
 bg.hide();photo.hide();patty.hide();heat.hide()
 g._challenge_phase="active";g._challenge_remaining=10;g._challenge_time_left=90;g._challenge_time_max=180
 g._update_challenge_hud()
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/challenge_hud_detail.png")
 print("LOGO_HEAT_OK")
 quit()
