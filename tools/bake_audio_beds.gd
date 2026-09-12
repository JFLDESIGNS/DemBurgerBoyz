extends SceneTree
## Bake invariant continuous beds from the existing sound design, not external recordings.
const BEDS := {"hiss": "_next_burner_hiss_sample", "spray": "_next_ext_spray_sample", "shake": "_next_shaker_rattle_sample", "soda": "_next_soda_pour_sample", "ice": "_next_ice_grind_sample", "softserve": "_next_softserve_sample"}
func _init() -> void:
	var synth = load("res://scripts/game_audio.gd").new()
	DirAccess.make_dir_recursive_absolute("res://sounds/cached_beds")
	var rate := 22050
	var count := rate * 12
	var crossfade := rate / 20
	for key in BEDS:
		seed(90210 + str(key).hash())
		var samples := PackedFloat32Array()
		samples.resize(count)
		for i in count:
			samples[i] = synth.call(BEDS[key])
		for i in crossfade:
			var t := float(i) / float(crossfade - 1)
			samples[count - crossfade + i] = lerpf(samples[count - crossfade + i], samples[i], t)
		var bytes := PackedByteArray()
		bytes.resize(count * 2)
		for i in count:
			bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = rate
		stream.data = bytes
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = crossfade
		stream.loop_end = count
		var err := ResourceSaver.save(stream, "res://sounds/cached_beds/%s.res" % key, ResourceSaver.FLAG_COMPRESS)
		if err != OK:
			push_error("Audio bake failed: " + str(key))
			quit(1)
			return
		print("BAKED_AUDIO_BED ", key)
	synth.free()
	quit(0)
