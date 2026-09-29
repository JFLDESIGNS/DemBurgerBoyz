extends Control
var circles: Array[Rect2] = []
func present(audit: Dictionary) -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 var panel := PanelContainer.new()
 panel.mouse_filter = Control.MOUSE_FILTER_STOP
 add_child(panel)
 var style := StyleBoxFlat.new()
 style.bg_color = Color("FFF0BA")
 style.set_content_margin_all(18)
 style.shadow_color = Color(0,0,0,.25)
 style.shadow_size = 8
 panel.add_theme_stylebox_override("panel",style)
 var rows := VBoxContainer.new()
 rows.add_theme_constant_override("separation",5)
 panel.add_child(rows)
 add_line(rows,"ORDER CHECK",Color("583821"),22)
 add_line(rows,"Circled = missing   Red = extra",Color("745637"),14)
 var missing: Array = audit.get("missing",[]).duplicate()
 for ingredient in audit.get("ordered",[]):
  var line := add_line(rows,str(ingredient).replace("_"," ").capitalize(),Color("583821"),17)
  if missing.has(ingredient):
   missing.erase(ingredient)
   line.set_meta("circle",true)
 for ingredient in audit.get("extra",[]):
  add_line(rows,"+ Extra: "+str(ingredient).replace("_"," ").capitalize(),Color("C62929"),17)
 var close := Button.new()
 close.text = "Got it"
 rows.add_child(close)
 close.pressed.connect(queue_free)
 await get_tree().process_frame
 var viewport_size: Vector2 = get_parent().size
 var target := Vector2(viewport_size.x * .5 - panel.size.x * .5, maxf(24,viewport_size.y*.5-panel.size.y*.5))
 position = Vector2(viewport_size.x*.5,20)
 scale = Vector2(.25,.25)
 rotation = -.18
 var tween := create_tween().set_parallel(true)
 tween.tween_property(self,"position",target,.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
 tween.tween_property(self,"scale",Vector2.ONE,.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
 tween.tween_property(self,"rotation",0.0,.55)
 for line in rows.get_children():
  if line.has_meta("circle"): circles.append(Rect2(panel.position+rows.position+line.position-Vector2(5,1),line.size+Vector2(10,2)))
 queue_redraw()
func add_line(rows: VBoxContainer, value: String, color: Color, font_size: int) -> Label:
 var line := Label.new()
 line.text = value
 line.add_theme_font_override("font",preload("res://assets/fonts/Fredoka-SemiBold.ttf"))
 line.add_theme_font_size_override("font_size",font_size)
 line.add_theme_color_override("font_color",color)
 rows.add_child(line)
 return line
func _draw() -> void:
 # Draw above the paper through a child overlay, not behind its opaque panel.
 pass
func _ready() -> void:
 var overlay := Control.new()
 overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
 overlay.z_index = 2
 add_child(overlay)
 overlay.draw.connect(func():
  for rect in circles:
   var points := PackedVector2Array()
   for i in 49:
    var a := TAU*float(i)/48.0
    points.append(rect.get_center()+Vector2(cos(a)*rect.size.x*.5,sin(a)*rect.size.y*.5))
   overlay.draw_polyline(points,Color("C62929"),2.5,true)
 )
 draw.connect(overlay.queue_redraw)
