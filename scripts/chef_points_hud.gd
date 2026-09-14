extends HBoxContainer
const ICON = preload("res://assets/ui/chef_points_burger.svg")
const CHIME = preload("res://sounds/ui/chef_points.wav")
const FONT = preload("res://assets/fonts/Fredoka-Bold.ttf")
var points := 0
var shown := 0.0
var number: Label
var climb: Tween
var sound: AudioStreamPlayer
var active_pop: Label
var reward_queue: Array[Dictionary] = []
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_theme_constant_override("separation", 7)
	tooltip_text = "Chef Points — perfect flips, quick lifts, fresh burgers and five-star reviews"
	var icon := TextureRect.new()
	icon.texture=ICON;icon.custom_minimum_size=Vector2(32,32)
	icon.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(icon)
	number=Label.new();number.add_theme_font_override("font",FONT)
	number.add_theme_font_size_override("font_size",30)
	number.add_theme_color_override("font_color",Color("ffdc73"))
	number.add_theme_color_override("font_outline_color",Color("30251c"))
	number.add_theme_constant_override("outline_size",2);number.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;add_child(number)
	sound=AudioStreamPlayer.new();sound.stream=CHIME;sound.volume_db=-13;add_child(sound)
	_draw_count(0)
func _draw_count(value: float) -> void:
	shown=value;number.text=str(roundi(value))
func set_total(total: int, amount: int = 0, reason: String = "") -> void:
	points=total
	if is_instance_valid(climb):climb.kill()
	if amount<=0:
		_draw_count(total);return
	climb=create_tween()
	climb.tween_method(_draw_count,shown,float(total),0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	number.modulate=Color(1.35,1.2,0.85)
	climb.parallel().tween_property(number,"modulate",Color.WHITE,0.65)
	reward_queue.append({"amount":amount,"reason":reason})
	if not is_instance_valid(active_pop): _show_next_reward()

func _show_next_reward() -> void:
	if reward_queue.is_empty(): return
	var reward: Dictionary=reward_queue.pop_front()
	var pop:=Label.new();pop.mouse_filter=Control.MOUSE_FILTER_IGNORE
	active_pop=pop
	pop.text="+%d CHEF POINTS  •  %s" % [reward.amount,reward.reason]
	pop.add_theme_font_override("font",FONT);pop.add_theme_font_size_override("font_size",19)
	pop.add_theme_color_override("font_color",Color("ffe69a"));pop.add_theme_color_override("font_outline_color",Color("292322"));pop.add_theme_constant_override("outline_size",3)
	get_tree().current_scene.get_node("UI/Root").add_child(pop)
	pop.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pop.offset_left=-540;pop.offset_right=-14;pop.offset_top=79;pop.offset_bottom=109
	pop.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;pop.z_index=90
	pop.modulate.a=0.0
	var fly:=pop.create_tween();fly.tween_property(pop,"modulate:a",1.0,0.12)
	fly.tween_interval(2.1)
	fly.tween_property(pop,"modulate:a",0.0,0.3)
	fly.tween_callback(func():
		pop.queue_free();active_pop=null;_show_next_reward()
	)
	sound.pitch_scale=1.0+minf(float(reward.amount)/200.0,0.18);sound.play()
