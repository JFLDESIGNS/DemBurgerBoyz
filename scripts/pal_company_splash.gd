extends Control
const MARK = preload("res://assets/branding/pal_laboratories.svg")
const FONT = preload("res://assets/fonts/Fredoka-Bold.ttf")
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("132637")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	center.add_child(stack)
	var logo := TextureRect.new()
	logo.texture = MARK
	logo.custom_minimum_size = Vector2(300,270)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	stack.add_child(logo)
	for line in ["PAL", "LABORATORIES"]:
		var label := Label.new()
		label.text = line
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font", FONT)
		label.add_theme_font_size_override("font_size", 64 if line == "PAL" else 25)
		label.add_theme_color_override("font_color", Color("f4eedc") if line == "PAL" else Color("84bd79"))
		stack.add_child(label)
