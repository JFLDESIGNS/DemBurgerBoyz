extends Control
var street_art: Texture2D
var burst_clock := 0.0

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	burst_clock += delta
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	resized.connect(queue_redraw)

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0: return
	for i in 64:
		var t := float(i) / 63.0
		var color := Color("76cfcb").lerp(Color("fff0ce"), smoothstep(0.05, 0.85, t))
		draw_rect(Rect2(0, size.y*i/64.0, size.x, size.y/64.0+1), color)
	if street_art != null:
		var source := street_art.get_size()
		var scale_factor := maxf(size.x/source.x, size.y/source.y)
		var fitted := source*scale_factor
		draw_texture_rect(street_art, Rect2((size-fitted)*0.5, fitted), false, Color(1,1,1,0.24))
	var center := Vector2(size.x*0.5, size.y*0.30)
	var radius := size.length()
	var turn := sin(burst_clock * 0.20) * 0.10
	for i in 24:
		var angle := TAU * float(i) / 24.0 + turn
		var a := Vector2(cos(angle-0.025),sin(angle-0.025))
		var b := Vector2(cos(angle+0.025),sin(angle+0.025))
		draw_colored_polygon(PackedVector2Array([center,center+a*radius,center+b*radius]),Color(1.0,0.98,0.82,0.20))
	# Diner checker trim frames the page without competing with the buttons.
	var cell := clampf(size.y/36.0, 16.0, 26.0)
	for row in 2:
		for col in int(ceil(size.x/cell)):
			var color := Color("dc4c43") if (row+col)%2 == 0 else Color("ffffff")
			draw_rect(Rect2(col*cell, size.y-(2-row)*cell, cell, cell), color)
	draw_rect(Rect2(0,size.y-2*cell-5,size.x,5),Color("c73d36"))
	draw_rect(Rect2(0,0,size.x,7),Color("dc4c43"))
