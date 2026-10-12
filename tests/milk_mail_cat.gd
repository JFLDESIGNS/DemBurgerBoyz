extends SceneTree
class MailCat extends Node3D:
 var phase="treat_wait"
 var courier: Node3D
 var fed=0
 func head_global()->Vector3:return courier.global_position+Vector3(0,.35,0)
 func waiting_for_treat()->bool:return true
 func receive_treat(_kind:String)->void:fed+=1
func _initialize():call_deferred("run")
func gui(g,point:Vector3)->Vector2:
 var pixel:Vector2=g.camera.unproject_position(point)
 var rect:Rect2=g.get_node("UI/Root").get_global_rect()
 return rect.position+pixel/g.get_viewport().get_visible_rect().size*rect.size
func run():
 create_timer(20).timeout.connect(func():quit(1))
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/main_ticket_harness.gd"));root.add_child(g);current_scene=g;g.playing=true
 g.camera.position=Vector3(0,.5,-2);g.camera.look_at(Vector3(0,.35,0))
 var audio=load("res://scripts/game_audio.gd").new();g.add_child(audio);g.game_audio=audio
 var milk=load("res://scripts/milk_refill.gd").new();milk.game=g;g.add_child(milk);milk.set_process(false)
 milk.carton=milk.make_carton();g.world.add_child(milk.carton)
 var center:Vector3=g._shop_preview_bounds(milk.carton).get_center()
 assert(milk.carton_hit(gui(g,milk.carton.to_global(center))))
 assert(not milk.carton_hit(Vector2(-200,-200)))
 g.patty_fridge_open=true
 var press=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.position=gui(g,milk.carton.to_global(center))
 assert(milk.handle_input(press) and milk.pressed)
 milk.pressed=false
 var mail=MailCat.new();mail.courier=Node3D.new();mail.add_child(mail.courier);g.world.add_child(mail);g.mail_delivery_truck=mail
 var sling=g._ensure_ingredient_slingshot();var target=gui(g,mail.head_global())
 assert(sling.catch_target(target)==mail.courier,"Mail cat must be aim-assist target")
 sling.launch("cheese",target+Vector2(0,180),target)
 await create_timer(.65).timeout
 assert(mail.fed==1,"Fling must feed the courier once")
 var voice=mail.courier.get_node_or_null("CustomerEatingVoice")
 assert(voice!=null and is_equal_approx(voice.pitch_scale,1.55),"Mail cat must use the high nom voice")
 print("MILK_MAIL_CAT_OK: carton body clickable, projectile catch, high nom voice")
 g.queue_free();await process_frame;await process_frame;quit()
