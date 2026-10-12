extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 create_timer(30).timeout.connect(func(): quit(1))
 var game = load("res://scenes/main.tscn").instantiate()
 game.set_script(load("res://tests/main_ticket_harness.gd"))
 root.add_child(game);current_scene=game
 game.playing=true
 var bird = load("res://scripts/park_bird.gd").new()
 game.world.add_child(bird);bird.set_process(false)
 bird.position=Vector3(-3,2.2,7)
 bird._enter(&"Idle")
 var cat = load("res://scripts/window_cat.gd").new()
 game.world.add_child(cat);cat.set_process(false)
 cat.visible=true;cat.position=Vector3(.4,.69,2.85)
 cat._begin_bird_approach(bird)
 var home: Vector3=cat.position
 for i in 57:
  cat._timer-=1.0/60.0
  cat._update_wildlife(1.0/60.0,game)
  bird.advance(1.0/60.0)
 assert(cat.position.z>home.z+.4,"Approach moves away from counter")
 assert(bird.state==&"Idle","Bird waits through approach")
 while cat._state=="bird_approach":
  cat._timer-=1.0/60.0;cat._update_wildlife(1.0/60.0,game)
 for i in 30:
  cat._timer-=1.0/60.0;cat._update_wildlife(1.0/60.0,game)
 assert(bird.state==&"Idle","Bird stays until final fifth of leap")
 for i in 12:
  cat._timer-=1.0/60.0;cat._update_wildlife(1.0/60.0,game)
 assert(bird.state==&"Takeoff")
 assert(bird.swing_velocity.length()>.7,"Contact shakes the house")
 assert(cat._bird_house_hit)
 var sync: Dictionary=cat.get_mp_sync()
 assert(sync.bird_gaze_active and sync.bird_gaze is Vector3)
 for i in 55:
  cat._timer-=1.0/60.0;cat._update_wildlife(1.0/60.0,game)
 assert(cat._state=="peek" and cat.position.is_equal_approx(home))
 print("CAT_BIRD_POUNCE_OK: late escape, house impact, deeper approach, replicated gaze, safe return")
 game.queue_free()
 await process_frame
 quit()
