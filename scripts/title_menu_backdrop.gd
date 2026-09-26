extends Control
func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 resized.connect(queue_redraw)
func _draw() -> void:
 if size.x <= 0 or size.y <= 0: return
 # A quiet mint-to-cream backdrop with the original diner checker trim.
 for i in 64:
  var t := float(i) / 63.0
  var color := Color("81CBC6").lerp(Color("F8EED6"),smoothstep(.05,.95,t))
  draw_rect(Rect2(0,size.y*i/64.0,size.x,size.y/64.0+1),color)
 var cell := clampf(size.y/36.0,16,26)
 for row in 2:
  for col in int(ceil(size.x/cell)):
   draw_rect(Rect2(col*cell,size.y-(2-row)*cell,cell,cell),Color("D74B40") if (row+col)%2==0 else Color("FFF5E0"))
 draw_rect(Rect2(0,size.y-2*cell-4,size.x,4),Color("B53B32"))
