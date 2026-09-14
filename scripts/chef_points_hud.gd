extends HBoxContainer
const ICON = preload("res://assets/ui/chef_points_burger.svg")
const CHIME = preload("res://sounds/ui/chef_points.wav")
const FONT = preload("res://assets/fonts/LuckiestGuy-Regular.ttf")
var points := 0
var shown := 0.0
var number: Label
var climb: Tween
var sound: AudioStreamPlayer
var active_pop: Label
var pop_amount := 0
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 7)
	tooltip_text = "Chef Points — perfect flips, quick lifts, fresh burgers and five-star reviews"
	var icon := TextureRect.new()
	icon.texture=ICON;icon.custom_minimum_size=Vector2(32,32)
	icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(icon)
	number=Label.new();number.add_theme_font_override("font",FONT)
	number.add_theme_font_size_override("font_size",28)
	number.add_theme_color_override("font_color",Color("ffdc73"))
	number.add_theme_color_override("font_outline_color",Color("30251c"))
	number.add_theme_constant_override("outline_size",4);add_child(number)
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
	number.pivot_offset=number.size*.5;number.scale=Vector2(1.28,1.28)
	climb.parallel().tween_property(number,"scale",Vector2.ONE,0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_instance_valid(active_pop):
		amount += pop_amount
		reason = "Chef points"
		active_pop.queue_free()
	pop_amount = amount
	var pop:=Label.new();pop.mouse_filter=Control.MOUSE_FILTER_IGNORE
	active_pop=pop
	pop.text="+%d  %s" % [amount,reason.to_upper()]
	pop.add_theme_font_override("font",FONT);pop.add_theme_font_size_override("font_size",19)
	pop.add_theme_color_override("font_color",Color("ffe69a"));pop.add_theme_color_override("font_outline_color",Color("292322"));pop.add_theme_constant_override("outline_size",4)
	get_tree().current_scene.get_node("UI/Root").add_child(pop)
	pop.global_position=global_position+Vector2(-65,48);pop.z_index=90
	var fly:=pop.create_tween();fly.tween_property(pop,"position:y",pop.position.y-22,0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fly.tween_property(pop,"modulate:a",0.0,0.45);fly.tween_callback(pop.queue_free)
	sound.pitch_scale=1.0+minf(float(amount)/200.0,0.18);sound.play()
