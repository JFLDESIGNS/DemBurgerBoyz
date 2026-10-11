extends SceneTree
func _initialize():call_deferred("run")
func run():
 var audio=load("res://scripts/game_audio.gd").new();root.add_child(audio)
 audio.sfx_levels["ingredients"]=1.0;audio.sfx_levels["customers"]=1.0
 var original:AudioStreamWAV=audio._stretch_recording()
 var loop:AudioStreamWAV=audio._stretch_recording(true)
 assert(original!=null and loop!=null and original!=loop)
 assert(original.loop_mode==AudioStreamWAV.LOOP_DISABLED)
 assert(loop.loop_mode==AudioStreamWAV.LOOP_FORWARD)
 assert(loop.loop_begin>int(loop.mix_rate) and loop.loop_end==65024)
 assert(is_equal_approx(original.get_length(),65024.0/44100.0))
 assert(audio._stretch_recording(true)==loop,"Loop resource reused")
 var player:AudioStreamPlayer=audio.start_slingshot_stretch()
 await create_timer(1.9).timeout
 assert(player.playing,"Held stretch continues beyond recording duration")
 assert(is_equal_approx(player.pitch_scale,1.0),"Supplied recording keeps its original pitch")
 var release_index:int=audio._player_i
 audio.play_slingshot_release()
 var release_player:AudioStreamPlayer=audio._players[release_index]
 assert(release_player.stream==audio._slingshot_release_recording())
 assert(release_player.stream.loop_mode==AudioStreamWAV.LOOP_DISABLED)
 assert(release_player.stream.get_length()<=.301 and is_equal_approx(release_player.pitch_scale,1.0))
 var cat_index:int=audio._player_i
 audio.play_cat_eating_stretch()
 var cat:AudioStreamPlayer=audio._players[cat_index]
 assert(cat.stream==original and cat.stream.loop_mode==AudioStreamWAV.LOOP_DISABLED)
 assert(is_equal_approx(cat.volume_db, audio._sfx_db(audio.STRETCH_BASE_DB, "ingredients") + linear_to_db(.5)), "Cat keeps its original quiet gain")
 assert(player.volume_db > cat.volume_db + 12.0, "Ingredient stretch must be clearly audible")
 var sling=load("res://scripts/ingredient_slingshot.gd").new();root.add_child(sling)
 sling.stretch_player=player;sling.cancel()
 assert(not player.playing,"Release/cancel stops the loop immediately")
 await process_frame
 assert(not is_instance_valid(player))
 player=audio.start_slingshot_stretch();sling.stretch_player=player
 sling.queue_free();await process_frame
 assert(not is_instance_valid(player) or not player.playing,"Removing the sling cannot leave an orphan loop")
 await create_timer(1.6).timeout
 assert(not cat.playing,"Cat sound is a one-shot")
 var before:int=audio._player_i;audio.cat_sounds_muted=true;audio.play_cat_eating_stretch()
 assert(audio._player_i==before)
 print("STRETCH_AUDIO_OK: original recording, tail-only sustain, preserved cat gain, release/cancel/exit cleanup, mute")
 audio.queue_free();await process_frame;quit()
