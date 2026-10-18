extends SceneTree
func _initialize():call_deferred("run")
func run():
 var radio=load("res://scripts/truck_radio.gd").new();root.add_child(radio)
 var previous=-1
 for cycle in 100:
  var heard=[]
  for i in 4:
   var index=radio._next_local_track()
   assert(index!=previous and not heard.has(index))
   heard.append(index);previous=index
 for path in radio.LOCAL_TRACKS:
  var stream=load(path)
  assert(stream is AudioStreamMP3 and stream.get_length()>1.0)
 radio.set_powered(true)
 assert(radio._is_local_station() and radio._player.playing and not radio._player.stream.loop)
 var first=radio._last_local_track
 radio._on_playback_finished()
 assert(radio._last_local_track!=first and radio._player.playing)
 radio.set_combat_silence(true);assert(radio._player.volume_db==-80)
 radio.set_combat_silence(false)
 radio.set_powered(false);assert(not radio._player.playing)
 print("RADIO_SHUFFLE_OK: all four per cycle, no consecutive repeat, playback and controls")
 quit()
