extends Control
var street_art: Texture2D = preload("res://assets/ui/title_illustrated_background.png")
func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 resized.connect(queue_redraw)
func _draw() -> void:
 if size.x <= 0 or size.y <= 0: return
 draw_rect(Rect2(Vector2.ZERO,size),Color("FFF0CE"))
 var fit := minf(size.x/1672.0,size.y/941.0)
 var dimensions := Vector2(1672,941)*fit
 draw_texture_rect(street_art,Rect2((size-dimensions)*.5,dimensions),false)
