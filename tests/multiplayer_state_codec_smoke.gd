extends SceneTree
const Codec = preload("res://scripts/multiplayer_state_codec.gd")
func _init() -> void:
	var host = Codec.new()
	var guest = Codec.new()
	var initial: Array = [[11, 12], [0.1234, 0.5], [true, false], 100]
	for i in 40: initial[0].append(100 + i)
	var first: Dictionary = host.encode("grill", initial)
	assert(guest.decode("grill", first) == host.quantized(initial))
	assert(host.encode("grill", initial).is_empty())
	var changed := initial.duplicate(true)
	changed[1][0] = 0.456
	var delta: Dictionary = host.encode("grill", changed)
	assert(not delta.full and var_to_bytes(delta.patch).size() < var_to_bytes(changed).size())
	assert(guest.decode("grill", delta) == host.quantized(changed))
	assert(guest.decode("grill", first).is_empty())
	changed[3] = 90
	host.encode("grill", changed) # Deliberately dropped revision.
	changed[3] = 80
	assert(guest.decode("grill", host.encode("grill", changed)).is_empty())
	assert(guest.decode("grill", host.encode("grill", changed, true)) == host.quantized(changed))
	changed[0].remove_at(0)
	changed[1].remove_at(0)
	changed[2].remove_at(0)
	assert(guest.decode("grill", host.encode("grill", changed)) == host.quantized(changed))
	var repair := {"rev": host.revisions.grill, "repair": true, "full": true, "patch": {"v": host.quantized(changed)}}
	assert(guest.decode("grill", repair) == host.quantized(changed))
	print("MULTIPLAYER_STATE_CODEC_OK")
	quit()
