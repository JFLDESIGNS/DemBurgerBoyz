extends SceneTree
func rms(data: PackedByteArray, rate: int, start: float, length: float) -> float:
	var energy := 0.0
	var count := int(length*rate)
	for i in count:
		var sample := float(data.decode_s16((int(start*rate)+i)*2))/32768.0
		energy += sample*sample
	return sqrt(energy/count)
func _initialize():
	var audio=load("res://scripts/game_audio.gd").new()
	var wav=audio._make_cheese_sizzle()
	assert(is_equal_approx(wav.get_length(),2.0))
	var early=rms(wav.data,wav.mix_rate,.2,.2)
	var held=rms(wav.data,wav.mix_rate,.7,.2)
	var fading=rms(wav.data,wav.mix_rate,1.5,.2)
	var end=rms(wav.data,wav.mix_rate,1.9,.09)
	assert(held>early*.85 and held<early*1.15)
	assert(fading<held*.6 and end<held*.04)
	assert(audio._sfx_category_for_cache_key("hot_oil_cheese")=="cooking")
	audio.free()
	print("CHEESE_SIZZLE_OK: 1s hold, 1s fade, cooking volume category")
	quit()
