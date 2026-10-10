extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(600,600)
 var actor=load("res://scenes/character_creator/modular_character_base.tscn").instantiate();root.add_child(actor);actor.scale=Vector3.ONE*100.0
 await process_frame
 var speech=load("res://scripts/customer_mouth_speech.gd").new();actor.add_child(speech);speech.start(1.15);speech.set_process(false)
 assert(speech.materials.size()>0,"Authored character mouth must support speech")
 var peak=0.0
 for i in 60:
  speech._process(1.0/60.0);peak=maxf(peak,speech.amount)
 assert(peak>.75,"Speech must reach a visibly round shape")
 for i in 90:speech._process(1.0/60.0)
 assert(speech.amount==0 and not speech.is_processing(),"Normal mouth restored after speech")
 if DisplayServer.get_name()!="headless":
  var mouth=actor._mouth_root.get_child(0)
  var camera=Camera3D.new();root.add_child(camera);camera.position=mouth.global_position+mouth.global_basis.z.normalized()*maxf(.55,mouth.get_aabb().size.x*mouth.global_basis.get_scale().x*4.0);camera.look_at(mouth.global_position);camera.current=true
  var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("544B45");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.9;root.add_child(env)
  for amount in [0.0,1.0]:
   for material in speech.materials:material.set_shader_parameter("speech_round",amount)
   for i in 4:await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://build/customer_polish_qa/mouth_%d.png"%int(amount))
 print("MOUTH_SPEECH_OK: shader morph, syllable opening, normal-mouth restoration")
 quit()
