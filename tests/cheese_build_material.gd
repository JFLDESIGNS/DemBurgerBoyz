extends SceneTree
class BuildPattyProbe extends "res://tests/build_cheese_melt_smoke.gd".PattyProbe:
 var cook_time := 21.0
func _initialize(): call_deferred("run")
func run():
 create_timer(60).timeout.connect(func(): push_error("CHEESE_BUILD_TIMEOUT"); quit(1))
 var game = load("res://scenes/main.tscn").instantiate()
 game.set_script(load("res://tests/main_ticket_harness.gd"))
 root.add_child(game)
 game._style_static_labels()
 game._setup_stations_data()
 game._build_station_ui()
 var patty = BuildPattyProbe.new()
 game.add_child(patty)
 patty.cheese_melt = 1.0
 patty.cheese_effect_age = 1.0
 var st: Dictionary = game.stations[game.STATION_CRAFT]
 st.items = ["bun_bottom", "patty", "cheese"] as Array[String]
 st.patties = [patty]
 for refresh in 2:
  game._refresh_station(game.STATION_CRAFT)
  var sprite: TextureRect = st.layer_pool[1].get_node("LayerTexture")
  var blend = sprite.get_node("CheeseBlend")
  assert(sprite.material == blend.material, "Build refresh cleared the cheese shader")
  assert(is_equal_approx(float(sprite.material.get_shader_parameter("wobble_amount")), .195))
  assert(st.layer_pool[0].get_node("LayerTexture").material == load("res://shaders/build_bun_color.tres"))
 # Rebuilding an old burger must not restart the seven-second effect.
 patty.cheese_effect_age = 7.0
 game._refresh_station(game.STATION_CRAFT)
 var sprite: TextureRect = st.layer_pool[1].get_node("LayerTexture")
 var blend = sprite.get_node("CheeseBlend")
 assert(is_zero_approx(float(sprite.material.get_shader_parameter("wobble_amount"))))
 patty.cheese_effect_age = 1.0
 blend._process(0.0)
 blend.set_process(false)
 if DisplayServer.get_name() != "headless":
  # Render the actual refreshed build sprite in isolation to measure its motion.
  var viewport = SubViewport.new()
  viewport.size = Vector2i(512, 384)
  viewport.transparent_bg = true
  viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
  root.add_child(viewport)
  sprite.reparent(viewport)
  sprite.position = Vector2.ZERO
  sprite.size = Vector2(512, 384)
  for child in sprite.get_children():
   child.set_process(false)
   if child is CanvasItem: child.hide()
  var frames: Array[Image] = []
  for time in [0.0, .3]:
   blend.material.set_shader_parameter("wobble_age", time)
   await process_frame
   await RenderingServer.frame_post_draw
   frames.append(viewport.get_texture().get_image())
  var changed := 0
  for y in 384:
   for x in 512:
    if frames[0].get_pixel(x,y) != frames[1].get_pixel(x,y): changed += 1
  assert(changed > 1000, "Cheese shader produced no visible rendered motion")
  DirAccess.make_dir_recursive_absolute("res://output")
  frames[0].save_png("res://output/cheese_build_wobble_a.png")
  frames[1].save_png("res://output/cheese_build_wobble_b.png")
  print("CHEESE_BUILD_RENDER_CHANGED_PIXELS=", changed)
 print("CHEESE_BUILD_MATERIAL_OK")
 quit()
