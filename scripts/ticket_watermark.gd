extends Control
const LOGO = preload("res://assets/ingredients/burger_pals_ticket_mask.png")
func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 var ink := ShaderMaterial.new()
 ink.shader = preload("res://shaders/ticket_logo_mask.gdshader")
 material = ink
 resized.connect(queue_redraw)

func _draw() -> void:
 var width := maxf(1.0,size.x-18.0)
 var height := width * float(LOGO.get_height()) / float(LOGO.get_width())
 draw_texture_rect(LOGO,Rect2(Vector2((size.x-width)*0.5,size.y*0.58-height*0.5+10.0),Vector2(width,height)),false)
