extends Control
var state:Dictionary={}
var mine:Dictionary={}
var won:=false
func _ready():mouse_filter=Control.MOUSE_FILTER_IGNORE
func _draw():
 if state.is_empty():return
 var center:=Vector2(size.x*.5,size.y-30)
 # Small physical-looking pips, patties, and a charge strip; no gameplay text.
 for i in 4:draw_circle(center+Vector2(-102+i*15,0),4.5,Color("F7D16D") if i<int(mine.get("hp",0)) else Color("#46535F"))
 for i in 6:
  var at:=center+Vector2(-22+i*13,0)
  draw_circle(at,4.2,Color("BA7145") if i<int(mine.get("ammo",0)) else Color("#46535F"))
 draw_line(center+Vector2(75,0),center+Vector2(137,0),Color("#46535F"),5,true)
 draw_line(center+Vector2(75,0),center+Vector2(75+62*float(mine.get("boost",0)),0),Color("7BE4EE"),5,true)
 if state.phase in ["waiting","countdown"]:
  for i in 3:
   var lit:bool=state.phase=="countdown" and float(state.clock)>=i
   draw_circle(Vector2(size.x*.5+(i-1)*28, size.y*.32),8,Color("F7D16D") if lit else Color("#46535F"))
 if state.phase=="results" and won:
  var at:=Vector2(size.x*.5,size.y*.25)
  draw_colored_polygon(PackedVector2Array([at+Vector2(-27,12),at+Vector2(-33,-18),at+Vector2(-12,-6),at+Vector2(0,-30),at+Vector2(12,-6),at+Vector2(33,-18),at+Vector2(27,12)]),Color("F7D16D"))
