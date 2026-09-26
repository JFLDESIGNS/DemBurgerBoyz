extends Node3D
# The controls live over the empty physical bins; purchases use the normal host route.
var game: Node
var markers: Dictionary = {}
func _process(_delta: float) -> void:
 if not is_instance_valid(game) or not is_instance_valid(game.camera): return
 visible = game.playing and is_instance_valid(game.ingredient_legend) and game.ingredient_legend.visible
 if not visible: return
 for id in game.ingredient_buttons:
  var button: Control = game.ingredient_buttons[id]
  if not is_instance_valid(button): continue
  var empty: bool = int(game.supply_stock.get(id, 0)) <= 0
  if not markers.has(id) and empty: _make_marker(str(id))
  if not markers.has(id): continue
  var marker: Label3D = markers[id]
  marker.visible = empty and button.is_visible_in_tree()
  if not marker.visible: continue
  marker.text = "ON THE WAY" if game._supply_order_pending(str(id)) else "ORDER MORE"
  var screen: Vector2 = game._ingredient_tile_camera_screen(button, .5)
  marker.global_position = game.camera.project_position(screen, 1.0)
 for id in ["patty", "bun_bottom", "bun_top"]:
  var empty: bool = int(game.supply_stock.get(id, 0)) <= 0
  if not markers.has(id) and empty: _make_marker(id)
  if not markers.has(id): continue
  var marker: Label3D = markers[id]
  marker.visible = empty
  if not empty: continue
  var at: Vector3
  if id == "patty":
   if not is_instance_valid(game.patty_fridge_root): marker.hide(); continue
   at = game._fridge_ball_launch_world()
  else:
   if not is_instance_valid(game.bun_pile_root): marker.hide(); continue
   at = game._bun_pile_home_world(id)
  var screen: Vector2 = game.camera.unproject_position(at)
  if id == "bun_bottom": screen.y += 14
  if id == "bun_top": screen.y -= 14
  marker.global_position = game.camera.project_position(screen, 1.0)
  marker.text = "ON THE WAY" if game._supply_order_pending(id) else ("ORDER BASE" if id == "bun_bottom" else "ORDER TOPS" if id == "bun_top" else "ORDER MORE")
func _make_marker(id: String) -> void:
 var label = Label3D.new()
 label.name = "Restock_" + id
 label.font = preload("res://assets/fonts/Nunito-ExtraBold.ttf")
 label.font_size = 32
 label.pixel_size = .00065
 label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
 label.modulate = Color("FFD36B")
 label.outline_modulate = Color("302017")
 label.outline_size = 10
 label.no_depth_test = true
 add_child(label)
 markers[id] = label
func handle_input(event: InputEvent) -> bool:
 if not visible or not game.playing or not event is InputEventMouseButton: return false
 if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed: return false
 var hovered = game.get_viewport().gui_get_hovered_control()
 if is_instance_valid(hovered) and is_instance_valid(game.phone_column) and game.phone_column.is_ancestor_of(hovered): return false
 for id in markers:
  var marker: Label3D = markers[id]
  if not marker.is_visible_in_tree(): continue
  var center: Vector2 = game.camera.unproject_position(marker.global_position)
  var edge: Vector2 = game.camera.unproject_position(marker.global_position + game.camera.global_basis.x * .065)
  var half_width: float = maxf(32, center.distance_to(edge))
  if Rect2(center - Vector2(half_width, 18), Vector2(half_width * 2, 36)).has_point(event.position):
   if not game._supply_order_pending(str(id)): game._buy_supply(str(id))
   return true
 return false
