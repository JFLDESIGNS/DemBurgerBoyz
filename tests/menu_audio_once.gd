extends SceneTree
func _initialize():call_deferred("run")
func run():
 create_timer(35).timeout.connect(func():push_error("MENU_AUDIO_TIMEOUT");quit(1))
 var music=root.get_node("IntroBootMusic")
 music.play_intro_voice();music.play_intro_voice();music.play_intro_voice()
 assert(music.intro_voice_play_count==1 and music.intro_voice.playing)
 var truck=load("res://scripts/truck_cinematic.gd").new();root.add_child(truck)
 for n in 4:await process_frame
 truck.play_departure()
 while truck.cat_leaving:await process_frame
 var sounds=truck.find_children("*","AudioStreamPlayer",true,false)
 assert(sounds.size()==1 and sounds[0].playing)
 truck.play_departure()
 assert(truck.find_children("*","AudioStreamPlayer",true,false).size()==1)
 await truck.departure_finished
 print("MENU_AUDIO_OK: voice once, departure screech once")
 truck.queue_free();await process_frame;quit()
