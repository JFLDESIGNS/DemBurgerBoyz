extends Control
const MARK = preload("res://assets/branding/pal_laboratories.svg")
const FONT = preload("res://assets/fonts/LuckiestGuy-Regular.ttf")
const VOICE = preload("res://sounds/branding/pal_robot_intro.ogg")
var voice: AudioStreamPlayer
var age := 0.0
var voice_started := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("101217")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	center.add_child(stack)
	var panel := Control.new()
	panel.custom_minimum_size = Vector2(360,420)
	stack.add_child(panel)
	var logo := TextureRect.new()
	logo.texture = MARK
	logo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	panel.add_child(logo)
	var nameplate := _label("PAL", 47, Color("e3edf2"))
	nameplate.position = Vector2(48,26)
	nameplate.size = Vector2(264,57)
	panel.add_child(nameplate)
	stack.add_child(_label("LABORATORIES", 30, Color("b5bdc4")))
	voice = AudioStreamPlayer.new()
	voice.name = "PalRobotVoice"
	voice.stream = VOICE
	voice.volume_db = -4.0
	add_child(voice)
	visibility_changed.connect(func():
		if not is_visible_in_tree() and is_instance_valid(voice): voice.stop()
	)

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	age += delta
	if age >= 0.2 and not voice_started:
		voice_started = true
		voice.play()
