extends SceneTree
const Customer = preload("res://scripts/customer.gd")
var failures: Array[String] = []
var output := ""
func expect(ok: bool, msg: String) -> void:
 if not ok:
  failures.append(msg)
  push_error(msg)
func _initialize() -> void: call_deferred("run")
func shot(name: String) -> void:
 if DisplayServer.get_name() == "headless": return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(name+".png"))
func run() -> void:
 create_timer(60).timeout.connect(func(): push_error("CUSTOMER_LIFE_TIMEOUT"); quit(1))
 output = OS.get_environment("BURGER_PROBE_OUTPUT")
 if output.is_empty(): output = ProjectSettings.globalize_path("res://build/customer_life")
 root.size = Vector2i(1280,720)
 var stage := Node3D.new()
 root.add_child(stage)
 current_scene = stage
 var camera := Camera3D.new()
 stage.add_child(camera)
 camera.position = Vector3(0,1.3,3.5)
 camera.look_at(Vector3(0,0.8,0))
 camera.current = true
 var light := DirectionalLight3D.new()
 stage.add_child(light)
 light.rotation_degrees = Vector3(-30,-25,0)
 light.light_energy = 1.4
 var env := WorldEnvironment.new()
 env.environment = Environment.new()
 env.environment.background_mode = Environment.BG_COLOR
 env.environment.background_color = Color("283640")
 env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 env.environment.ambient_light_color = Color.WHITE
 env.environment.ambient_light_energy = .6
 stage.add_child(env)
 for custom in [false,true]:
  var c := Customer.new()
  c.setup(["bun_bottom","patty","bun_top"],Color.WHITE,45,0,0,0,-1,{"format_version":8,"body_type":"kenney_chunky_toon","name":"Probe","hair_style":3,"lash_style":1,"eyelid_enabled":true,"eye_opening_version":1} if custom else {},true)
  stage.add_child(c)
  c.position = Vector3.ZERO
  c.rotation = Vector3.ZERO
  c.set_process(false)
  c.is_waiting = true
  var player: AnimationPlayer = c.get("_anim_player")
  var sk := c.find_child("Skeleton3D",true,false) as Skeleton3D
  var life := c.get_node("CustomerLife")
  life.set_process(false)
  player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
  for clip in Customer.WAITING_IDLES:
   c._play_anim("burger:"+clip)
   player.advance(.3)
   expect(player.current_animation=="burger/"+clip,"Waiting clip missing: "+clip)
  c._burger_idle = "Idle_Forward"
  for state in ["idle","walk","burger:Phone_One_Hand","idle","button","idle","offensive","walk","idle"]:
   c._play_anim(state)
   player.advance(.3)
   c._reset_skeleton_pose()
   var arm := sk.find_bone("LeftArm")
   var angle := sk.get_bone_pose_rotation(arm).angle_to(sk.get_bone_rest(arm).basis.get_rotation_quaternion())
   expect(angle>.2,"Reset exposed T pose: "+state)
   player.active = false
   c._play_anim(state)
   expect(player.active and player.is_playing(),"Inactive same-state animator did not recover: "+state)
  c.show_review_stars(1,"We are closed")
  expect(c.get_node_or_null("ReviewCardRoot")==null,"Review block must not be created")
  if custom:
   expect(is_instance_valid(life.modular),"Custom character helper not bound")
   c._play_anim("burger:Phone_One_Hand")
   player.seek(player.get_animation("burger/Phone_One_Hand").length * 0.5, true)
   player.advance(.2)
   life._process(.016)
   expect(c._burger_props.get_node("phone").is_visible_in_tree(),"Phone must be visible in the hand")
   print("PHONE_ROOT ",player.root_node," ",player.get_node(player.root_node).get_path()," ",c._burger_props.get_path())
   print("PHONE_STATE ",player.current_animation," ",c._burger_props.visible," ",c._burger_props.get_node("phone").visible," ",c._burger_props.get_node("phone").global_position)
   for i in 5:
    player.advance(.016)
    life._process(.016)
    await process_frame
   print("PHONE_AFTER ",player.current_animation," ",c._burger_props.get_node("phone").is_visible_in_tree()," ",c._burger_props.global_position)
   await shot("customer_phone")
   c._play_anim("idle")
   player.advance(.2)
   var eyes: Node3D = life.modular.get("_eyes_root")
   var eye := eyes.get_child(0).get_node("Eye") as MeshInstance3D
   var mat := eye.material_override as ShaderMaterial
   life.forced_target = eye.global_position + eye.global_basis.orthonormalized()*Vector3(.5,.15,1)
   life.gaze_left = 3.0
   life.with_head = true
   life.gaze_cooldown = 20.0
   life.blink_wait = 20.0
   for i in 20:
    life._process(.016)
    await process_frame
   expect((mat.get_shader_parameter("pupil_gaze") as Vector2).length()>.02,"Pupils did not track target")
   await shot("customer_looking")
   life.blink_age = .05
   life._process(.03)
   var lid := eyes.get_child(0).get_node_or_null("Eyelid") as MeshInstance3D
   expect(lid!=null,"Test customer should have eyelids")
   if lid!=null: expect(float(lid.material_override.get_shader_parameter("blink"))>.95,"Lid did not close")
   await shot("customer_blink")
   c.set("_eating",true)
   c.set_meta("meal_stars",5.0)
   for i in 45: life._process(.016)
   var enlarged := float(mat.get_shader_parameter("pupil_size"))
   expect(enlarged>float(life.modular.eye_pupil_size)*1.15,"Five-star meal did not dilate pupils")
   c.is_leaving = true
   for i in 45: life._process(.016)
   expect(is_equal_approx(float(mat.get_shader_parameter("pupil_size")),life.modular.eye_pupil_size),"Pupils did not return to normal when leaving")
   c.is_leaving=false
   c.set("_eating",false)
   c._play_anim("walk")
   var max_hair := 0.0
   for i in 60:
    player.advance(.016)
    life._process(.016)
    max_hair=maxf(max_hair,absf(life.hair_value))
   expect(max_hair>.003 and max_hair<=.04,"Hair bounce missing or too large")
  c.queue_free()
  for i in 3: await process_frame
 print("CUSTOMER_LIFE_OK" if failures.is_empty() else "CUSTOMER_LIFE_FAILED")
 stage.queue_free()
 for i in 3: await process_frame
 quit(0 if failures.is_empty() else 1)
