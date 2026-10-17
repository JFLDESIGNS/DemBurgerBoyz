extends SceneTree
func _initialize():call_deferred("run")
func run():
 create_timer(20).timeout.connect(func():quit(1))
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/scrape_ting_fixture.gd"));root.add_child(g);current_scene=g
 var audio=load("res://scripts/game_audio.gd").new();root.add_child(audio);audio.set_process(false);g.game_audio=audio
 audio.sfx_levels["tools"]=1.0
 g.grill_residue.resize(g.GRILL_SLOTS);g.grill_residue_centers.resize(g.GRILL_SLOTS);g.grill_residue_chunks.resize(g.GRILL_SLOTS)
 for i in g.GRILL_SLOTS:g.grill_residue[i]=1.0;g.grill_residue_centers[i]=Vector3.ONE;g.grill_residue_chunks[i]=[]
 var normal_index:int=audio._ting_player_i
 var index:int=audio._player_i
 for i in 8:g._scrape_residue_hit(0,Vector2.RIGHT,true)
 assert(g.dance_taps==0 and audio._ting_player_i==normal_index)
 assert(audio._player_i==(index+1)%audio._players.size(),"Rapid scrape chips play only one light ting")
 assert(is_equal_approx(db_to_linear(audio._players[index].volume_db),.527),"Cleaning accent stays below normal contact")
 assert(absf(audio._players[index].stream.get_length()-.09)<.002)
 audio._last_scrape_ting_ms=-10000
 g.mp_residue_chip(0,1,0,1,1,true)
 assert(g.dance_taps==0,"Replicated cleaning cannot trigger dancing")
 g.grill_roomba_tings_left=2;g.grill_roomba_ting_cool=0;g._roomba_maybe_clean_ting(Vector3.ONE)
 assert(g.dance_taps==0)
 audio._scrape_move_on=true;audio._scrape_ting_cool=0;audio._last_scrape_ting_ms=-10000
 audio._tick_scrape_tings(.1)
 assert(audio._ting_player_i==normal_index)
 audio.set_grill_scrape(false)
 audio._last_scrape_contact_ms=-10000
 normal_index=audio._ting_player_i
 audio.set_grill_scrape(true,true)
 assert(audio._ting_player_i==(normal_index+1)%audio._ting_players.size(),"Scrape start needs regular contact")
 for i in 10:audio.set_grill_scrape(true,true)
 assert(audio._ting_player_i==(normal_index+1)%audio._ting_players.size(),"Contact cannot repeat every frame")
 assert(g.dance_taps==0,"Contact must not trigger dancing")
 audio.set_grill_scrape(false)
 index=audio._player_i
 audio.play_debris_kuhh_burst(1)
 assert(audio._player_i==(index+1)%audio._players.size(),"Single debris release must always play")
 assert(db_to_linear(audio._players[index].volume_db)>.63)
 g._play_grill_tap_at(Vector3.ONE)
 assert(g.dance_taps==1,"Intentional musical taps still register normally")
 print("SCRAPE_TING_NO_DANCE_OK: audible release, regular contact, quiet accents, rate limit, local/remote cleaning, musical taps intact")
 g.game_audio=null;g.queue_free();audio.queue_free();await process_frame;quit()
