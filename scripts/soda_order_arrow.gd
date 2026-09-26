extends Label3D
var game: Node
var elapsed := 0.0
func _ready() -> void:
 name="SodaOrderArrow"
 text="↓"
 font=preload("res://assets/fonts/Nunito-ExtraBold.ttf")
 font_size=88
 pixel_size=.002
 modulate=Color("FFD56B")
 outline_modulate=Color("493220")
 outline_size=9
 billboard=BaseMaterial3D.BILLBOARD_ENABLED
 no_depth_test=true
 render_priority=30
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
  if str(mobile.get("phase","")) in ["accepted","paper","wrapping","bagging"] and not game.GameDataScript.order_soda_ids(mobile.get("items",[])).is_empty():visible=true
 position=game.soda_cup_rack_pos+Vector3(.12,.42+sin(elapsed*3.4)*.045,0)
