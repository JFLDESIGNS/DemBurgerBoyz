extends SceneTree
class GameStub extends Node3D:
 var _location_relocate_busy:=false
 var playing:=true
 var shift_paused:=false
 func _cat_delivery_blocks_visit()->bool:return false
 func _boss_keeps_cat_company()->bool:return false
func _initialize():call_deferred("run")
func run():
 var game=GameStub.new();root.add_child(game);current_scene=game
 var cat=load("res://scripts/window_cat.gd").new();game.add_child(cat);cat.set_process(false);cat.enabled=true;cat.reset_shift()
 for i in 19:
  cat.special_people_peek();cat.peek_for_patty(1.0);cat.request_delivery_peek();cat._process(1.0)
  assert(not cat.visible and cat._state=="hidden")
 game.shift_paused=true;cat._process(3.0);assert(cat._first_visit_wait==1.0)
 game.shift_paused=false;cat._process(1.0);assert(cat.visible and cat._state=="rising")
 cat.reset_shift();assert(cat._first_visit_wait==20.0 and not cat.visible)
 print("CAT_FIRST_VISIT_OK: no early special peeks, pause-safe 20 seconds, guaranteed first visit, daily reset")
 quit()
