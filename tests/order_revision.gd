extends SceneTree
class MockGame extends Node:
 var playing=true
 var day=1
 var order_history: Array=[]
func _initialize(): call_deferred("run")
func run():
 var game=load("res://scripts/game.gd").new()
 game.day=1
 for pair in [[1200.0,1],[890.0,2],[750.0,1],[590.0,2],[290.0,3]]:
  game.day_time=pair[0]
  assert(game._customer_cap()==pair[1])
 assert(game._review_stars_from_serve(10,true,false,{"stars":5,"wait":4},1.0)<=2.5)
 assert(game._review_stars_from_serve(10,false,false,{"stars":5,"wait":4},1.0)==5.0)
 game.free()
 var mock=MockGame.new()
 var ui=Node.new();ui.name="UI";mock.add_child(ui)
 var host=Control.new();host.name="Root";ui.add_child(host)
 root.add_child(mock)
 var insights=load("res://scripts/order_insights.gd").new();mock.add_child(insights)
 insights.setup(mock,host)
 mock.order_history=[{"day":1,"perfect":true},{"day":1,"perfect":true}]
 insights._process(0.0);assert(insights.counter.text.ends_with("2"))
 mock.order_history.append({"day":1,"perfect":false})
 insights._process(0.0);assert(insights.counter.text.ends_with("0"))
 assert(not insights.counter.visible)
 var tex=load("res://assets/ui/burger_pals_icon.svg")
 tex.get_image().save_png("res://build/burgerpals_icon_preview.png")
 print("ORDER_REVISION_OK")
 quit()
