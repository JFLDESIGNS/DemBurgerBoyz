extends SceneTree
class QuietProbe extends "res://scripts/game_audio.gd":
 func _ready(): pass
 func _process(_delta): pass
func _initialize():call_deferred("run")
func run():
 var audio=QuietProbe.new();root.add_child(audio)
 audio.set_roomba_wawawa(true)
 assert(audio._roomba_wawawa_player.volume_db<=-18)
 await create_timer(.6).timeout
 assert(not audio._roomba_wawawa_player.playing,"Distress must stop instead of looping")
 audio.set_roomba_wawawa(true)
 assert(not audio._roomba_wawawa_player.playing,"Repeated stuck updates must not restart the voice")
 audio.set_roomba_wawawa(false)
 print("ROBO_QUIET_OK")
 quit()
