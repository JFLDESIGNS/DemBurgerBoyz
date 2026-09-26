extends PanelContainer
func _ready(): resized.connect(queue_redraw)
func _draw():
 var points:=PackedVector2Array([Vector2(0,size.y-2),Vector2(size.x,size.y-2)])
 for i in range(20,-1,-1):
  points.append(Vector2(size.x*float(i)/20.0,size.y+(8.0+float(i%3)*2.0 if i%2==1 else 0.0)))
 draw_colored_polygon(points,Color("F4E6C8"))
