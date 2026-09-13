extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	create_timer(45).timeout.connect(func(): push_error("LOADING_SPEED_TIMEOUT");quit(1))
	var game=load("res://scenes/main.tscn").instantiate()
	game.set_script(load("res://tests/boot_media_harness.gd"))
	root.add_child(game);current_scene=game
	game.game_audio=load("res://scripts/game_audio.gd").new()
	game.add_child(game.game_audio)
	game._build_gameplay_loading_screen()
	game._show_gameplay_loading_screen()
	assert(game.game_audio.cat_sounds_muted)
	var index_before:int=game.game_audio._player_i
	game.game_audio.play_cat_meow();game.game_audio.play_cat_begging_meow();game.game_audio.play_cat_purr()
	assert(game.game_audio._player_i==index_before)
	game._gameplay_load_in_progress=true
	game._loading_screen_began_ms=Time.get_ticks_msec()
	var start:=Time.get_ticks_msec()
	await game._play_loading_interlude()
	assert(Time.get_ticks_msec()-start<1500,"Loading must not wait for the full movie")
	game._loading_batch_began_ms=Time.get_ticks_msec()-30000
	start=Time.get_ticks_msec();await game._loading_batch_checkpoint()
	assert(Time.get_ticks_msec()-start<1500,"Batch checkpoints must not replay the full movie")
	assert(game._loading_video.looping)
	game._hide_gameplay_loading_screen()
	assert(not game.game_audio.cat_sounds_muted)
	print("LOADING_SPEED_SMOKE_OK");quit()
