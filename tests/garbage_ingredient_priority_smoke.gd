extends SceneTree
func _initialize(): call_deferred("run")
func run():
 var game = load("res://scenes/main.tscn").instantiate()
 game.set_script(load("res://tests/main_ticket_harness.gd"))
 root.add_child(game)
 current_scene = game
 game.camera.position = Vector3(0,0,3)
 game.camera.rotation = Vector3.ZERO
 game.camera.current = true
 var area := Area3D.new()
 area.collision_layer = game.PHYSICAL_GARBAGE_COLLISION_LAYER
 var shape := CollisionShape3D.new()
 var box := BoxShape3D.new()
 box.size = Vector3(2,2,0.3)
 shape.shape = box
 area.add_child(shape)
 game.add_child(area)
 game.physical_garbage_area = area
 var point: Vector2 = game.camera.unproject_position(Vector3.ZERO)
 var cheese := Button.new()
 cheese.position = point-Vector2(20,20)
 cheese.size = Vector2(40,40)
 game.add_child(cheese)
 game.ingredient_buttons["cheese"] = cheese
 await physics_frame
 await physics_frame
 assert(game._strip_ingredient_at(point) == "cheese")
 assert(not game._garbage_area_hit(point), "Garbage stole cheese's click")
 game.ingredient_buttons.clear()
 assert(game._garbage_area_hit(point), "Garbage must remain usable outside ingredient buttons")
 print("GARBAGE_INGREDIENT_PRIORITY_OK")
 game.free()
 quit()
