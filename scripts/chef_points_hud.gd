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
	tooltip_text = "Chef Points - perfect flips, quick lifts, fresh burgers and five-star reviews"
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
	sound=AudioStreamPlayer.new(); sound.bus = "SFX";sound.stream=CHIME;sound.volume_db=-6;add_child(sound)
	_draw_count(0)
func _draw_count(value: float) -> void:
	shown=value;number.text=str(roundi(value))

func _process(_delta: float) -> void:
	if is_instance_valid(active_pop): _position_reward(active_pop)

func _exit_tree() -> void:
	if is_instance_valid(active_pop): active_pop.queue_free()
	reward_queue.clear()

func _position_reward(pop: Label) -> void:
	pop.size = Vector2(maxf(526,pop.get_minimum_size().x),maxf(30,pop.get_minimum_size().y))
	pop.pivot_offset = Vector2(pop.size.x,pop.size.y*.5)
	# The HUD can be scaled independently of UI/Root. Align in canvas coordinates
	# against the actual number label, not the HBox's unscaled layout dimensions.
	var number_center := number.get_global_transform_with_canvas() * (number.size * .5)
	var hud_left := get_global_transform_with_canvas() * Vector2(0,size.y*.5)
	var parent_inverse: Transform2D = pop.get_parent().get_global_transform_with_canvas().affine_inverse()
	var target: Vector2 = parent_inverse * Vector2(hud_left.x-18,number_center.y)
	pop.position = target - pop.pivot_offset
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
	var ui_root := get_tree().current_scene.get_node("UI/Root")
	# Retire stale rewards from a rebuilt HUD before displaying the single current popup.
	for old in ui_root.get_children():
		if old is Label and "CHEF POINTS" in old.text.to_upper():
			old.hide(); ui_root.remove_child(old); old.queue_free()
	var pop:=Label.new();pop.mouse_filter=Control.MOUSE_FILTER_IGNORE
	pop.name="ChefPointsReward"
	active_pop=pop
	pop.text="+%d CHEF POINTS  -  %s" % [reward.amount,reward.reason]
	pop.add_theme_font_override("font",FONT);pop.add_theme_font_size_override("font_size",21)
	pop.add_theme_color_override("font_color",Color("ffe69a"));pop.add_theme_color_override("font_outline_color",Color("292322"));pop.add_theme_constant_override("outline_size",3)
	pop.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
	ui_root.add_child(pop)
	pop.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_position_reward(pop)
	pop.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;pop.z_index=90
	pop.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	pop.modulate.a=0.0
	pop.scale=Vector2(0.85,0.85)
	var fly:=pop.create_tween();fly.tween_property(pop,"modulate:a",1.0,0.12)
	fly.parallel().tween_property(pop,"scale",Vector2.ONE,0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	fly.tween_interval(2.1)
	fly.tween_property(pop,"modulate:a",0.0,0.3)
	fly.tween_callback(func():
		pop.queue_free();active_pop=null;_show_next_reward()
	)
	_sparkle_burst(pop)
	sound.pitch_scale=1.0+minf(float(reward.amount)/200.0,0.18);sound.play()


func _sparkle_burst(pop: Control) -> void:
	for i in 8:
		var star:=Label.new();star.text="✦";star.mouse_filter=Control.MOUSE_FILTER_IGNORE
		star.add_theme_font_size_override("font_size",14 + i % 3 * 3)
		star.add_theme_color_override("font_color",Color("ffe285"))
		pop.add_child(star);star.position=Vector2(440,8)
		var angle:=float(i)*TAU/8.0
		var tw:=star.create_tween().set_parallel(true)
		tw.tween_property(star,"position",star.position+Vector2(cos(angle)*68,sin(angle)*26),0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(star,"modulate:a",0.0,0.5)
		tw.chain().tween_callback(star.queue_free)
