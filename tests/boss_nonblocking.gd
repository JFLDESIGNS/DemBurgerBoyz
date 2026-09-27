extends SceneTree
func _initialize():call_deferred("run")
func run():
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/main_ticket_harness.gd"));root.add_child(g)
 g.playing=true;g._boss_intro_running=true
 assert(not g._morning_boss_blocks_controls(),"Knock must not block movement")
 g._cut_collector=Node3D.new();g.add_child(g._cut_collector);g._cut_collector_kind="pep"
 assert(not g._morning_boss_blocks_controls(),"Walk-up must not pause the kitchen")
 assert(load("res://scripts/game_audio.gd").can_instantiate())
 print("BOSS_NONBLOCKING_OK");quit()
