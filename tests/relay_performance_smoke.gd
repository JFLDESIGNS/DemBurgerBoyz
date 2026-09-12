extends SceneTree
const Peer = preload("res://scripts/relay_multiplayer_peer.gd")
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var host = Peer.new()
	var guest = Peer.new()
	host.host_online("ws://127.0.0.1:18769", "Performance test host")
	var deadline := Time.get_ticks_msec() + 10000
	while host.get_room_code() == "" and Time.get_ticks_msec() < deadline:
		host._poll()
		await process_frame
	if host.get_room_code() == "":
		push_error("Local relay host timed out")
		quit(1)
		return
	guest.join_online("ws://127.0.0.1:18769", host.get_room_code(), "Performance test guest")
	while guest._unique_id == 0 and Time.get_ticks_msec() < deadline:
		host._poll()
		guest._poll()
		await process_frame
	if guest._unique_id == 0:
		push_error("Local relay join timed out")
		quit(1)
		return
	host._target_peer = guest._unique_id
	for i in 400:
		var bytes := PackedByteArray()
		bytes.resize(4096)
		bytes.fill(i % 255)
		bytes.encode_u32(0, i)
		host._put_packet_script(bytes)
	var received := 0
	deadline = Time.get_ticks_msec() + 15000
	while received < 400 and Time.get_ticks_msec() < deadline:
		host._poll()
		guest._poll()
		while guest._get_available_packet_count() > 0:
			var bytes: PackedByteArray = guest._get_packet_script()
			if bytes.size() != 4096 or bytes.decode_u32(0) != received:
				push_error("Relay lost packet order or payload")
				quit(1)
				return
			received += 1
		await process_frame
	var stats: Dictionary = host.get_transport_stats()
	print("RELAY_BURST packets=", received, " stats=", stats)
	host.close()
	guest.close()
	if received != 400:
		push_error("Relay did not deliver the complete burst")
	print("RELAY_PERFORMANCE_SMOKE_OK" if received == 400 else "RELAY_PERFORMANCE_SMOKE_FAILED")
	quit(0 if received == 400 else 1)
