extends Control
## Presentation only: the existing ingredient controls still own stock and input.
const DURATION := 0.62
var game: Node
var ingredient: String
var icon: TextureRect
var previous_stock := -1
var previous_drag := false
var flight_age := DURATION
var since_take := 10.0
var pile_center := Vector2.ZERO
var topper_center := Vector2.ZERO
var topper_size := Vector2.ZERO
var stock := 0

func setup(owner_game: Node, id: String, topper: TextureRect) -> void:
 game=owner_game;ingredient=id;icon=topper
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 name="PilePieces"

func _process(delta: float) -> void:
 if not is_instance_valid(icon) or not is_instance_valid(game):return
 since_take+=delta
 flight_age=minf(DURATION,flight_age+delta)
 stock=int(game.supply_stock.get(ingredient,0))
 var dragging:bool=game._pending_ingredient_drag==ingredient or (ingredient=="cheese" and game._pending_cheese_drag)
 var taken:bool=(dragging and not previous_drag) or (previous_stock>=0 and stock<previous_stock and since_take>DURATION)
 if taken and stock>0:
  flight_age=0.0;since_take=0.0
 previous_stock=stock;previous_drag=dragging
 icon.self_modulate.a=0.0 if flight_age<DURATION or stock<=0 else 1.0
 var tub:Node3D=game.ingredient_bin_nodes.get(ingredient)
 var fill:Node3D=tub.get_node_or_null("Fill") if is_instance_valid(tub) else null
 visible=stock>0 and is_instance_valid(fill) and fill.visible and is_instance_valid(game.camera)
 if not visible:return
 var inverse=get_global_transform_with_canvas().affine_inverse()
 pile_center=inverse*game.camera.unproject_position(fill.global_position)+Vector2(0,5)
 topper_center=inverse*(icon.get_global_transform_with_canvas()* (icon.size*.5))
 var texture_size:Vector2=icon.texture.get_size()
 topper_size=texture_size*minf(icon.size.x/texture_size.x,icon.size.y/texture_size.y)
 queue_redraw()

func _piece(center:Vector2,dimensions:Vector2,brightness:float,angle:float,shadow:float=1.0) -> void:
 for offset in [Vector2.ZERO,Vector2(-2,0),Vector2(2,0),Vector2(0,-2),Vector2(0,2),Vector2(-2,-2),Vector2(2,2),Vector2(-2,2),Vector2(2,-2)]:
  draw_set_transform(center+Vector2(1,3)+offset,angle)
  draw_texture_rect(icon.texture,Rect2(-dimensions*.5,dimensions),false,Color(0,0,0,.022*shadow))
 draw_set_transform(center,angle)
 draw_texture_rect(icon.texture,Rect2(-dimensions*.5,dimensions),false,Color(brightness,brightness,brightness,1))
 draw_set_transform(Vector2.ZERO)

func _draw() -> void:
 if stock<=0 or not is_instance_valid(icon) or icon.texture==null:return
 var small:=topper_size*(.55 if ingredient=="cheese" else .36)
 small.y*=.8
 var offsets:=[Vector2(-small.x*.30,small.y*.1),Vector2(small.x*.30,small.y*.18),Vector2(0,-small.y*.18)]
 var count:=mini(1 if ingredient=="cheese" else 3,stock)
 if ingredient=="cheese":offsets[0]=Vector2.ZERO
 for i in count:
  if i==count-1 and flight_age<DURATION:continue
  _piece(pile_center+offsets[i],small,.46,icon.rotation+[-.13,.12,0.0][i])
 if flight_age<DURATION:
  var t:=smoothstep(.08,DURATION,flight_age)
  var start:Vector2=pile_center+offsets[count-1]
  var at:=start.lerp(topper_center,t)+Vector2(0,-sin(t*PI)*12.0)
  _piece(at,small.lerp(topper_size,t),lerpf(.46,1.0,t),icon.rotation,1.0-t)

func _exit_tree() -> void:
 if is_instance_valid(icon):icon.self_modulate.a=1.0
