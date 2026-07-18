## WebSocket multiplayer peer that talks to the Railway room relay.
## Host peer_id=1, joiners 2–4. Game packets are fully relayed (works over NAT).
class_name RelayMultiplayerPeer
extends MultiplayerPeerExtension

signal relay_hosted(code: String)
signal relay_joined(code: String)
signal relay_failed(message: String)

const HEADER_SIZE := 10
const MAGIC := 0x47

var _ws: WebSocketPeer = WebSocketPeer.new()
var _url: String = ""
var _status: MultiplayerPeer.ConnectionStatus = MultiplayerPeer.CONNECTION_DISCONNECTED
var _unique_id: int = 0
var _acting_as_server: bool = false
var _refuse: bool = false
var _transfer_mode: MultiplayerPeer.TransferMode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
var _transfer_channel: int = 0
var _target_peer: int = 0
var _room_code: String = ""
var _want_host: bool = false
var _want_join_code: String = ""
var _player_name: String = "Cook"

var _inbox: Array = [] ## [{from, channel, mode, data}]
var _current_from: int = 1
var _current_channel: int = 0
var _current_mode: MultiplayerPeer.TransferMode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
var _peer_connected_emitted: Dictionary = {} ## peer_id -> true


func host_online(url: String, player_name: String = "Cook") -> Error:
	return _begin(url, true, "", player_name)


func join_online(url: String, code: String, player_name: String = "Cook") -> Error:
	return _begin(url, false, code, player_name)


func get_room_code() -> String:
	return _room_code


func _begin(url: String, as_host: bool, code: String, player_name: String) -> Error:
	close()
	_url = _normalize_ws_url(url)
	if _url == "":
		relay_failed.emit("Missing relay URL (set Online relay in the lobby)")
		return ERR_INVALID_PARAMETER
	_want_host = as_host
	_want_join_code = code
	_player_name = player_name.strip_edges()
	if _player_name == "":
		_player_name = "Cook"
	_status = MultiplayerPeer.CONNECTION_CONNECTING
	var err := _ws.connect_to_url(_url)
	if err != OK:
		_status = MultiplayerPeer.CONNECTION_DISCONNECTED
		relay_failed.emit("Could not reach online relay")
		return err
	return OK


func _normalize_ws_url(raw: String) -> String:
	var u := raw.strip_edges()
	if u == "":
		return ""
	if u.begins_with("https://"):
		u = "wss://" + u.substr(8)
	elif u.begins_with("http://"):
		u = "ws://" + u.substr(7)
	elif not u.begins_with("ws://") and not u.begins_with("wss://"):
		u = "wss://" + u
	## Strip trailing slash.
	while u.ends_with("/"):
		u = u.substr(0, u.length() - 1)
	return u


func _poll() -> void:
	if _ws == null:
		return
	_ws.poll()
	var st := _ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		if _status == MultiplayerPeer.CONNECTION_CONNECTING and _unique_id == 0:
			## First open — request host/join.
			if _want_host:
				_send_json({"op": "host", "name": _player_name})
			else:
				_send_json({"op": "join", "code": _want_join_code, "name": _player_name})
		while _ws.get_available_packet_count() > 0:
			var packet := _ws.get_packet()
			if _ws.was_string_packet():
				_handle_json(packet.get_string_from_utf8())
			else:
				_handle_binary(packet)
	elif st == WebSocketPeer.STATE_CLOSING or st == WebSocketPeer.STATE_CLOSED:
		if _status != MultiplayerPeer.CONNECTION_DISCONNECTED:
			var was_connected := _status == MultiplayerPeer.CONNECTION_CONNECTED
			_status = MultiplayerPeer.CONNECTION_DISCONNECTED
			if was_connected:
				## Notify SceneMultiplayer that peers dropped.
				for pid in _peer_connected_emitted.keys():
					peer_disconnected.emit(int(pid))
				_peer_connected_emitted.clear()


func _send_json(obj: Dictionary) -> void:
	if _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	_ws.send_text(JSON.stringify(obj))


func _handle_json(text: String) -> void:
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return
	var op := str(data.get("op", ""))
	match op:
		"hosted":
			_room_code = str(data.get("code", ""))
			_unique_id = int(data.get("peer_id", 1))
			_acting_as_server = true
			_status = MultiplayerPeer.CONNECTION_CONNECTED
			relay_hosted.emit(_room_code)
		"joined":
			_room_code = str(data.get("code", ""))
			_unique_id = int(data.get("peer_id", 2))
			_acting_as_server = false
			_status = MultiplayerPeer.CONNECTION_CONNECTED
			## Announce every peer already in the room (host + earlier cooks).
			var existing: Array = data.get("peers", [])
			if existing.is_empty():
				_emit_peer_connected(1)
			else:
				for pid_v in existing:
					_emit_peer_connected(int(pid_v))
			relay_joined.emit(_room_code)
		"peer_joined":
			var pid := int(data.get("peer_id", 2))
			_emit_peer_connected(pid)
		"peer_left":
			var left_id := int(data.get("peer_id", 0))
			if _peer_connected_emitted.has(left_id):
				_peer_connected_emitted.erase(left_id)
				peer_disconnected.emit(left_id)
		"error":
			var msg := str(data.get("msg", "relay error"))
			_status = MultiplayerPeer.CONNECTION_DISCONNECTED
			relay_failed.emit(msg)
			_ws.close()
		"hello", "pong":
			pass


