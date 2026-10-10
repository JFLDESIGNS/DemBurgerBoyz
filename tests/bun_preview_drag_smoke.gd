extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var g = load("res://scenes/main.tscn").instantiate()
	g.set_script(load("res://tests/main_ticket_harness.gd"));root.add_child(g);current_scene=g
	var parent = Control.new();g.add_child(parent)
	parent.scale=Vector2(-1.3,.7);parent.rotation=.15
	var top=Control.new();var bottom=Control.new();parent.add_child(top);parent.add_child(bottom)
	top.position=Vector2(40,20);bottom.position=Vector2(40,80)
	top.scale=Vector2(-.8,1.1)
	var start_top=top.get_global_transform_with_canvas().origin
	var start_bottom=bottom.get_global_transform_with_canvas().origin
	g._build_swipe={"origin":Vector2(200,200),"preview_rows":[{"row":top,"home":top.position},{"row":bottom,"home":bottom.position}]}
	g._move_build_swipe_preview(Vector2(320,140))
	assert((top.get_global_transform_with_canvas().origin-start_top).is_equal_approx(Vector2(120,-60)))
	assert((bottom.get_global_transform_with_canvas().origin-start_bottom).is_equal_approx(Vector2(120,-60)),"Both halves must follow the same screen movement")
	g._move_build_swipe_preview(Vector2.ZERO,true)
	assert(top.position==Vector2(40,20) and bottom.position==Vector2(40,80))
	print("BUN_PREVIEW_DRAG_OK: mirrored/scaled/rotated UI follows pointer, both halves move, reset restores both")
	quit()
