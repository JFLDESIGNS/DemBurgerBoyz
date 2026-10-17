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
var bin_polygon := PackedVector2Array()
var bin_center := Vector2.ZERO

func setup(owner_game: Node, id: String, topper: TextureRect) -> void:
 game=owner_game;ingredient=id;icon=topper
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 name="PilePieces"
 var shader:=Shader.new()
 shader.code="""
shader_type canvas_item;
uniform float contrast = 1.0;
uniform float lift = 0.0;
uniform vec3 tint = vec3(1.0);
varying vec4 ink;
void vertex(){ ink=COLOR; }
void fragment(){
 vec4 tex=texture(TEXTURE,UV);
 float weight=clamp((1.0-ink.r)/0.4,0.0,1.0);
 vec3 graded=clamp((tex.rgb-vec3(.5))*contrast+vec3(.5)+lift,vec3(0.0),vec3(1.0))*tint;
 COLOR=vec4(mix(tex.rgb,graded,weight),tex.a)*ink;
}
"""
 var mat:=ShaderMaterial.new()
 mat.shader=shader
 if ingredient=="onion":
  mat.set_shader_parameter("contrast",.62)
  mat.set_shader_parameter("lift",.045)
 elif ingredient=="tomato":
  mat.set_shader_parameter("contrast",.68)
 elif ingredient=="pickle":
  mat.set_shader_parameter("contrast",.82)
  mat.set_shader_parameter("lift",.08)
 elif ingredient=="cheese":
  mat.set_shader_parameter("tint",Vector3(1.0,.94,.85))
 material=mat

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
 bin_center=inverse*game.camera.unproject_position(fill.global_position)
 pile_center=bin_center+Vector2(0,-10)
 bin_polygon.clear()
 # Use the actual rim, not the lowered fill plane: a low-stock plane can
 # project through the front wall even though it is inside the 3D container.
 var half:=maxf(.1,float(game.ingredient_bin_length)-2.0*float(game.ingredient_bin_wall))*.43
 for corner in [Vector2(-half,-half),Vector2(half,-half),Vector2(half,half),Vector2(-half,half)]:
  bin_polygon.append(inverse*game.camera.unproject_position(tub.to_global(Vector3(corner.x,0,corner.y))))
 bin_center=Vector2.ZERO
 for point in bin_polygon:bin_center+=point*.25

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
 # Per-bin styling keeps the smaller pieces seated on the pile.
 var piece_scale:=.36
 var brightness:=.46
 var max_count:=3
 var flatten:=.8
 var angles:=[-.13,.12,0.0]
 match ingredient:
  "cheese":
   piece_scale=.726;brightness=.3298;max_count=1;flatten=.92;angles=[-.03,0.0,0.0]
  "tomato":
   piece_scale=.57024;brightness=.62;max_count=2
  "lettuce":
   piece_scale=.4752;brightness=.414;max_count=2;angles=[-.23,.20,0.0]
  "onion":
   piece_scale=.4752;brightness=.62
  "pickle":
   piece_scale=.432;brightness=.56
  "bacon":
   piece_scale=.5184;brightness=.334305;max_count=2
 var small:=topper_size*piece_scale
 small.y*=flatten
 var offsets:=[Vector2(-small.x*.30,small.y*.1),Vector2(small.x*.30,small.y*.18),Vector2(0,-small.y*.18)]
 if ingredient=="bacon":
  offsets[0].x=-small.x*.15
  offsets[1].x=small.x*.15
 var count:=mini(max_count,stock)
 if count==1:offsets[0]=Vector2.ZERO
 var flight_start:=pile_center
 var flight_size:=small
 for i in count:
  var angle:float=icon.rotation+angles[i]
  var center:Vector2=pile_center+offsets[i]
  var fitted:=small
  # Keep rotated corners and the soft shadow inside the projected pile surface.
  for attempt in 65:
   if _fits_bin(center,fitted,angle):break
   center=center.lerp(bin_center,.12)
   if attempt>12:fitted*=.97
  if i==count-1:
   flight_start=center
   flight_size=fitted
   if flight_age<DURATION:continue
  _piece(center,fitted,brightness,angle)
 if flight_age<DURATION:
  var t:=smoothstep(.08,DURATION,flight_age)
  var start:Vector2=flight_start
  var at:=start.lerp(topper_center,t)+Vector2(0,-sin(t*PI)*12.0)
  _piece(at,flight_size.lerp(topper_size,t),lerpf(brightness,1.0,t),icon.rotation+lerpf(float(angles[count-1]),0.0,t),1.0-t)

func _fits_bin(center:Vector2,dimensions:Vector2,angle:float) -> bool:
 if bin_polygon.size()!=4:return true
 for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
  var point:Vector2=center+(corner*(dimensions*.5+Vector2(3,4))).rotated(angle)
  if not Geometry2D.is_point_in_polygon(point,bin_polygon):return false
 return true

func _exit_tree() -> void:
 if is_instance_valid(icon):icon.self_modulate.a=1.0
