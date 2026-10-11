extends SceneTree
func _initialize():call_deferred("run")
func run():
 create_timer(240).timeout.connect(func():push_error("PET_GAME_TIMEOUT");quit(1))
 root.size=Vector2i(1280,720)
 var g=load("res://scenes/main.tscn").instantiate();root.add_child(g);current_scene=g
 while not g.menu_ready:await process_frame
 await g._start_game()
 g._clear_bts_day_intro(false);g._bts_day1_performance_done=true;g._boss_intro_running=false;g.spawn_timer=99999

 AudioServer.set_bus_mute(0,true)
 g._phone_expanded=false;g.options_menu_open=false;g.shift_paused=false
 var audio_bus=AudioServer.bus_count;AudioServer.add_bus();AudioServer.set_bus_name(audio_bus,"StretchProbe")
 var capture=AudioEffectCapture.new();capture.buffer_length=3.0;AudioServer.add_bus_effect(audio_bus,capture)
 var origin:Vector2=g.ingredient_buttons["onion"].get_global_rect().get_center()
 print("REAL_PULL origin=",origin," hit=",g._strip_ingredient_at(origin)," game_audio=",g.game_audio)
 var press=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.position=origin
 g._input(press)
 var move=InputEventMouseMotion.new();move.position=origin+Vector2(0,65);g._input(move)
 var sling=g._ingredient_slingshot
 print("REAL_PULL pulling=",sling.pulling," player=",sling.stretch_player)
 assert(sling.pulling and is_instance_valid(sling.stretch_player))
 sling.stretch_player.bus="StretchProbe"
 await create_timer(.8).timeout
 var samples=capture.get_buffer(capture.get_frames_available());var energy=0.0
 for v in samples:energy+=v.length_squared()*.5
 print("REAL_PULL samples=",samples.size()," rms=",sqrt(energy/maxi(1,samples.size()))," playing=",sling.stretch_player.playing," pulling=",sling.pulling)
 assert(energy>0.001)
 print("REAL_PULL_OUTPUT_OK")
 quit()
