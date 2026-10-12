extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 create_timer(60).timeout.connect(func():quit(1))
 var game=load("res://scenes/main.tscn").instantiate()
 game.set_script(load("res://tests/main_ticket_harness.gd"))
 root.add_child(game);current_scene=game;game.playing=true
 var social=load("res://scripts/customer_social.gd").new()
 game.add_child(social);social.game=game;game._customer_social=social;social.set_process(false)
 for i in 2:
  var person=load("res://scripts/customer.gd").new()
  var order: Array[String]=[]
  person.setup(order,Color.WHITE,9999.0,0,0,0,i)
  game.world.add_child(person);person.set_process(false);person.is_waiting=true
  person.position=Vector3(-.35-i*1.1,.1,2.7);person.target_x=person.position.x
  game.customers.append(person)
 var first=game.customers[0]
 var second=game.customers[1]
 first._apply_leave_fade_alpha(.5)
 assert(first._leave_fade_bound and not first._leave_fade_bindings.is_empty())
 var original_bindings: Array=first._leave_fade_bindings.duplicate()
 first._apply_leave_fade_alpha(1.0)
 assert(not first._leave_fade_bound and first._leave_fade_materials.is_empty())
 for binding in original_bindings:
  var restored: Material=binding.mesh.material_override if int(binding.surface)<0 else binding.mesh.get_surface_override_material(int(binding.surface))
  assert(restored==binding.material,"Opaque materials must return after leaving the doorway")
 assert(social.first_ordering_customer()==first)
 var cat=load("res://scripts/window_cat.gd").new()
 game.world.add_child(cat);cat.set_process(false);cat.visible=true;cat._state="peek"
 cat.react_to_customer(second,false)
 assert(cat._state=="peek","Cat cannot swat second customer")
 first._eating=true
 cat.react_to_customer(first,false)
 assert(cat._state=="peek","Cat cannot swat an eating customer")
 var old_position: Vector3=first.position
 first.target_x+=1.0
 first._advance_customer(.1)
 assert(first.position.is_equal_approx(old_position),"Eating must not start queue walking")
 first._play_anim("walk")
 assert(first._anim_state!="walk")
 first._eating=false;first.target_x=old_position.x
 first.pet_cat();first._advance_customer(.2)
 assert(first._cat_pet_left>0.0)
 assert(str(first._anim_player.current_animation).begins_with("burger/Pet_Cat_"),"Pet must use the baked Blender clip")
 var pet_clip: Animation=first._anim_player.get_animation(first._anim_player.current_animation)
 assert(is_equal_approx(pet_clip.length,2.4))
 var pet_side := "Left" if str(first._anim_player.current_animation).ends_with("Left") else "Right"
 var hand_track:=pet_clip.find_track(NodePath("Root/Skeleton3D:"+pet_side+"Arm"),Animation.TYPE_ROTATION_3D)
 assert(hand_track>=0 and not pet_clip.rotation_track_interpolate(hand_track,.7).is_equal_approx(pet_clip.rotation_track_interpolate(hand_track,.95)),"Pet strokes must move the reaching arm")
 cat.react_to_customer(first,false)
 assert(cat._state=="social_swat")
 cat._state="peek";cat.rub_customer(first)
 assert(cat._state=="social_rub" and cat._purr_left>0)
 var reaction=load("res://scripts/customer_truck_smack.gd").new()
 game.add_child(reaction);reaction.setup(game,first,old_position);reaction.set_process(false)
 for i in 190:reaction._process(1.0/60.0)
 assert(reaction.hit and game.slot_camera_shake_amp>=.075)
 for i in 125:reaction._process(1.0/60.0)
 assert(not bool(first.get_meta("truck_smack_busy",true)))
 assert(first.position.is_equal_approx(old_position))
 print("STREET_SOCIAL_OK: first-only swats, eating guards, pet/rub, truck impact and return")
 game.queue_free();await process_frame;quit()
