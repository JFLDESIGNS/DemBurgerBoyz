extends SceneTree
var samples: Array[float] = []
var video_samples: Array[float] = []
var video_start := 0
var measuring := false
var previous := 0
var previous_movie := 0
func _initialize(): call_deferred("run")
func _process(_delta: float) -> bool:
 if measuring:
  var now:=Time.get_ticks_usec()
  var ms := float(now-previous)/1000.0
  samples.append(ms)
  if current_scene.get_meta("loading_phase", "") == "video_playback":
   var movie: int = int(current_scene.get_meta("loading_movie_count", 0))
   if video_start == 0: video_start = now
   if previous_movie == movie: video_samples.append(ms)
   previous_movie = movie
  if ms>100: print("LOAD_STALL ",ms," phase=",current_scene.get_meta("loading_phase", "")," step=",current_scene.get_meta("loading_step", ""))
  previous=now
 return false
func run() -> void:
 create_timer(360).timeout.connect(func(): push_error("FULL_LOAD_TIMEOUT");quit(1))
 var intro=load("res://scenes/boot_intro.tscn").instantiate()
 root.add_child(intro)
 current_scene=intro
 intro.skip_intro()
 while current_scene==intro or current_scene==null: await process_frame
 var game=current_scene
 expect(not game._kitchen_ready,"Kitchen must not delay the menu")
 expect(game._loading_video.video.paused,"Loading video must already be decoded in the menu")
 previous=Time.get_ticks_usec()
 measuring=true
 await game._run_comprehensive_gameplay_load()
 measuring=false
 expect(int(game.get_meta("loading_first_play_ms", 99999)) < 1500,"Movie must start immediately, before heavy preparation")
 expect(int(game.get_meta("loading_movie_count", 0)) == 1,"Start the movie once; loading must not wait for interludes")
 print("LOADING_SCHEDULE first_play_ms=",game.get_meta("loading_first_play_ms")," movies=",game.get_meta("loading_movie_count")," durations_ms=",game.get_meta("loading_movie_durations_ms"))
 expect(game.get_meta("loading_video_complete", false),"Loading presentation must be marked complete when gameplay is ready")
 expect(game._loading_video.video_path.ends_with("burger_pals_loading_16.ogv"),"New muted Technicolor clip must be loaded")
 print("LOADING_MOVIE_RUNS_ALONGSIDE_PREPARATION")
 expect(game._kitchen_ready and game._gameplay_load_complete,"Kitchen and resources must finish loading")
 expect(game._gameplay_resource_cache.has(game.REFINED_SOFT_SERVE_PATH),"Soft serve model must load off the main thread before kitchen construction")
 var mascot: Node3D = game.icecream_root.get_node_or_null("IceCreamMascot")
 expect(is_instance_valid(mascot),"Newer cone mascot must be restored to the machine roof")
 expect(mascot.get_node("Visual").scene_file_path == game.ICECREAM_MASCOT_SCENE,"Machine topper must use the newer cone")
 var rotation_before: float = mascot.rotation.y
 game._update_icecream_mascot_spin(1.0)
 expect(not is_equal_approx(rotation_before,mascot.rotation.y),"Machine topper must rotate")
 game._start_game_immediate(false)
 for i in 90: await process_frame
 expect(game.playing,"Gameplay must start after the staged load")
 expect(game.shaker_root.get_meta("pickup_render_warmed",false),"Shaker particles must render during loading before first pickup")
 var pickup_began := Time.get_ticks_usec()
 game._begin_shaker_hold()
 print("SHAKER_PICKUP_CPU_MS ",float(Time.get_ticks_usec()-pickup_began)/1000.0)
 expect(game.shaker_held,"Seasoning shaker must remain grabbable")
 game._cancel_shaker_hold_silent()
 var output := OS.get_environment("BURGER_PROBE_OUTPUT")
 if not output.is_empty() and DisplayServer.get_name() != "headless":
  game.set_process(false)
  game.get_node("UI/Root").hide()
  game.icecream_root.show()
  var roof: Vector3 = mascot.global_position + Vector3.UP * 0.12
  var preview_camera := Camera3D.new()
  game.world.add_child(preview_camera)
  preview_camera.global_position = roof + Vector3(0.7,0.25,-1.0)
  preview_camera.look_at(roof)
  preview_camera.make_current()
  for i in 4: await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(output.path_join("restored_cone_mascot.png"))
 samples.sort()
 print("LOADING_FRAMES median_ms=",samples[samples.size()/2]," p95_ms=",samples[int(samples.size()*.95)]," max_ms=",samples[-1])
 video_samples.sort()
 if video_samples.size()>5:
  print("MOVIE_FRAMES p95_ms=",video_samples[int(video_samples.size()*.95)]," max_ms=",video_samples[-1])

 print("FULL_LOAD_OK")
 game.queue_free()
 for i in 8: await process_frame
 quit()
func expect(ok: bool,msg: String):
 if not ok:
  push_error(msg)
  quit(1)
