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
 expect(int(game.get_meta("loading_movie_count", 0)) == 1,"Play one complete crossing before loading")
 expect(int(game.get_meta("loading_first_batch_ms", 0)) >= 19800,"No gameplay preparation before the first crossing finishes")
 expect(int(game.get_meta("loading_item_preparation_ms",0)) >= 35000,"Prepare items for thirty-five seconds after the full clip")
 print("LOADING_SCHEDULE first_play_ms=",game.get_meta("loading_first_play_ms")," movies=",game.get_meta("loading_movie_count")," durations_ms=",game.get_meta("loading_movie_durations_ms"))
 expect(game.get_meta("loading_video_complete", false),"Loading presentation must be marked complete when gameplay is ready")
 expect(game._loading_video.video_path.ends_with("burger_pals_night_loading.ogv"),"New muted Technicolor clip must be loaded")
 print("LOADING_FIRST_CROSSING_THEN_OFFSCREEN_PREPARATION")
 expect(game._kitchen_ready and game._gameplay_load_complete,"Kitchen and resources must finish loading")
 expect(game._gameplay_resource_cache.has(game.REFINED_SOFT_SERVE_PATH),"Soft serve model must load off the main thread before kitchen construction")
 var mascot: Node3D = game.icecream_root.get_node_or_null("IceCreamMascot")
 expect(is_instance_valid(mascot),"Newer cone mascot must be restored to the machine roof")
 expect(mascot.get_node("Visual").scene_file_path == game.ICECREAM_MASCOT_SCENE,"Machine topper must use the newer cone")
 var rotation_before: float = mascot.rotation.y
 game._update_icecream_mascot_spin(1.0)
 expect(not is_equal_approx(rotation_before,mascot.rotation.y),"Machine topper must rotate")
 expect(game._background_load_complete,"Audio and character warmups must finish before the boss introduction")
 expect(game._runtime_prewarm_complete,"Runtime warmups must finish before gameplay")
 game._start_game_immediate(false)
 for i in 90: await process_frame
 expect(game.playing,"Gameplay must start after the staged load")
 expect(game.shaker_root.get_meta("pickup_render_warmed",false),"Shaker particles must render during loading before first pickup")
 var pickup_began := Time.get_ticks_usec()
 game._begin_shaker_hold()
 print("SHAKER_PICKUP_CPU_MS ",float(Time.get_ticks_usec()-pickup_began)/1000.0)
 expect(game.shaker_held,"Seasoning shaker must remain grabbable")
 game._cancel_shaker_hold_silent()
 var fixtures=game.world.get_node("CeilingFixtures")
 var lights=fixtures.find_children("CeilingDownlight","SpotLight3D",true,false)
 expect(game.gfx_env.ssao_enabled,"Contact AO enabled")
 expect(lights.size()==4,"Four real ceiling lights")
 expect(fixtures.find_children("EmissiveDiffuser","MeshInstance3D",true,false).size()==4,"Four glowing diffusers")
 expect(game.shaker_root.has_node("SeasoningTapedLabel"),"Seasoning label")
 expect(game.oil_root.has_node("OilTapedLabel"),"Oil label")

 var cash_before: float = game.money
 var cost_before: float = game.shift_ingredient_cost
 game.supply_stock["bacon"] = 4
 expect(game._try_use_supply("bacon",2),"Consume stocked ingredients")
 expect(is_equal_approx(game.shift_ingredient_cost-cost_before,4.0),"Ingredient cost follows actual shop prices")
 expect(is_equal_approx(game.money,cash_before),"Usage must not charge wallet twice")
 var guest = game.CustomerScript.new()
 var recipe: Array[String] = ["bun_bottom","patty","bun_top"]
 guest.setup(recipe,Color.WHITE,100.0,0,0,0,-1)
 guest.set_meta("profit_built",["bun_bottom","patty","bacon","bun_top"])
 expect(is_equal_approx(game._order_food_cost(guest),2.75),"Cost actual served extras, not just requested recipe")
 guest.free()
 game.shift_food_sales = 20.0
 game.shift_tips = 2.0
 game.shift_ingredient_cost = 4.0
 game.last_day_cut = 10.0
 expect(game._format_day_cut_recap().contains("Net food profit: $8.00"),"Daily net includes food cost and boss cut")
 game._show_order_profit(10.0,2.75)
 expect(game._shift_events.profit_label.text.contains("$7.25"),"Order profit display")
 game._boss_intro_seq += 1
 game._boss_pep_pending = false
 game._boss_intro_running = false
 game.set_process(false)
 game._shift_events.set_process(false)
 if is_instance_valid(game._cut_collector):
  game._cut_collector.queue_free()
  await process_frame
 game.get_node("UI/Root").hide()
 for diffuser in fixtures.find_children("EmissiveDiffuser","MeshInstance3D",true,false):
  expect(diffuser.mesh is BoxMesh,"Squared ceiling diffuser")
 game._start_burger_pals_parade("challenge")
 expect(game._parade_presentation.remaining > 4.0 and game._parade_presentation.remaining <= 5.0,"Five second film effect")
 expect(game.burger_pals_parade.find_children("ParadeFullCola","",true,false).is_empty(),"No parade drinks")
 expect(game.burger_pals_parade.find_children("ParadeFinishedFries","",true,false).is_empty(),"No parade fries")
 expect(game.challenge_banner.visible,"Small challenge banner at start")
 game.burger_pals_parade.advance_parade(6.0)
 game.burger_pals_parade.set_process(false)
 await create_timer(.3).timeout
 if DisplayServer.get_name() != "headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://build/light_balance_release/vintage_parade.png")
 game._parade_presentation._process(5.0)
 expect(not game._parade_presentation.screen.visible,"Film expires at five seconds")
 await create_timer(.1).timeout
 if DisplayServer.get_name() != "headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://build/light_balance_release/parade_color.png")
 game._stop_burger_pals_parade()
 game.get_node("UI/Root").show()
 game._show_challenge_banner("THREE PALS. ONE EPIC ORDER!",Color(1,.86,.53),5)
 await create_timer(.5).timeout
 if DisplayServer.get_name() != "headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://build/light_balance_release/vintage_challenge.png")
 game.get_node("UI/Root").hide()
 for style in 3:
  game._shift_events.boss_peek(style)
  game._shift_events._update_boss_gaze(.1)
  await create_timer(.9).timeout
  expect(is_instance_valid(game._shift_events.visit),"Boss peek exists")
  if is_instance_valid(game._shift_events.visit):
   var peek_boss=game._shift_events.visit.get_child(0).get_child(0)
   expect(not peek_boss._char_meshes.is_empty(),"Complete boss model retained")
   for part in peek_boss._char_meshes:
    expect(part.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Offscreen peek body cannot shadow opposite cart side")
   print("PEEK_POSE ",style," ",game._shift_events.visit.global_position," HEAD ",game._shift_events.visit.get_child(0).get_child(0)._collector_head_host().global_position)
  if DisplayServer.get_name() != "headless":
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://build/light_balance_release/boss_peek_%d.png" % style)
  await create_timer(3.0).timeout
  expect(not is_instance_valid(game._shift_events.visit),"Boss leaves after peeking")
 game.window_cat.special_people_peek(10.0)
 game.grill_on = true
 game._spawn_patty_at(0,Vector3(game.GRILL_CENTER_X,game.GRILL_SURFACE_Y,game.GRILL_SURFACE_Z))
 await create_timer(.8).timeout
 var patty = game.grill[0]
 expect(not game._shift_events.eligible_patty(patty),"Center patties safe")
 patty.global_position.z = game.GRILL_SURFACE_Z + game.GRILL_DEPTH*.5-.04
 expect(game._shift_events.eligible_patty(patty),"Back edge exposed")
 patty.global_position.x = game.GRILL_CENTER_X + game.GRILL_WIDTH*.4
 patty.global_position.z = game.GRILL_SURFACE_Z
 expect(game._shift_events.eligible_patty(patty),"Side patties exposed")
 game.dragging_patty = patty
 expect(not game._shift_events.eligible_patty(patty),"Player-held patties safe")
 game.dragging_patty = null
 patty._rest_x = patty.global_position.x
 patty._rest_z = patty.global_position.z
 game._shift_events.steal_patty(patty)
 await create_timer(1.10).timeout
 expect(game.world.has_node("CatStealingTongue"),"Cat extends red tongue to patty")
 if DisplayServer.get_name() != "headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://build/light_balance_release/cat_tongue.png")
 expect(game.grill[0] == null,"Stolen patty clears grill slot immediately")
 await create_timer(.9).timeout
 expect(is_instance_valid(patty) and not patty.visible and game._patty_spawn_pool.has(patty),"Stolen patty recycled after mouth flight")
 game.stations[0]["items"] = ["bun_bottom","patty"]
 for flavor in ["ketchup","mustard"]:
  game.supply_stock[flavor] = 5
  var bottle: Node3D = game.condiment_bottle_roots[flavor]
  var before: Vector3 = bottle.position
  game._request_condiment_add(flavor,0)
  await create_timer(.3).timeout
  expect(game._condiment_auto_active.has(flavor),"Condiment still traveling visibly")
  expect(game._station_sauce_in_flight(0),"Auto serve waits for visible squeeze")
  expect(bottle.position.distance_to(before) > .05,"Condiment bottle moves toward burger")
  await create_timer(1.8).timeout
  expect(not game._condiment_auto_active.has(flavor),"Condiment completes flight and returns")
  expect(not game._station_sauce_in_flight(0),"Auto serve unblocks after squeeze")
 expect(game._shift_events.profit_label.z_index > game.phone_column.z_index,"Profit above phone")
 expect(game._cached_tip_bill_material(true).shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL,"Jar bills receive shading")
 game.shift_food_sales=227.0
 game.shift_tips=61.0
 game.shift_ingredient_cost=72.75
 game.total_served=19
 game.perfect_serves=6
 var sun_before: float=game.gfx_sun.light_energy
 game.get_node("UI/Root").show()
 game.day_social_reviews=[{"stars":5,"who":"Sage","text":"I sat in my car for five minutes to process that burger. Calling the lunch insane."},{"stars":2,"who":"Drew","text":"Great fries, but my burger needed a little more time on the grill."}]
 game.day_social_rating_sum=7.0
 game._end_day()
 await create_timer(8).timeout
 game._show_parade_shift_results()
 expect(game._shift_results.active,"Night presentation active")
 expect(game.gfx_sun.light_energy < sun_before*.2,"Sun sets at closing")
 expect(not game._parade_presentation.screen.visible,"No black and white overlay at closing")
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/light_balance_release/night_results.png")
 await create_timer(4.5).timeout
 expect(is_equal_approx(float(game._shift_results.screen.material.get_shader_parameter("blackout")),1.0),"Night fades fully to black")
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/light_balance_release/black_results.png")
 game._shift_results.restore()
 expect(game.game_over_panel.get_parent()==game.get_node("UI/Root"),"Recap restored to normal UI hierarchy")
 expect(is_equal_approx(game.gfx_sun.light_energy,sun_before),"Sun restored for next shift")
 print("VINTAGE_PRESENTATION_OK")
 game.queue_free()
 for i in 8: await process_frame
 quit()
func expect(ok: bool,msg: String):
 if not ok:
  push_error(msg)
  quit(1)
