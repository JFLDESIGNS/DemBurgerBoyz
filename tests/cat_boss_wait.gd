extends SceneTree
class GameStub extends Node3D:
 var boss := true
 var delivery := false
 func _boss_keeps_cat_company() -> bool: return boss
 func _cat_delivery_blocks_visit() -> bool: return delivery
func _initialize() -> void: call_deferred("run")
func run() -> void:
 create_timer(30).timeout.connect(func(): quit(1))
 var game := GameStub.new()
 root.add_child(game)
 current_scene = game
 var cat = load("res://scripts/window_cat.gd").new()
 game.add_child(cat)
 cat.set_process(false)
 cat.special_people_peek(0.1)
 cat._state = "peek"
 cat._timer = 0.1
 for n in 180: cat._process(1.0/60.0)
 assert(cat.visible and cat._state == "peek", "Cat must stay for boss")
 game.boss = false
 cat._process(1.0/60.0)
 assert(cat._state == "lowering", "Cat leaves after boss exits")
 cat._process(0.6)
 assert(not cat.visible)
 game.boss = true
 cat.visible = true
 cat._state = "fed_hold"
 cat._timer = 0.01
 cat._process(0.1)
 assert(cat._state == "fed_hold")
 game.boss = false
 cat._process(0.1)
 assert(cat._state == "running", "Fed cat resumes departure")
 game.boss=true;game.delivery=true;cat._state="peek";cat.visible=true;cat._timer=.1
 cat._process(.2);assert(cat.visible and cat._state=="peek","Delivery cannot pop an existing cat away during the boss")
 game.boss=false;cat._process(.1);assert(cat.visible and cat._state=="lowering","Cat visibly lowers instead of vanishing")
 print("CAT_BOSS_WAIT_OK")
 game.queue_free()
 await process_frame
 quit()
