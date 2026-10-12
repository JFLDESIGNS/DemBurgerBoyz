extends Node
const Food = preload("res://scripts/food_sprites.gd")
var patty: Node
const VISUAL_MELT_SECONDS := 1.2
var frames: Array[Texture2D] = []
var material: ShaderMaterial
static func wobble_envelope(age: float) -> float:
	return .39 * smoothstep(.15,1.0,age) * (1.0 - smoothstep(1.0,7.0,age))
func setup(source: Node) -> void:
	patty = source
	var char_amount = patty.build_char_amount() if patty.has_method("build_char_amount") else 0.0
	frames.clear()
	for i in Food.CHEESE_MELT_FRAME_COUNT:
		frames.append(Food.build_patty_state_tex(char_amount, true, float(i)/float(Food.CHEESE_MELT_FRAME_COUNT-1)))
	material = ShaderMaterial.new()
	material.shader = preload("res://shaders/cheese_melt_blend.gdshader")
	get_parent().material = material
	_process(0.0)
func _process(_delta: float) -> void:
	if not is_instance_valid(patty) or frames.is_empty(): return
	var last := frames.size()-1
	var age = patty.get("cheese_effect_age")
	if age == null: age = float(patty.cheese_melt)*3.0
	var progress = clampf(float(age)/VISUAL_MELT_SECONDS, 0.0, 1.0)*float(last)
	var first = mini(last, int(progress))
	var next = mini(last, first+1)
	get_parent().texture = frames[first]
	material.set_shader_parameter("next_state", (frames[next] as AtlasTexture).atlas)
	# Constant movement through the sequence; easing each pair caused 11 tiny stops.
	material.set_shader_parameter("blend_amount", progress-first)
	material.set_shader_parameter("wobble_age", float(age))
	material.set_shader_parameter("wobble_amount", wobble_envelope(float(age)))
