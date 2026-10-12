extends PanelContainer
var customer: Node3D
var age := 0.0
var tail: Polygon2D
func setup(person: Node3D, text: String) -> void:
 customer=person;name="CustomerConversation";mouse_filter=Control.MOUSE_FILTER_IGNORE;z_index=74
 var skin:=StyleBoxFlat.new();skin.bg_color=Color("FFF0C8");skin.border_color=Color("D9B76F");skin.shadow_color=Color(.18,.10,.04,.25);skin.shadow_size=5
 skin.set_border_width_all(2);skin.set_corner_radius_all(9);skin.content_margin_left=15;skin.content_margin_right=15;skin.content_margin_top=10;skin.content_margin_bottom=10
 add_theme_stylebox_override("panel",skin)
 var label:=Label.new();label.text=text;label.custom_minimum_size=Vector2(184,44);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 label.add_theme_font_override("font",preload("res://assets/fonts/Nunito-ExtraBold.ttf"));label.add_theme_font_size_override("font_size",13);label.add_theme_color_override("font_color",Color("715033"));add_child(label)
 tail=Polygon2D.new();tail.color=skin.border_color;tail.polygon=PackedVector2Array([Vector2(2,-12),Vector2(-18,7),Vector2(2,12)]);add_child(tail)
 var fill:=Polygon2D.new();fill.color=skin.bg_color;fill.polygon=PackedVector2Array([Vector2(3,-9),Vector2(-12,5),Vector2(3,9)]);tail.add_child(fill)
 modulate.a=0.0
func _process(delta: float) -> void:
 if not is_instance_valid(customer) or not customer.is_waiting or customer.is_leaving:queue_free();return
 var game=get_tree().current_scene
 if game.shift_paused or game.options_menu_open:return
 age+=delta
 if age>2.6:queue_free();return
 var camera:=get_viewport().get_camera_3d()
 if camera==null:return
 var parent:=get_parent() as Control
 var point:=parent.get_global_transform_with_canvas().affine_inverse()*camera.unproject_position(customer.global_position)
 position=Vector2(clampf(point.x+70.0,12.0,maxf(12.0,parent.size.x-size.x-12.0)),202.0)
 tail.position=Vector2(0,size.y*.55)
 modulate.a=smoothstep(0.0,.18,age)*(1.0-smoothstep(2.3,2.6,age))
