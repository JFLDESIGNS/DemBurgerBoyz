extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var splash=load("res://scripts/pal_company_splash.gd").new()
 root.add_child(splash)
 assert(abs(splash.VOICE.get_length()-4.5)<0.03)
 await create_timer(0.75).timeout
 assert(splash.voice_started and splash.voice.playing)
 assert(splash.get("caption")==null,"No spoken dialogue captions")
 var output=OS.get_environment("PAL_PREVIEW_OUTPUT")
 if not output.is_empty() and DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(output)
 await create_timer(2.5).timeout
 assert(splash.voice.playing)
 await create_timer(1.55).timeout
 assert(not splash.voice.playing,"Voice must finish within five-second splash")
 splash.hide();assert(not splash.voice.playing)
 splash.queue_free();await process_frame
 print("PAL_ROBOT_SPLASH_OK");quit()
