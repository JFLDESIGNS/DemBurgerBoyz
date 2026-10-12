extends SceneTree
class PattyProbe extends Node3D:
	var has_cheese := true
	var cheese_melt := 0.0
	var cheese_effect_age := 0.0
	func cheese_ready(): return cheese_melt >= 1.0
func _initialize():call_deferred("run")
func run():
	var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/main_ticket_harness.gd"));root.add_child(g);current_scene=g
	for i in g.STATION_COUNT: g.stations.append({"items":[],"patties":[],"preview":null})
	var p=PattyProbe.new();g.add_child(p);g.stations[0].patties=[p]
	var prior:Texture2D
	for i in 12:
		p.cheese_melt=float(i)/11.0
		g._update_station_cheese_melt(.1)
		assert(g.stations[0].cheese_visual_frames==[i])
		var tex=g._station_patty_layer_tex(g.stations[0],0,true)
		assert(tex!=prior,"Each gameplay melt phase must select a different sprite")
		prior=tex
	var sprite=TextureRect.new();g.add_child(sprite)
	var blend=load("res://scripts/build_cheese_blend.gd").new();sprite.add_child(blend);blend.setup(p)
	assert(is_zero_approx(blend.wobble_envelope(0.0)))
	assert(is_equal_approx(blend.wobble_envelope(1.0),1.0))
	assert(is_equal_approx(blend.wobble_envelope(2.0),1.0))
	assert(is_equal_approx(blend.wobble_envelope(3.0),1.0))
	assert(is_equal_approx(blend.wobble_envelope(3.5),1.0))
	assert(blend.wobble_envelope(4.0)>0 and blend.wobble_envelope(4.0)<1)
	assert(blend.wobble_envelope(5.0)>.6,"Wobble remains visible after melting")
	var region:Rect2=(blend.frames[0] as AtlasTexture).region
	for frame in blend.frames: assert((frame as AtlasTexture).region==region,"Melt states must share a fixed anchor")
	p.cheese_effect_age=.6;blend._process(0)
	assert(is_equal_approx(blend.material.get_shader_parameter("blend_amount"),.5))
	p.cheese_effect_age=1.2;blend._process(0)
	assert(sprite.texture==blend.frames[11])
	for i in 11:
		p.cheese_effect_age=(float(i)+.5)/11.0*1.2;blend._process(0)
		assert(is_equal_approx(blend.material.get_shader_parameter("blend_amount"),.5))
	print("BUILD_CHEESE_MELT_OK")
	quit()
