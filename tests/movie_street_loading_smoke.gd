extends SceneTree
func _initialize() -> void: call_deferred("run")
func capture(name: String) -> void:
 if DisplayServer.get_name()=="headless": return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OS.get_environment("BURGER_PROBE_OUTPUT").path_join(name+".png"))
func midway() -> void:
 await create_timer(10.0).timeout
 await capture("loading_midway")
func run() -> void:
 create_timer(50).timeout.connect(func(): push_error("MOVIE_STREET_TIMEOUT");quit(1))
 root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720)
 var game=load("res://scenes/main.tscn").instantiate()
 game.set_script(load("res://tests/boot_media_harness.gd"))
 root.add_child(game);current_scene=game
 game._build_gameplay_loading_screen()
 await game._loading_video.prewarm()
 assert(game._loading_video.video.paused,"Movie must prewarm behind the menu")
 game._show_gameplay_loading_screen()
 game._gameplay_load_in_progress=true
 game._loading_screen_began_ms=Time.get_ticks_msec()
 midway()
 var began:=Time.get_ticks_msec()
 await game._play_loading_interlude()
 var seconds:=float(Time.get_ticks_msec()-began)/1000.0
 assert(seconds>=19.8 and seconds<24.0,"Play the complete twenty-second march once")
 assert(not game._loading_video.looping and game._loading_video.video.paused,"Keep the completed movie paused during preparation")
 var still:TextureRect=game._gameplay_load_overlay.get_node("LoadingStill")
 assert(still.visible and still.texture.get_size()==Vector2(1920,1080),"Show the matching full-resolution end-frame still")
 assert(game._gameplay_load_overlay.get_node("LoadingLettering").visible,"Preparation headline must return after playback")
 await capture("loading_preparation")
 game._hide_gameplay_loading_screen()
 assert(not game._loading_video.video.is_playing(),"Stop decoding once the loading screen closes")
 game.queue_free()
 for i in 8: await process_frame
 print("MOVIE_STREET_LOADING_OK duration=",seconds)
 quit()
