extends SceneTree
func _initialize():call_deferred("run")
func run():
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/audio_scrape_fixture.gd"));root.add_child(g);current_scene=g
 g.grill_residue.resize(g.GRILL_SLOTS);g.grill_residue_centers.resize(g.GRILL_SLOTS);g.grill_residue_chunks.resize(g.GRILL_SLOTS);g.grill_residue_kind.resize(g.GRILL_SLOTS)
 for i in g.GRILL_SLOTS:
  g.grill_residue_chunks[i]=[];g.grill_residue[i]=0.0;g.grill_residue_centers[i]=Vector3.ZERO
 g.grill_residue[0]=1.0;g.grill_residue[1]=1.0
 g.grill_residue_centers[0]=Vector3(1,0,2);g.grill_residue_centers[1]=Vector3(1.12,0,2)
 g._scrape_finish_clean_at(0,1,2)
 assert(g.grill_residue[0]==0 and g.grill_residue[1]==1,"Single-player cleaning must preserve neighboring pile")
 g.mp_residue_clean(0,1,2);g.mp_residue_amt(0,0,1,2);g.mp_residue_chip(0,1,0,1,2,false)
 assert(g.grill_residue[1]==1,"Late/duplicate cleanup messages cannot jump to nearby pile")
 g.grill_residue_centers[0]=Vector3(5,0,5);g.grill_residue[0]=1
 g.mp_residue_amt(0,.6,1.12,2)
 assert(is_equal_approx(g.grill_residue[1],.6) and g.grill_residue[0]==1,"Different peer slot resolves by exact position")
 g.mp_residue_clean(0,1.12,2)
 assert(g.grill_residue[1]==0 and g.grill_residue[0]==1)
 g.mp_residue_amt(0,.5)
 assert(g.grill_residue[0]==.5,"Slot-only bootstrap remains supported")
 var audio=load("res://scripts/game_audio.gd").new();root.add_child(audio);g.game_audio=audio
 audio.sfx_levels["ingredients"]=1.0
 var idx:int=audio._player_i;audio.play_condiment_squirt("ketchup")
 var ketchup:AudioStreamPlayer=audio._players[idx]
 assert(absf(ketchup.stream.get_length()-.525)<.003)
 assert(is_equal_approx(db_to_linear(ketchup.volume_db),.56))
 idx=audio._player_i;audio.play_condiment_squirt("mustard")
 assert(absf(audio._players[idx].stream.get_length()-1.05)<.003,"Mustard keeps its recording")
 for i in g.STATION_COUNT:g.stations.append({"items":[],"preview":null})
 var done:=[false]
 g._play_ingredient_fly_to_build("tomato",0,func():done[0]=true,Vector2(100,100))
 idx=audio._player_i
 await create_timer(.15).timeout
 assert(not done[0] and audio._player_i==idx,"No impact before ingredient arrives")
 await create_timer(.4).timeout
 assert(done[0] and audio._player_i==(idx+1)%audio._players.size(),"One impact at completed flight")
 assert(is_equal_approx(db_to_linear(audio._players[idx].volume_db),.28),"Landing remains soft")
 print("AUDIO_SCRAPE_OK: half ketchup, quieter gain, landing timing, exact grime target, duplicate protection")
 g.game_audio=null;audio.queue_free();g.queue_free();await process_frame;quit()
