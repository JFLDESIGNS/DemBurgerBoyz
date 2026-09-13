extends SceneTree
const Customer = preload("res://scripts/customer.gd")
var failures: Array[String] = []
var output := ""
func _initialize(): call_deferred("run")
func expect(ok: bool, msg: String) -> void:
 if not ok:
  failures.append(msg)
  push_error(msg)
func shot(name: String) -> void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(name+".png"))
func move_spatula(game: Node, screen: Vector2) -> void:
 var tip: Vector3=game._hand_spatula_tip_from_screen(screen,game.GRILL_SURFACE_Y+game.HAND_SPATULA_HOLD_Y)
 game.hand_spatula_root.global_position=tip-game.hand_spatula_root.global_basis*game.HAND_SPATULA_TIP_OFFSET
func run() -> void:
 create_timer(75).timeout.connect(func():push_error("CUSTOMER_GAZE_TIMEOUT");quit(1))
 output=OS.get_environment("BURGER_PROBE_OUTPUT")
 if output.is_empty():output=ProjectSettings.globalize_path("res://build/gaze_fix")
 root.size=Vector2i(1280,720)
 root.content_scale_size=Vector2i(1280,720)
 var game=load("res://scenes/main.tscn").instantiate()
 game.set_script(load(get_script().resource_path.get_base_dir().path_join("main_ticket_harness.gd")))
 root.add_child(game)
 current_scene=game
 game.set_process_input(false)
 for child in game.get_node("UI/Root").get_children():
  if child is CanvasItem:child.hide()
 game._build_hand_spatula()
 game.hand_spatula_root.show()
 var light:=DirectionalLight3D.new()
 light.rotation_degrees=Vector3(-35,25,0)
 light.light_energy=1.4
 game.add_child(light)
 var env:=WorldEnvironment.new()
 env.environment=Environment.new()
 env.environment.background_mode=Environment.BG_COLOR
 env.environment.background_color=Color("273b42")
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.environment.ambient_light_color=Color.WHITE
 env.environment.ambient_light_energy=.6
 game.add_child(env)
 for ci in 3:
  var preset:=Customer.take_next_saved_character_preset()
  if preset.is_empty():preset={"format_version":11,"body_type":"kenney_chunky_toon","name":"Gaze Test","hair_style":3,"eye_opening_version":1,"lash_style":1}
  var c:=Customer.new()
  c.setup(["bun_bottom","patty","bun_top"],Color.WHITE,90,0,0,0,-1,preset,true)
  game.customers_root.add_child(c)
  c.set_process(false)
  c.position=Vector3(0,Customer.STAND_Y,2.25)
  c.rotation_degrees.y=Customer.FACE_TRUCK_YAW
  c.is_waiting=true
  c._burger_idle="Idle_Forward"
  c._play_anim("idle")
  var life=c.get_node("CustomerLife")
  life.set_process(false)
  var glance_count := 0
  for trial in 200:
   if life.react_to_grill_tap(Vector3(0,1,0)): glance_count += 1
  expect(glance_count > 65 and glance_count < 135,"Tap attention must have a fifty-percent chance")
  life.tap_glance_left = 0.0
  life.start_grill_dance()
  expect(is_equal_approx(life.dance_left,2.0),"Each piano tap refreshes two seconds of dancing")
  life._process(2.01)
  expect(is_zero_approx(life.dance_left),"Dance stops after two seconds without taps")
  var player: AnimationPlayer=c._anim_player
  player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
  var eyes: Node3D=life.modular.get("_eyes_root")
  var eye:=eyes.get_child(0).get_node("Eye") as MeshInstance3D
  var mat:=eye.material_override as ShaderMaterial
  expect(not life.forced_target.is_finite(),"Test must use the real spatula, not forced_target")
  print("PRESET ",c.custom_character_name," pupil=",life.modular.eye_pupil_size," yaw=",life.modular.left_eye_yaw," inward=",life.modular.eye_pupil_inward)
  var left: Array[Vector2]=[]
  var right: Array[Vector2]=[]
  for side in 2:
   var viewport_size: Vector2=game.get_viewport().get_visible_rect().size
   move_spatula(game,Vector2(viewport_size.x*(0.22 if side==0 else 0.82),viewport_size.y*0.70))
   print("BLADE ",side," ",game._spatula_tip_world_pos())
   for frame in 48:
    player.advance(1.0/60.0)
    life._process(1.0/60.0)
    life.with_head=false
    await process_frame
   expect(life.gaze_strength>.95,"Customer did not start following within 0.8 seconds")
   expect(life.target_world.distance_to(game._spatula_tip_world_pos())<.001,"Gaze did not use live blade tip")
   for group in eyes.get_children():
    var pupil: Vector2=group.get_node("Eye").material_override.get_shader_parameter("pupil_gaze")
    if side==0:left.append(pupil)
    else:right.append(pupil)
   if ci==0:await shot("spatula_gaze_left" if side==0 else "spatula_gaze_right")
  for i in left.size():
   expect(absf(right[i].x-left[i].x)>.12,"Spatula movement did not visibly move pupil %d on customer %d"%[i,ci])
  for pair in [left,right]:
   var nearest_travel: float = minf(absf(pair[0].x),absf(pair[1].x))
   var farthest_travel: float = maxf(absf(pair[0].x),absf(pair[1].x))
   expect(nearest_travel > farthest_travel * 0.65,"Near eye must move comparably to far eye from its resting position")
  print("GAZE_TRAVEL customer=",ci," left=",left," right=",right)
  # Natural 45-second waiting sequence, including side glances and phone breaks.
  var eligible:=0
  var watching:=0
  var side_watching:=0
  for f in 2700:
   c._wait_motion_time=float(f)/60.0
   c._play_wait_stance()
   player.advance(1.0/60.0)
   life._process(1.0/60.0)
   var clip:=String(player.current_animation)
   if clip.begins_with("burger/Idle_") or clip=="burger/Impatient_Foot_Tap":
    eligible+=1
    if life.gaze_strength>.8:
     watching+=1
     if clip!="burger/Idle_Forward":side_watching+=1
   if f%120==0:await process_frame
  var duty:=float(watching)/maxf(1.0,float(eligible))
  print("GAZE_DUTY customer=",ci," ratio=",duty," side_frames=",side_watching)
  expect(duty>.70,"Tracking should cover most waiting-idle time")
  expect(side_watching>120,"Tracking should continue through other waiting idles")
  # Explicit impatient state must still look at the spatula.
  c._play_anim("burger:Impatient_Foot_Tap")
  for f in 120:life._process(1.0/60.0)
  expect(life.gaze_strength>.9,"Impatient customers must still follow the spatula")
  # Bring the actual hand/blade near the face during a scheduled gaze break.
  c._play_anim("burger:Idle_Forward")
  life.gaze_left=0.0
  life.gaze_cooldown=10.0
  life.with_head=false
  var near_target: Vector3=c.global_position+Vector3(0.35,1.3,-0.6)
  game.hand_spatula_root.global_position=near_target-game.hand_spatula_root.global_basis*game.HAND_SPATULA_TIP_OFFSET
  for f in 40:life._process(1.0/60.0)
  expect(life.gaze_strength>.95,"A close hand must override the scheduled gaze break")
  expect(life.look.look_weight>.8,"A close hand must also turn the head")
  expect(not mat.shader.code.contains("render_mode unshaded"),"Eyes must respond to scene lighting")
  expect(not life.modular.is_processing(),"Game customers must not run editor rig updates")
  # The glove remains a valid target above faces after the grill spatula hides.
  game.hand_spatula_root.hide()
  game.playing=true
  var above_screen: Vector2=game.camera.unproject_position(eye.global_position+Vector3(0,0.6,-1.0))
  var above_target: Vector3=game.customer_hand_attention_target(above_screen)
  expect(above_target.is_finite() and above_target.y>eyes.global_position.y,"Off-grill hand projection must preserve above-head height")
  var motion:=InputEventMouseMotion.new()
  motion.position=above_screen
  motion.global_position=above_screen
  game.get_viewport().warp_mouse(above_screen)
  for f in 3:await process_frame
  life.gaze_left=2.0
  for f in 40:life._process(1.0/60.0)
  expect(life.target_world.distance_to(above_target)<.01,"Hidden spatula must fall back to the visible glove cursor")
  expect(life.gaze_strength>.95,"Waiting customers must sometimes track the off-grill hand")
  expect((mat.get_shader_parameter("pupil_gaze") as Vector2).y>0.03,"Pupils must look upward at a hand above the face")
  game.hand_spatula_root.show()
  game.playing=false
  # Preserve intentional attention changes and cleanly return eyes to neutral.
  for state in ["burger:Phone_One_Hand","burger:Check_Watch"]:
   c._play_anim(state)
   for f in 30:life._process(1.0/60.0)
   expect(life.gaze_strength<.01,"Phone/watch must retain their own focus")
  c._play_anim("idle")
  c.is_leaving=true
  for f in 30:life._process(1.0/60.0)
  expect((mat.get_shader_parameter("pupil_gaze") as Vector2).length()<.001,"Leaving must restore neutral pupils")
  c.queue_free()
  for f in 3:await process_frame
 game.queue_free()
 for f in 5:await process_frame
 print("CUSTOMER_GAZE_OK" if failures.is_empty() else "CUSTOMER_GAZE_FAILED")
 quit(0 if failures.is_empty() else 1)
