extends SceneTree
func _initialize(): call_deferred("run")
func run():
 create_timer(150).timeout.connect(func(): push_error("REGRESSION_TIMEOUT"); quit(1))
 var game = load("res://scenes/main.tscn").instantiate()
 game.set_script(load("res://tests/main_ticket_harness.gd"))
 root.add_child(game)
 current_scene = game
 game._seed_first_run_configs()
 game._style_static_labels()
 game._setup_stations_data()
 await game._initialize_kitchen()
 await game._ensure_patty_spawn_pool()
 await game._prewarm_patty_fridge_place()
 game.playing = true
 game.grill_on = true
 game.supply_stock["patty"] = 20
 var aim = Vector3(game.GRILL_CENTER_X,game.GRILL_SURFACE_Y,game.GRILL_SURFACE_Z)
 game._try_place_patty_at(aim)
 game._try_place_patty_at(aim)
 game._try_place_patty_at(aim)
 assert(game._fridge_launch_inflight == 1,"Repeated clicks launched duplicate flights")
 assert(game.supply_stock.patty == 19,"Repeated clicks consumed extra patties")
 assert(game._first_empty_slot() == 1,"Airborne patty did not reserve its slot")
 game._try_place_patty_at(aim + Vector3(game.PATTY_MIN_SEP * 1.5,0,0))
 assert(game._fridge_launch_inflight == 2,"Distinct destinations should allow parallel flights")
 await create_timer(0.6).timeout
 assert(game._fridge_pending_places.is_empty())
 assert(game.grill[0] != null and game.grill[1] != null,"Both accepted flights must land")
 game._challenge_count = 3
 game._challenge_phase = "offer"
 game._accept_challenge()
 var c = game._challenge_customer
 assert(is_instance_valid(c))
 c.is_waiting = true
 c.set_process(false)
 game._on_customer_arrived(c)
 assert(game.tickets.has(c))
 for i in 2:
  game._begin_customer_serve_handoff(c)
  assert(game.tickets.has(c),"Challenge ticket vanished at handoff")
  c.set_meta("burger_in_flight",true)
  game.stations[game.STATION_CRAFT]["items"] = Array(c.order)
  game._complete_challenge_serve(game.STATION_CRAFT,c)
  assert(game._challenge_remaining == 2-i)
  game._customer_burger_arrived(c)
  assert(game._order_can_receive_burger(c),"Challenge cannot receive its next burger")
  assert(not c.is_leaving)
 game._begin_customer_serve_handoff(c)
 game.stations[game.STATION_CRAFT]["items"] = Array(c.order)
 game._complete_challenge_serve(game.STATION_CRAFT,c)
 assert(game._challenge_phase == "","Final burger must finish the challenge")
 print("CHALLENGE_PATTY_OK duplicate clicks, slot reservations, landings, full challenge")
 quit()