func _emit_peer_connected(pid: int) -> void:
	if pid <= 0 or _peer_connected_emitted.has(pid):
		return
	_peer_connected_emitted[pid] = true
	peer_connected.emit(pid)


func _handle_binary(packet: PackedByteArray) -> void:
	if packet.size() < HEADER_SIZE:
		return
	if packet[0] != MAGIC:
		return
	var from_id := _read_u32(packet, 1)
	var channel := int(packet[9])
	## byte 8 = mode
	var mode := int(packet[8]) as MultiplayerPeer.TransferMode
	var payload := packet.slice(HEADER_SIZE)
	_inbox.append({
		"from": from_id,
		"channel": channel,
		"mode": mode,
		"data": payload,
	})


func _read_u32(buf: PackedByteArray, offset: int) -> int:
	return buf[offset] | (buf[offset + 1] << 8) | (buf[offset + 2] << 16) | (buf[offset + 3] << 24)


func _write_u32(buf: PackedByteArray, offset: int, value: int) -> void:
	buf[offset] = value & 0xFF
	buf[offset + 1] = (value >> 8) & 0xFF
	buf[offset + 2] = (value >> 16) & 0xFF
	buf[offset + 3] = (value >> 24) & 0xFF


func _put_packet_script(buffer: PackedByteArray) -> Error:
	if _status != MultiplayerPeer.CONNECTION_CONNECTED:
		return ERR_UNCONFIGURED
	if _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return ERR_CANT_CONNECT
	## 0 = relay broadcasts to every other peer in the room (up to 4 cooks).
	var target := _target_peer
	var out := PackedByteArray()
	out.resize(HEADER_SIZE + buffer.size())
	out[0] = MAGIC
	_write_u32(out, 1, _unique_id)
	_write_u32(out, 5, target)
	out[8] = int(_transfer_mode)
	out[9] = _transfer_channel & 0xFF
	for i in buffer.size():
		out[HEADER_SIZE + i] = buffer[i]
	var err := _ws.put_packet(out)
	return err


func _get_packet_script() -> PackedByteArray:
	## Pop after SceneMultiplayer has already peeked peer/channel/mode via the getters below.
	if _inbox.is_empty():
		return PackedByteArray()
	var item: Dictionary = _inbox.pop_front()
	_current_from = int(item.get("from", 1))
	_current_channel = int(item.get("channel", 0))
	_current_mode = item.get("mode", MultiplayerPeer.TRANSFER_MODE_RELIABLE) as MultiplayerPeer.TransferMode
	return item.get("data", PackedByteArray()) as PackedByteArray


func _get_available_packet_count() -> int:
	return _inbox.size()


func _get_max_packet_size() -> int:
	return 65535


func _peek_inbox() -> Dictionary:
	## Godot reads peer/channel/mode BEFORE get_packet — must peek front, not last-popped.
	if _inbox.is_empty():
		return {}
	return _inbox[0] as Dictionary


func _get_packet_channel() -> int:
	var item := _peek_inbox()
	if item.is_empty():
		return _current_channel
	return int(item.get("channel", 0))


func _get_packet_mode() -> MultiplayerPeer.TransferMode:
	var item := _peek_inbox()
	if item.is_empty():
		return _current_mode
	return item.get("mode", MultiplayerPeer.TRANSFER_MODE_RELIABLE) as MultiplayerPeer.TransferMode


func _get_packet_peer() -> int:
	var item := _peek_inbox()
	if item.is_empty():
		return maxi(_current_from, 1)
	return maxi(int(item.get("from", 1)), 1)


func _set_transfer_channel(channel: int) -> void:
	_transfer_channel = channel


func _set_transfer_mode(mode: MultiplayerPeer.TransferMode) -> void:
	_transfer_mode = mode


func _get_transfer_channel() -> int:
	return _transfer_channel


func _get_transfer_mode() -> MultiplayerPeer.TransferMode:
	return _transfer_mode


func _set_target_peer(peer: int) -> void:
	_target_peer = peer


func _get_unique_id() -> int:
	return maxi(_unique_id, 0)


func _is_server() -> bool:
	return _acting_as_server


func _is_server_relay_supported() -> bool:
	return true


func _get_connection_status() -> MultiplayerPeer.ConnectionStatus:
	return _status


func _close() -> void:
	_inbox.clear()
	_peer_connected_emitted.clear()
	_unique_id = 0
	_acting_as_server = false
	_room_code = ""
	_status = MultiplayerPeer.CONNECTION_DISCONNECTED
	if _ws != null:
		if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN \
				or _ws.get_ready_state() == WebSocketPeer.STATE_CONNECTING:
			_ws.close()
		_ws = WebSocketPeer.new()


func _disconnect_peer(_peer: int, _force: bool) -> void:
	## Room relay — closing this socket drops us from the room.
	close()


func _set_refuse_new_connections(enable: bool) -> void:
	_refuse = enable


func _is_refusing_new_connections() -> bool:
	return _refuse
