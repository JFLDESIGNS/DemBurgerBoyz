extends SceneTree
func _initialize():
 var food=load("res://scripts/food_sprites.gd")
 var expected=load("res://assets/ingredients/pickle_topper.png")
 assert(food.get_tex("pickle")==expected)
 var layer=food.prep_texture_for_composite(food.get_tex("pickle"))
 assert(layer!=null and not layer.is_empty())
 print("PICKLE_TEXTURE_MATCH_OK")
 quit()
