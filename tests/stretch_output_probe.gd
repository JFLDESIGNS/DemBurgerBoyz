extends SceneTree
func _initialize():call_deferred("run")
func run():
 AudioServer.set_bus_mute(0,true)
 var audio=load("res://scripts/game_audio.gd").new();root.add_child(audio)
 var idx=AudioServer.bus_count;AudioServer.add_bus();AudioServer.set_bus_name(idx,"StretchProbe");AudioServer.set_bus_send(idx,"Master")
 var capture=AudioEffectCapture.new();capture.buffer_length=3.0;AudioServer.add_bus_effect(idx,capture)
 var player=audio.start_slingshot_stretch();player.bus="StretchProbe"
 await create_timer(.8).timeout
 var frames=capture.get_buffer(capture.get_frames_available());var peak=0.0;var energy=0.0
 for v in frames:peak=maxf(peak,maxf(absf(v.x),absf(v.y)));energy+=v.length_squared()*.5
 print("STRETCH_OUTPUT frames=",frames.size()," peak=",peak," rms=",sqrt(energy/maxi(1,frames.size()))," playing=",player.playing," position=",player.get_playback_position())
 print("BUS mute=",AudioServer.is_bus_mute(0)," master_db=",AudioServer.get_bus_volume_db(0)," stretch_db=",player.volume_db)
 quit()
