extends SceneTree
func _initialize(): call_deferred("run")
func run():
 var game = load("res://scenes/main.tscn").instantiate()
 print("FULL_SERVE_SCENE_INSTANTIATED")
 root.add_child(game)
 print("FULL_SERVE_SCENE_READY")
 current_scene = game
 await process_frame
 print("FULL_SERVE_LOADING")
 await game._start_game()
 print("FULL_SERVE_LOADED")
 game.playing = false
 game.spawn_timer = 9999.0
 for c in game.customers.duplicate():
  game._remove_ticket(c)
  c.queue_free()
 game.customers.clear()
 var preset = {"format_version":8,"name":"Serve timing","top_catalog_version":1,"top_style":1,"bottom_catalog_version":1,"bottom_style":2,"shoe_catalog_version":1,"shoe_style":1,"hair_style":12}
 var measurements = []
 for app in ["home","social"]:
  game._set_phone_app(app)
  game._spawn_customer_local(["bun_bottom","patty","bun_top"],Color.WHITE,9999.0,0,-1,0,0,false,-1,false,preset,true)
  var c = game.customers.back()
  c.position.x = c.target_x
  c.is_waiting = true
  c.set_process(false)
  game._create_ticket(c)
  game.selected_customer = c
  var p = game._take_prewarmed_patty()
  assert(p != null)
  p.set_process(false)
  p.cook_time = 8.0
  p.first_side_time = 8.0
  p.flipped_once = true
  game.stations[0]["items"] = ["bun_bottom","patty","bun_top"] as Array[String]
  game.stations[0]["patties"] = [p]
  game._refresh_station(0)
  for i in 60: await process_frame
  await RenderingServer.frame_post_draw
  var before_money = game.money
  var before_reviews = game.social_reviews.size()
  var start = Time.get_ticks_usec()
  game._complete_serve(0,c)
  var commit_ms = (Time.get_ticks_usec()-start)/1000.0
  var gaps = []
  var last = Time.get_ticks_usec()
  for i in 50:
   await process_frame
   var now = Time.get_ticks_usec()
   var frame_ms = (now-last)/1000.0
   gaps.append(frame_ms)
   if frame_ms > 40.0: print("SERVE_FRAME ",app," frame=",i," ms=",frame_ms," process_ms=",Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
   last = now
  assert(game.money > before_money,"Serving must still pay the customer ticket")
  assert(not game.tickets.has(c),"Served customer's ticket must be removed")
  assert(game.social_reviews.size() > before_reviews,"Serving must still publish the review")
  c._apply_leave_fade_alpha(0.5)
  for i in 10: await process_frame
  gaps.sort()
  measurements.append({"phone_app":app,"commit_ms":commit_ms,"post_serve_p50_ms":gaps[25],"post_serve_max_ms":gaps.back()})
 print("FULL_SERVE_PROFILE ",JSON.stringify(measurements))
 print("FULL_SERVE_HOT_PATHS ",JSON.stringify(game.get_performance_hot_path_stats()))
 print("FULL_SERVE_PIPELINE_OK")
 game.queue_free()
 for i in 3: await process_frame
 quit()
