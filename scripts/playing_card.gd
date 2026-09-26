extends Button
var card := -1
var selected := false
const ART="res://assets/cards/burger_cards.png"
static var atlas: Texture2D
static func art(index: int) -> Texture2D:
 if atlas==null and ResourceLoader.exists(ART):atlas=load(ART)
 if atlas==null:return null
 var texture:=AtlasTexture.new();texture.atlas=atlas
 texture.region=Rect2(Vector2(index%3,int(index/3))*Vector2(atlas.get_width()/3.0,atlas.get_height()/2.0),Vector2(atlas.get_width()/3.0,atlas.get_height()/2.0))
 return texture
func _ready():
 custom_minimum_size=Vector2(52,76);mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
func _draw():
 draw_style_box(_paper(),Rect2(Vector2.ZERO,size))
 if card<0:
  var back=art(1)
  if back:draw_texture_rect(back,Rect2(Vector2(2,2),size-Vector2(4,4)),false)
  return
 var rank=card%13+2
 var suit=int(card/13)
 var color=Color("C42D32") if suit in [1,2] else Color("143C48")
 var label=str(rank) if rank<11 else {11:"J",12:"Q",13:"K",14:"A"}[rank]
 if rank>=11:
  var index={11:4,12:3,13:2,14:5}[rank]
  var picture=art(index)
  if picture:draw_texture_rect(picture,Rect2(Vector2(10,7),size-Vector2(20,14)),false)
 else:
  for i in rank:
   _suit(Vector2(size.x*.35+float(i%2)*size.x*.30,19+float(int(i/2))*9),3.3,suit,color)
 var font=ThemeDB.fallback_font
 draw_string(font,Vector2(3,12),label,HORIZONTAL_ALIGNMENT_LEFT,-1,11,color)
 _suit(Vector2(7,19),3.1,suit,color)
 draw_string(font,Vector2(size.x-15,size.y-4),label,HORIZONTAL_ALIGNMENT_LEFT,-1,11,color)
 if selected:draw_rect(Rect2(Vector2.ONE,size-Vector2(2,2)),Color("FFCE52"),false,3)
func _paper():
 var style=StyleBoxFlat.new();style.bg_color=Color("FFF6DE");style.set_corner_radius_all(4);return style
# Original vector suit marks: no font dependency or licensed artwork.
func _suit(center: Vector2,r: float,suit: int,color: Color):
 if suit==2:
  draw_colored_polygon(PackedVector2Array([center+Vector2(0,-r*1.5),center+Vector2(r,0),center+Vector2(0,r*1.5),center+Vector2(-r,0)]),color)
 elif suit==1:
  draw_circle(center+Vector2(-r*.5,-r*.3),r*.65,color);draw_circle(center+Vector2(r*.5,-r*.3),r*.65,color)
  draw_colored_polygon(PackedVector2Array([center+Vector2(-r,0),center+Vector2(r,0),center+Vector2(0,r*1.3)]),color)
 else:
  if suit==0:
   draw_circle(center+Vector2(0,-r*.6),r*.7,color);draw_circle(center+Vector2(-r*.6,r*.1),r*.7,color);draw_circle(center+Vector2(r*.6,r*.1),r*.7,color)
  else:
   draw_colored_polygon(PackedVector2Array([center+Vector2(0,-r*1.4),center+Vector2(-r,r*.3),center+Vector2(r,r*.3)]),color)
   draw_circle(center+Vector2(-r*.4,r*.2),r*.6,color);draw_circle(center+Vector2(r*.4,r*.2),r*.6,color)
  draw_rect(Rect2(center+Vector2(-r*.25,0),Vector2(r*.5,r*1.5)),color)
