extends SceneTree
func _initialize():call_deferred("run")
func run():
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/challenge_auto_fixture.gd"));root.add_child(g);current_scene=g
 for i in 100:
  g._pick_challenge_size()
  assert(g._challenge_count>=5 and g._challenge_count<=10)
  assert(g._challenge_time_max==g._challenge_count*10.0)
 g._show_challenge_offer()
 assert(g._challenge_phase=="active" and g.spawned==1,"Challenge starts without an accept prompt")
 print("CHALLENGE_AUTO_START_5_TO_10_OK")
 quit()
