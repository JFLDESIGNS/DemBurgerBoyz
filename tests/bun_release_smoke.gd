extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var g = load("res://scenes/main.tscn").instantiate()
	g.set_script(load("res://tests/bun_release_fixture.gd"));root.add_child(g);current_scene=g
	var bun = g._make_held_bun()
	g.spatula_patty = bun
	g.spatula_from_build = true
	g.spatula_carry_travel = 300.0
	for velocity in [Vector2(-3000,0),Vector2(3000,0)]:
		g.spatula_vel_screen = velocity
		g.placed_at = Vector2.ZERO
		g._handle_spatula_release(Vector2(800,420))
		assert(g.placed_at == Vector2(800,420) and g.throws == 0, "Fast bun releases must use the drop point, not a flick destination")
	print("BUN_RELEASE_OK: both flick directions place buns at the cursor")
	quit()
