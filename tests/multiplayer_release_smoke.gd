extends SceneTree
var game
var output: String
func _check(condition: bool, message: String = "Multiplayer regression failed") -> void:
 if not condition:
  push_error(message)
  quit(1)

func _initialize() -> void: call_deferred("run")
func mark(name: String, value: String = "ok") -> void:
 var file := FileAccess.open(output.path_join(name), FileAccess.WRITE)
 file.store_string(value)
func wait_file(name: String) -> void:
 var deadline := Time.get_ticks_msec() + 90000
 while not FileAccess.file_exists(output.path_join(name)):
  _check(Time.get_ticks_msec() < deadline, "Timed out: " + name)
  await process_frame
func run() -> void:
 output = OS.get_environment("MP_TEST_DIR")
 var host := OS.get_environment("MP_TEST_ROLE") == "host"
 var relay := OS.get_environment("MP_TEST_TRANSPORT") == "relay"
 game = load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 current_scene = game
 await game._start_game()
 game.set_process(false)
 game.set_physics_process(false)
 game.set_process_input(false)
 game.spawn_timer = 99999.0
 for c in game.customers.duplicate():
  game._remove_ticket(c)
  c.queue_free()
 game.customers.clear()
 for i in 3: await process_frame
 var net = root.get_node("NetManager")
 net.relay_url = "ws://127.0.0.1:18769" if relay else ""
 if host:
  _check(net.host_room("Regression Host", "Local regression") == OK)
  while not net.is_online(): await process_frame
  mark("connection", net.room_code if relay else str(net.game_port))
  await wait_file("guest_connected")
 else:
  await wait_file("connection")
  var address := FileAccess.get_file_as_string(output.path_join("connection"))
  if relay: _check(net.join_by_code(address, "Regression Guest") == OK)
  else: _check(net.join_room("127.0.0.1", int(address), "Regression Guest") == OK)
  while not net.is_online(): await process_frame
  mark("guest_connected")
 game.mp_enabled = true
 game.playing = true
 if host:
  var paint := Image.create(16,16,false,Image.FORMAT_RGBA8)
  paint.fill(Color(0.2,0.1,0.8,0.5))
  var preset := {"format_version":8,"name":"Multiplayer Release","top_catalog_version":1,"top_style":1,"bottom_catalog_version":1,"bottom_style":2,"shoe_catalog_version":1,"shoe_style":1,"skin_paint":Marshalls.raw_to_base64(paint.save_png_to_buffer())}
  game.mp_spawn_customer.rpc(90001,["bun_bottom","patty","bun_top","soda_cola"],1.0,1.0,1.0,9999.0,0,0,0,false,-1,false,preset)
  var customer = game._customer_by_net_id(90001)
  customer.position.x = customer.target_x
  customer.is_waiting = true
  customer.set_process(false)
  customer.start_order_clock()
  game._create_ticket(customer)
  customer.order_elapsed_sec = 4.95
  game.grill_on = true
  game._spawn_patty_at(0,Vector3(game.GRILL_CENTER_X,game.GRILL_SURFACE_Y,game.GRILL_SURFACE_Z),90002)
  var patty = game._patty_by_net_id(90002)
  patty.set_process(false)
  patty.cook_time = 8.0
  patty.first_side_time = 8.0
  patty.flipped_once = true
  patty.is_held = true
  game.grill[0] = null
  game.stations[0]["items"] = ["bun_bottom","patty","bun_top"]
  game.stations[0]["patties"] = [patty]
  game._refresh_station(0)
  game.cup_soda_fill = 1.0
  game.cup_flavor = "cola"
  game._mp_broadcast_grill()
  game._mp_broadcast_station(0)
  game._mp_broadcast_customers()
  game._mp_broadcast_economy()
  var before = game.total_served
  mark("fixture")
  await wait_file("requested")
  var deadline := Time.get_ticks_msec() + 20000
  while game.total_served == before:
   _check(Time.get_ticks_msec() < deadline, "Host did not serve guest request")
   await process_frame
  var arrival_spot: Vector3 = customer.global_position
  _check(bool(customer.get_meta("burger_in_flight", false)), "Serve did not latch arrival")
  while bool(customer.get_meta("burger_in_flight", false)):
   _check(not customer.is_leaving and customer.global_position.is_equal_approx(arrival_spot), "Host left before burger arrival")
   await process_frame
  await create_timer(1.3).timeout
  _check(game.total_served == before + 1, "Duplicate serve scored twice")
  _check(game.stations[0]["items"].is_empty())
  _check(is_equal_approx(customer.order_elapsed_sec,4.95), "Host order clock changed: " + str(customer.order_elapsed_sec))
  mark("host_result", JSON.stringify({"money":game.money,"served":game.total_served,"reviews":game.social_reviews.size()}))
  await wait_file("guest_passed")
 else:
  await wait_file("fixture")
  var deadline := Time.get_ticks_msec() + 20000
  while game._customer_by_net_id(90001) == null or game.stations[0]["items"].is_empty():
   _check(Time.get_ticks_msec() < deadline)
   await process_frame
  var customer = game._customer_by_net_id(90001)
  _check(customer.get_custom_character_preset()["name"] == "Multiplayer Release")
  _check(not str(customer.get_custom_character_preset()["skin_paint"]).is_empty())
  # An observer's own full cup must remain intact while the host's soda animates.
  var own_cup := Node3D.new()
  game.world.add_child(own_cup)
  game.cup_root = own_cup
  game.cup_soda_fill = 0.9
  game.cup_flavor = "orange"
  mark("requested")
  game._submit_serve_request(customer,0)
  game._submit_serve_request(customer,0)
  var saw_burst := false
  var saw_cup := false
  var saw_stopped_clock := false
  while not FileAccess.file_exists(output.path_join("host_result")):
   _check(Time.get_ticks_msec() < deadline, "No serve result")
   if is_instance_valid(customer) and bool(customer.get_meta("serve_in_progress", false)):
    saw_stopped_clock = saw_stopped_clock or not customer._order_clock_on
   if is_instance_valid(customer) and bool(customer.get_meta("burger_in_flight", false)):
    _check(not customer.is_leaving, "Guest left before burger arrival")
   for fly in game._serve_fly_root_pool:
    saw_burst = saw_burst or (fly.visible and fly.get_node("BurgerCompleteBurst").visible)
   saw_cup = saw_cup or game.get_node("UI/Root").get_node_or_null("CupFlyLayer") != null
   await process_frame
  await create_timer(0.25).timeout
  var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("host_result")))
  _check(saw_burst, "Guest missed burger completion burst")
  _check(saw_cup, "Guest missed companion drink animation")
  _check(game.cup_root == own_cup and own_cup.visible and is_equal_approx(game.cup_soda_fill,0.9), "Remote FX consumed observer cup")
  _check(is_equal_approx(game.money,float(expected.money)), "Money diverged")
  _check(game.total_served == int(expected.served), "Served count diverged")
  _check(game.social_reviews.size() == int(expected.reviews), "Social reviews diverged")
  _check(game.stations[0]["items"].is_empty(), "Guest station not cleared")
  _check(not game.tickets.has(customer), "Guest ticket survived serve")
  _check(saw_stopped_clock, "Guest clock did not stop")
  _check(not game._serve_fly_busy, "Guest animation did not release")
  mark("guest_passed")
 game.mp_enabled = false
 net.leave(false)
 print("MULTIPLAYER_RELEASE_SMOKE_OK ","host" if host else "guest", " ", "relay" if relay else "lan")
 # Let SceneTree shut down the complete graph together, including pending tweens.
 for tween in get_processed_tweens(): tween.kill()
 await process_frame
 await process_frame
 quit()
