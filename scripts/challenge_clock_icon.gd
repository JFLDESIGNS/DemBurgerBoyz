extends Control
func _draw() -> void:
 var c:=size*.5
 draw_circle(c+Vector2(0,3),23,Color("BC945D"))
 draw_circle(c,23,Color("643D27"))
 draw_circle(c,19,Color("FFF5D4"))
 for i in 12:
  var dir:=Vector2(sin(i*TAU/12),-cos(i*TAU/12))
  draw_line(c+dir*14,c+dir*17,Color("9E7447"),2,true)
 draw_line(c,c+Vector2(0,-12),Color("643D27"),3,true)
 draw_line(c,c+Vector2(9,5),Color("C4492C"),3,true)
 draw_circle(c,3,Color("643D27"))
