extends Control
# Kept for the loader's phase updates; the screen shows only its main headline.
var status_text := ""
const FONT = preload("res://assets/fonts/Fredoka-Bold.ttf")
const TITLE := "FIRING UP THE GRILL"
var letters: Array[Label] = []
var age := 0.0
var tick := -1

func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 for glyph in TITLE:
  var label := Label.new()
  label.text = glyph
  label.add_theme_font_override("font", FONT)
  label.add_theme_color_override("font_color", Color("b9b2a6"))
  label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.7))
  label.add_theme_constant_override("shadow_offset_y", 2)
  label.mouse_filter = Control.MOUSE_FILTER_IGNORE
  add_child(label)
  letters.append(label)
 resized.connect(_layout)
 _layout()

func _layout() -> void:
 # Match the video's fitted 16:9 rectangle, including letterboxed windows.
 var fitted := Vector2(minf(size.x, size.y * 16.0 / 9.0), minf(size.y, size.x * 9.0 / 16.0))
 var origin := (size - fitted) * 0.5
 var font_size := maxi(12, roundi(26.0 * fitted.x / 1280.0))
 var total := FONT.get_string_size(TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
 var x := origin.x + (fitted.x - total) * 0.5 + 15.0 * fitted.x / 1280.0
 for label in letters:
  label.add_theme_font_size_override("font_size", font_size)
  label.position = Vector2(x, origin.y + fitted.y * 0.375 + 30.0 * fitted.y / 720.0)
  label.set_meta("baseline", label.position)
  x += FONT.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

func _process(delta: float) -> void:
 if not is_visible_in_tree(): return
 age += delta
 var next := int(age * 12.0)
 if next == tick: return
 tick = next
 var t := float(tick) / 12.0
 for i in letters.size():
  var label := letters[i]
  label.position = label.get_meta("baseline") + Vector2(0, -1.5 * maxf(0.0, sin(t * 3.4 - i * 0.36)))
