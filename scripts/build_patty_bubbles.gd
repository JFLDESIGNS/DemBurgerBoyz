extends Control
var heat: Control
var redraw_age := 0.0
func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
func _process(delta: float) -> void:
 visible=is_instance_valid(heat) and heat.age<15.0
 if visible and is_visible_in_tree():
  redraw_age+=delta
  if redraw_age>=1.0/30.0:
   redraw_age=fmod(redraw_age,1.0/30.0);queue_redraw()
func _draw() -> void:
 if not is_instance_valid(heat): return
 for i in 8:
  var angle := float(i)*2.399
  var radius := .46 if i%3!=0 else .23
  var at := Vector2(.5+cos(angle)*radius,.37+sin(angle)*radius*.52)*size
  var pop := sin(fmod(heat.age*.8+float(i)*.17,1.0)*PI)
  var r := size.x*(.013+float(i%3)*.002)*pop
  draw_circle(at+Vector2(0,r*.25),r,Color("713017"))
  draw_circle(at,r*.85,Color("B66B3C"))
  draw_arc(at,r*.60,PI*1.12,PI*1.75,8,Color("D28A52"),maxf(1.0,r*.2),true)
