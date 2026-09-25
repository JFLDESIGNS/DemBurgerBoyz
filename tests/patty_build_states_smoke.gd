extends SceneTree
func _initialize():
 var sprites = load("res://scripts/food_sprites.gd")
 var paths := []
 for amount in [0.0,0.3,0.6,1.0]:
  var tex: Texture2D = sprites.build_patty_state_tex(amount)
  assert(tex != null and tex.get_width() > tex.get_height())
  paths.append((tex as AtlasTexture).atlas.resource_path)
  var image := tex.get_image()
  if image.is_compressed(): image.decompress()
  assert(image.get_pixel(0,0).a == 0.0)
  assert(sprites.build_patty_state_tex(amount,true) != null)
 assert(paths[0].ends_with("perfect.png"))
 assert(paths[1].ends_with("overdone.png"))
 assert(paths[2].ends_with("almost_black.png"))
 assert(paths[3].ends_with("black.png"))
 print("PATTY_BUILD_STATES_OK")
 quit()
