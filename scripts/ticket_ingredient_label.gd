extends Label
var completed := false:
 set(value):
  if completed == value: return
  completed = value
  queue_redraw()

func _draw() -> void:
 if not completed: return
 var paragraph := TextParagraph.new()
 paragraph.width = size.x
 paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
 paragraph.add_string(text,get_theme_font("font"),get_theme_font_size("font_size"))
 var y := maxf(0.0,(size.y-paragraph.get_size().y)*0.5)
 for index in paragraph.get_line_count():
  var line := paragraph.get_line_size(index)
  var middle := y + line.y * 0.52
  var width := minf(size.x,line.x)
  var left := (size.x-width)*0.5 if horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER else 0.0
  draw_line(Vector2(left,middle),Vector2(left+width,middle),get_theme_color("font_color"),1.7,true)
  y += line.y
