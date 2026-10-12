extends SceneTree
func _initialize():call_deferred("run")
func run():
 var p=load("res://scripts/patty.gd").new()
 p.cook_time=0;var raw:Color=p._side_cook_color(1)
 p.cook_time=10;var mid:Color=p._side_cook_color(1)
 p.cook_time=15;var brown:Color=p._side_cook_color(1)
 assert(raw.b>mid.b and mid.b>brown.b,"Bottom gradually browns before flipping")
 p.first_side_time=15;p.flipped_once=true;p.cook_time=0
 var second:Color=p._side_cook_color(1);var top:Color=p._side_cook_color(0)
 assert(second.b>top.b*1.5,"Fresh second side is visibly pinker than the cooked top")
 p.cook_time=15
 assert(p._side_cook_color(1).b<second.b*.6,"Second side browns by scoop time")
 p.free();print("PATTY_SIDE_BROWNING_OK");quit()
