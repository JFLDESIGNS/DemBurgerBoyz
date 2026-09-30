extends MeshInstance3D
var game: Node
var elapsed := 0.0
func _ready() -> void:
 name="SodaOrderArrow"
 var points=PackedVector2Array([Vector2(-.04,.016),Vector2(-.03,.024),Vector2(0,-.006),Vector2(.03,.024),Vector2(.04,.016),Vector2(0,-.024)])
 var shape=ImmediateMesh.new();shape.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
 for index in Geometry2D.triangulate_polygon(points):shape.surface_add_vertex(Vector3(points[index].x,points[index].y,0))
 shape.surface_end();mesh=shape
 var ink=StandardMaterial3D.new();ink.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;ink.albedo_color=Color("FFD56B");ink.cull_mode=BaseMaterial3D.CULL_DISABLED;ink.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED;ink.no_depth_test=true;ink.render_priority=30
 material_override=ink;cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
func _process(delta: float) -> void:
 elapsed+=delta
 visible=false
 if not is_instance_valid(game) or not game.playing: return
 for customer in game.customers:
  if not is_instance_valid(customer) or customer.is_leaving or customer.get_meta("meal_aside",false): continue
  if not game.GameDataScript.order_soda_ids(customer.order).is_empty() and not game._customer_soda_handed(customer):
   visible=true
   break
 if is_instance_valid(game._grubbah):
  var mobile:Dictionary=game._grubbah.state
  if str(mobile.get("phase","")) in ["accepted","paper","wrapping","bagging"] and not game.GameDataScript.order_soda_ids(mobile.get("items",[])).is_empty() and not mobile.get("side_packs",{}).has(str(game.GameDataScript.order_soda_ids(mobile.get("items",[]))[0])):visible=true
 position=game.soda_cup_rack_pos+Vector3(0,.24+sin(elapsed*3.4)*.025,0)
