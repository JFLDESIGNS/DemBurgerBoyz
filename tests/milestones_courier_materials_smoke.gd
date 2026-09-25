extends SceneTree
var failures:=0
func expect(ok: bool, message: String) -> void:
 if not ok: push_error(message);failures+=1
func _initialize(): call_deferred("run")
func run():
 var a=load("res://scripts/achievements.gd").new()
 a.save_path="user://achievement_smoke.cfg"
 DirAccess.remove_absolute(a.save_path)
 root.add_child(a)
 a.setup(null)
 expect(a.catalog.size()==46,"46 unique milestones")
 a.record("earnings",99)
 expect(not a.earned.has("earnings_100"),"No early earning reward")
 a.record("earnings",1)
 expect(a.earned.has("earnings_100"),"100 dollars unlock")
 a.record("earnings",400)
 expect(a.earned.has("earnings_500"),"500 dollars unlock")
 var stamps: Dictionary=a.earned.duplicate()
 a.record("earnings",1)
 expect(a.earned==stamps,"No duplicate unlocks")
 a.record("orders")
 a.record("perfect_burgers")
 a.record("purchases")
 a.record("unlocks")
 expect(a.earned.has("orders_1") and a.earned.has("perfect_burgers_1") and a.earned.has("purchases_1") and a.earned.has("unlocks_1"),"First milestones")
 var b=load("res://scripts/achievements.gd").new()
 b.save_path=a.save_path
 root.add_child(b);b.setup(null)
 expect(b.earned==a.earned and b.stats==a.stats,"Persistent progress")
 var game=load("res://scenes/main.tscn").instantiate()
 game.set_script(load("res://tests/main_ticket_harness.gd"))
 root.add_child(game);current_scene=game
 game.achievements=a
 game.playing=true
 game.tutorial_mode=true
 var before: Dictionary=a.stats.duplicate()
 game._achievement_event("orders")
 expect(a.stats==before,"Tutorial does not count")
 game.tutorial_mode=false
 game._achievement_event("orders")
 expect(a.stats.orders==2.0,"Real order counts")
 for child in game.get_node("UI/Root").get_children():
  if child is CanvasItem: child.hide()
 var container:=PanelContainer.new()
 container.position=Vector2(20,20);container.size=Vector2(370,900)
 game.get_node("UI/Root").add_child(container)
 a.make_page(container);a.page.show()
 var cone: Node3D=game._create_icecream_cone_node(false)
 game.world.add_child(cone)
 var swirl: Node3D=cone.get_node("SoftServeSwirl")
 game._refresh_icecream_cone_visuals_for(swirl,1.0)
 expect(swirl.get_node_or_null("IceCreamSnowSparkles")==null,"No floating ice cream dots")
 expect(swirl.get_node("CorkscrewSplineServe").material_override is ShaderMaterial,"Surface sparkle shader")
 var grill=load("res://assets/machines/stylized_grill.glb").instantiate()
 grill.set_script(load("res://scripts/stylized_grill.gd"))
 game.world.add_child(grill);grill.configure()
 grill.position=Vector3(0,-0.4,1.0)
 cone.position=Vector3(0,0,0)
 game.camera.position=Vector3(0,0.17,-0.55)
 game.camera.look_at(Vector3(0,0.16,0))
 game.camera.current=true
 var light:=DirectionalLight3D.new()
 var env:=Environment.new()
 env.background_mode=Environment.BG_COLOR
 env.background_color=Color("263442")
 env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.ambient_light_color=Color("bccbe6")
 env.ambient_light_energy=0.7
 var we:=WorldEnvironment.new()
 we.environment=env
 game.world.add_child(we)
 light.rotation_degrees=Vector3(-30,150,0)
 game.world.add_child(light)
 game.tutorial_mode=true
 var mail=load("res://scripts/mail_delivery_truck.gd").new()
 mail.game=game
 game.world.add_child(mail)
 mail.set_phase("treat_wait")
 expect(mail.waiting_for_treat(),"Courier requests treat")
 mail.pet_courier()
 expect(mail.pet_hop_left < 0.72 and mail.animation.speed_scale==3.0,"Mail pet hop 3x")
 mail.receive_treat("cheese")
 expect(mail.phase=="thanks","Courier accepts treat")
 mail.advance(0.9)
 expect(mail.phase=="return","Courier leaves after thanks")
 mail.set_phase("treat_wait");mail.elapsed=9.1;mail.advance(0.01)
 expect(mail.phase=="return","Treat wait times out")
 mail.clip("03_Box_Delivery")
 expect(is_equal_approx(mail.animation.speed_scale,2.0),"Box animation runs twice as fast")
 mail.hide()
 var cat=load("res://scripts/window_cat.gd").new()
 cat.pet(true)
 expect(cat._happy_speed==3.0 and cat._happy_anim_left<0.72,"Window cat pet hop 3x")
 cat.free()
 for i in 30: await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/light_balance_release/milestones_cone_preview.png")
 print("MILESTONES_COURIER_MATERIALS_OK failures=",failures)
 DirAccess.remove_absolute(a.save_path)
 quit(1 if failures else 0)
