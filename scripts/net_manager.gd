## Peer-to-peer co-op: Railway WebSocket relay (internet) + ENet LAN fallback.
extends Node

signal connection_changed
signal rooms_updated
signal peer_ready_changed
signal session_start_requested(seed: int)
signal peer_joined_live(peer_id: int) ## Host: cook joined mid-shift — push kitchen snapshot
signal chat_flash(text: String, color: Color)

const RelayPeerScript := preload("res://scripts/relay_multiplayer_peer.gd")

## Port = CODE_PORT_BASE + code (0000–9999) → 41000–50999 (LAN / same-PC only)
const CODE_PORT_BASE := 41000
const DISCOVERY_PORT := 7770
const MAX_PLAYERS := 4
const ROOM_STALE_SEC := 5.0
const BROADCAST_INTERVAL := 0.75
const JOIN_SEEK_SEC := 12.0
const LOCAL_ROOMS_PATH := "user://burger_mp_rooms.json"
const RELAY_CFG_PATH := "user://mp_relay.cfg"
const MAGIC := "FTFLIP_ROOM_v2"

## Paste your Railway public URL (https://… or wss://…). Empty = LAN-only.
## Production relay (jfldesigns Railway):
const DEFAULT_RELAY_URL := "wss://burger-pals-mp-production.up.railway.app"

const GAME_PORT_MIN := CODE_PORT_BASE
const GAME_PORT_MAX := CODE_PORT_BASE + 9999

enum Role { NONE, HOST, CLIENT }

var role: Role = Role.NONE
var room_name: String = "Burger Truck"
var player_name: String = "Cook"
var room_code: String = "0000"
var game_port: int = CODE_PORT_BASE
var connected: bool = false
var peers_ready: Dictionary = {}
var peer_names: Dictionary = {} ## peer_id -> display name
var discovered_rooms: Array = []
var lan_ip: String = "127.0.0.1"
var relay_url: String = DEFAULT_RELAY_URL
var online_mode: bool = false ## true when using Railway relay
var session_active: bool = false
var last_session_seed: int = 0

var _peer: MultiplayerPeer = null
var _enet: ENetMultiplayerPeer = null
var _relay = null ## RelayMultiplayerPeer
var _broadcaster: PacketPeerUDP = null
var _listener: PacketPeerUDP = null
var _broadcast_accum: float = 0.0
var _listen_accum: float = 0.0
var _local_poll_accum: float = 0.0
var _listening: bool = false
var _next_net_id: int = 1
var _broadcast_targets: Array[String] = []
var _joining_code: String = ""
var _join_seek_left: float = 0.0

const PEER_COLORS := [
	Color(1.0, 0.55, 0.2),
	Color(0.35, 0.85, 1.0),
	Color(0.55, 0.9, 0.45),
	Color(0.95, 0.55, 0.85),
]


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	player_name = _default_player_name()
	_load_relay_url()
	_refresh_network_info()


func _process(delta: float) -> void:
	if role == Role.HOST and connected and not online_mode:
		_broadcast_accum += delta
		if _broadcast_accum >= BROADCAST_INTERVAL:
			_broadcast_accum = 0.0
			_broadcast_room()
			_write_local_room()
	if _listening:
		_listen_accum += delta
		if _listen_accum >= 0.2:
			_listen_accum = 0.0
			_poll_discovery()
			_prune_rooms()
	_local_poll_accum += delta
	if _local_poll_accum >= 0.4:
		_local_poll_accum = 0.0
		if _listening or role == Role.NONE or _join_seek_left > 0.0:
			_poll_local_rooms()
	_update_join_seek(delta)


func is_online() -> bool:
	return connected and multiplayer.multiplayer_peer != null \
		and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func is_host() -> bool:
	return role == Role.HOST and is_online()


func is_client() -> bool:
	return role == Role.CLIENT and is_online()


func my_id() -> int:
	if not is_online():
		return 1
	return multiplayer.get_unique_id()


func peer_count() -> int:
	if not is_online():
		return 1
	return multiplayer.get_peers().size() + 1


func connected_peer_ids() -> Array[int]:
	var ids: Array[int] = []
	if not is_online():
		ids.append(1)
		return ids
	ids.append(my_id())
	for p in multiplayer.get_peers():
		ids.append(int(p))
	ids.sort()
	return ids


func color_for_peer(peer_id: int) -> Color:
	var idx := clampi(peer_id - 1, 0, PEER_COLORS.size() - 1)
	return PEER_COLORS[idx]


func name_for_peer(peer_id: int) -> String:
	if peer_names.has(peer_id):
		var n := str(peer_names[peer_id]).strip_edges()
		if n != "":
			return n
	if peer_id == my_id() and player_name.strip_edges() != "":
		return player_name.strip_edges()
	return "Cook %d" % clampi(peer_id, 1, MAX_PLAYERS)


func bump_net_id_floor(v: int) -> void:
	_next_net_id = maxi(_next_net_id, v)


func peek_next_net_id() -> int:
	return _next_net_id


func all_peers_ready() -> bool:
	if peer_count() < 2:
		return false
	for id in connected_peer_ids():
		if not bool(peers_ready.get(int(id), false)):
			return false
	return true


func ready_summary() -> String:
	var ids := connected_peer_ids()
	var bits: Array[String] = []
	for id in ids:
		var nm := name_for_peer(int(id))
		var ok := bool(peers_ready.get(int(id), false))
		bits.append("%s%s" % [nm, " ✓" if ok else ""])
	return ", ".join(bits)


func announce_player_name() -> void:
	if not is_online():
		return
	_rpc_set_peer_name.rpc(player_name)


@rpc("any_peer", "call_local", "reliable")
func _rpc_set_peer_name(p_name: String) -> void:
	var sid := multiplayer.get_remote_sender_id()
	if sid == 0:
		sid = my_id()
	var clean := p_name.strip_edges()
	if clean == "":
		clean = "Cook"
	peer_names[sid] = clean


func alloc_net_id() -> int:
	var id := _next_net_id
	_next_net_id += 1
	return id


func has_relay_url() -> bool:
	return get_relay_url().strip_edges() != ""


func get_relay_url() -> String:
	return relay_url.strip_edges()


func set_relay_url(url: String) -> void:
	relay_url = url.strip_edges()
	_save_relay_url()


func _load_relay_url() -> void:
	if DEFAULT_RELAY_URL.strip_edges() != "":
		relay_url = DEFAULT_RELAY_URL.strip_edges()
	if not FileAccess.file_exists(RELAY_CFG_PATH):
		return
	var cfg := ConfigFile.new()
	if cfg.load(RELAY_CFG_PATH) != OK:
		return
	var saved := str(cfg.get_value("mp", "relay_url", "")).strip_edges()
	if saved != "":
		relay_url = saved


func _save_relay_url() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("mp", "relay_url", relay_url)
	cfg.save(RELAY_CFG_PATH)


static func normalize_code(raw: String) -> String:
	var digits := ""
	for ch in raw.strip_edges():
		if ch >= "0" and ch <= "9":
			digits += ch
	if digits.length() > 4:
		digits = digits.substr(digits.length() - 4, 4)
	while digits.length() < 4:
		digits = "0" + digits
	return digits


static func port_from_code(code: String) -> int:
	return CODE_PORT_BASE + int(normalize_code(code))


static func code_from_port(port: int) -> String:
	var n := clampi(port - CODE_PORT_BASE, 0, 9999)
	return "%04d" % n


func is_seeking_room() -> bool:
	return _join_seek_left > 0.0 and _joining_code != ""


func seeking_code() -> String:
	return _joining_code


func refresh_rooms() -> void:
	_refresh_network_info()
	if _listening or _join_seek_left > 0.0:
		_ensure_listener()
		_poll_discovery()
		_poll_local_rooms()
		_prune_rooms()
	rooms_updated.emit()


func begin_browse() -> void:
	_listening = true
	_refresh_network_info()
	_ensure_listener()
	_poll_local_rooms()
	rooms_updated.emit()


func stop_browse() -> void:
	_listening = false
	if _join_seek_left <= 0.0:
		_close_listener()


func find_room_by_code(code: String) -> Dictionary:
	var want := normalize_code(code)
	for r in discovered_rooms:
		if str(r.get("code", "")) == want:
			return r
	return {}


func host_room(p_name: String = "", p_room: String = "") -> Error:
	_close_listener()
	_listening = false
	_clear_join_seek()
	leave(false)
	if p_name.strip_edges() != "":
		player_name = p_name.strip_edges()
	if p_room.strip_edges() != "":
		room_name = p_room.strip_edges()
	else:
		room_name = "%s's Truck" % player_name

	_refresh_network_info()
	if has_relay_url():
		return _host_online()
	return _host_lan()


func _host_online() -> Error:
	online_mode = true
	_relay = RelayPeerScript.new()
	_relay.relay_hosted.connect(_on_relay_hosted)
	_relay.relay_failed.connect(_on_relay_failed_host)
	_relay.relay_session_start.connect(_on_relay_session_start)
	var err: Error = _relay.host_online(get_relay_url(), player_name)
	if err != OK:
		_relay = null
		online_mode = false
		return err
	_peer = _relay
	role = Role.HOST
	multiplayer.multiplayer_peer = _relay
	connected = false
	peers_ready = {1: false}
	_next_net_id = 1
	chat_flash.emit("Connecting to online relay...", Color("90CAF9"))
	connection_changed.emit()
	return OK


func _on_relay_hosted(code: String) -> void:
	room_code = normalize_code(code)
	game_port = port_from_code(room_code)
	connected = true
	peers_ready = {1: false}
	announce_player_name()
	chat_flash.emit("Online room %s — friends anywhere can join!" % room_code, Color("81C784"))
	connection_changed.emit()


func _on_relay_failed_host(message: String) -> void:
	chat_flash.emit("Online host failed: %s — trying LAN..." % message, Color("FFA726"))
	leave(false)
	var err := _host_lan()
	if err != OK:
		chat_flash.emit("Could not host room", Color("EF5350"))
		connection_changed.emit()


func _host_lan() -> Error:
	online_mode = false
	var err := ERR_CANT_CREATE
	for _attempt in 64:
		var code_n := randi() % 10000
		var code := "%04d" % code_n
		var port := port_from_code(code)
		_enet = ENetMultiplayerPeer.new()
		err = _enet.create_server(port, MAX_PLAYERS - 1)
		if err == OK:
			room_code = code
			game_port = port
			break
		_enet = null
	if err != OK or _enet == null:
		return err

	_peer = _enet
	role = Role.HOST
	multiplayer.multiplayer_peer = _enet
	connected = true
	peers_ready = {1: false}
	_next_net_id = 1
	_ensure_broadcaster()
	_broadcast_room()
	_write_local_room()
	connection_changed.emit()
	chat_flash.emit("LAN room %s — same Wi‑Fi / PC only" % room_code, Color("81C784"))
	return OK


func join_by_code(code: String, p_name: String = "") -> Error:
	code = normalize_code(code)
	if p_name.strip_edges() != "":
		player_name = p_name.strip_edges()
	leave(false)
	room_code = code
	game_port = port_from_code(code)

	if has_relay_url():
		return _join_online(code)

	## LAN / same-PC path.
	begin_browse()
	refresh_rooms()
	_joining_code = code
	var found := find_room_by_code(code)
	if not found.is_empty():
		_clear_join_seek()
		return join_room(str(found.get("ip", "127.0.0.1")), int(found.get("port", game_port)), player_name)
	_join_seek_left = JOIN_SEEK_SEC
	chat_flash.emit("Looking for LAN room %s..." % code, Color("90CAF9"))
	return join_room("127.0.0.1", game_port, player_name)


func _join_online(code: String) -> Error:
	online_mode = true
	_relay = RelayPeerScript.new()
	_relay.relay_joined.connect(_on_relay_joined)
	_relay.relay_failed.connect(_on_relay_failed_join)
	_relay.relay_session_start.connect(_on_relay_session_start)
	var err: Error = _relay.join_online(get_relay_url(), code, player_name)
	if err != OK:
		_relay = null
		online_mode = false
		return err
	_peer = _relay
	role = Role.CLIENT
	multiplayer.multiplayer_peer = _relay
	connected = false
	room_code = code
	chat_flash.emit("Joining online room %s..." % code, Color("90CAF9"))
	connection_changed.emit()
	return OK


func _on_relay_joined(code: String) -> void:
	room_code = normalize_code(code)
	connected = true
	_clear_join_seek()
	peers_ready[my_id()] = false
	announce_player_name()
	chat_flash.emit("Joined online room %s!" % room_code, Color("81C784"))
	connection_changed.emit()


func _on_relay_session_start(seed: int) -> void:
	## Railway JSON handoff — guests (and mid-joiners) enter the shift here.
	_apply_session_start(seed)


func _on_relay_failed_join(message: String) -> void:
	chat_flash.emit("Online join failed: %s" % message, Color("EF5350"))
	## Fall back to LAN hunt for that code.
	leave(false)
	begin_browse()
	refresh_rooms()
	_joining_code = room_code
	_join_seek_left = JOIN_SEEK_SEC
	chat_flash.emit("Trying LAN for room %s..." % room_code, Color("90CAF9"))
	join_room("127.0.0.1", port_from_code(room_code), player_name)


func join_room(ip: String, port: int, p_name: String = "") -> Error:
	online_mode = false
	if _peer != null or multiplayer.multiplayer_peer != null:
		if _broadcaster != null:
			_broadcaster.close()
			_broadcaster = null
		if _peer != null:
			_peer.close()
			_peer = null
		_enet = null
		_relay = null
		multiplayer.multiplayer_peer = null
	if p_name.strip_edges() != "":
		player_name = p_name.strip_edges()
	ip = ip.strip_edges()
	if ip == "" or ip.to_lower() == "localhost":
		ip = "127.0.0.1"
	room_code = code_from_port(port)
	game_port = port
	_enet = ENetMultiplayerPeer.new()
	var err := _enet.create_client(ip, port)
	if err != OK:
		_enet = null
		return err
	_peer = _enet
	role = Role.CLIENT
	multiplayer.multiplayer_peer = _enet
	connected = false
	connection_changed.emit()
	return OK


func leave(emit_signal: bool = true) -> void:
	_clear_local_room_entry()
	if _join_seek_left <= 0.0:
		_clear_join_seek()
	if _broadcaster != null:
		_broadcaster.close()
		_broadcaster = null
	if _peer != null:
		_peer.close()
		_peer = null
	_enet = null
	_relay = null
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null
	role = Role.NONE
	connected = false
	online_mode = false
	session_active = false
	last_session_seed = 0
	peers_ready.clear()
	if emit_signal:
		connection_changed.emit()


func set_ready(is_ready: bool) -> void:
	if not is_online() or session_active:
		return
	var me := my_id()
	if me <= 0:
		return
	## Optimistic local update so the Ready button flips immediately.
	peers_ready[me] = is_ready
	peer_ready_changed.emit()
	## Broadcast to every cook (relay-safe). Host also stores + re-syncs snapshot.
	_rpc_lobby_ready_state.rpc(me, is_ready)


func request_start_session() -> void:
	if not is_host():
		return
	if session_active:
		return
	if not is_online():
		chat_flash.emit("Host a room first, then Start Co-op", Color("FFA726"))
		return
	if peer_count() < 1:
		return
	if peer_count() > MAX_PLAYERS:
		chat_flash.emit("Room overflow — max %d cooks" % MAX_PLAYERS, Color("EF5350"))
		return
	if peer_count() == 1:
		chat_flash.emit("Starting solo — friends can still join with code %s" % room_code, Color("81C784"))
	elif not all_peers_ready():
		chat_flash.emit("Starting — friends can still join mid-shift with the code", Color("FFCC80"))
	_host_begin_session(randi())


func _host_set_peer_ready(peer_id: int, is_ready: bool) -> void:
	if not is_host() or session_active:
		return
	if peer_id <= 0 or peer_id > MAX_PLAYERS:
		return
	peers_ready[peer_id] = is_ready
	_broadcast_lobby_ready()
	peer_ready_changed.emit()


func _broadcast_lobby_ready() -> void:
	if not is_host():
		return
	var ready_ids: Array = []
	for id in connected_peer_ids():
		if bool(peers_ready.get(int(id), false)):
			ready_ids.append(int(id))
	_rpc_sync_lobby_ready.rpc(ready_ids)


func _host_begin_session(session_seed: int) -> void:
	if not is_host() or session_active:
		return
	if peer_count() < 1 or peer_count() > MAX_PLAYERS:
		return
	last_session_seed = session_seed
	## Keep the room open for mid-shift joins (code) until we hit max cooks.
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.refuse_new_connections = peer_count() >= MAX_PLAYERS
	## Host enters immediately.
	_apply_session_start(session_seed)
	## Online: JSON room broadcast (reliable). LAN: Godot RPC fallback.
	if online_mode and _relay != null and is_instance_valid(_relay):
		_relay.send_session_start(session_seed)
		## Repeat once next frame in case a guest just connected.
		call_deferred("_deferred_resend_session_start", session_seed)
	else:
		_rpc_start_session.rpc(session_seed)
		if multiplayer.multiplayer_peer != null:
			for p in multiplayer.get_peers():
				_rpc_start_session.rpc_id(int(p), session_seed)
	if peer_count() <= 1:
		chat_flash.emit("Shift live — share code %s for late joins" % room_code, Color("FFEB3B"))
	else:
		chat_flash.emit("Shift starting — pulling %d cooks in!" % peer_count(), Color("FFEB3B"))


func _deferred_resend_session_start(session_seed: int) -> void:
	if not is_host() or not online_mode:
		return
	if _relay == null or not is_instance_valid(_relay):
		return
	_relay.send_session_start(session_seed)


func _apply_session_start(session_seed: int) -> void:
	## Idempotent — host local + JSON + RPC may all fire.
	if session_active:
		return
	session_active = true
	last_session_seed = session_seed
	session_start_requested.emit(session_seed)


func _peer_known_in_room(peer_id: int) -> bool:
	if peer_id <= 0 or peer_id > MAX_PLAYERS:
		return false
	if peer_id == my_id():
		return true
	if not is_online():
		return false
	for p in multiplayer.get_peers():
		if int(p) == peer_id:
			return true
	return peers_ready.has(peer_id)


@rpc("any_peer", "call_local", "reliable")
func _rpc_lobby_ready_state(claimed_id: int, is_ready: bool) -> void:
	## Every peer announces Ready. Prefer network sender id; claimed_id covers relay quirks.
	if session_active:
		return
	var sid := multiplayer.get_remote_sender_id()
	var peer_id := sid if sid > 0 else int(claimed_id)
	if peer_id <= 0:
		peer_id = int(claimed_id)
	if peer_id <= 0 or peer_id > MAX_PLAYERS:
		return
	peers_ready[peer_id] = is_ready
	if is_host():
		## Authoritative snapshot so guests never miss a checkmark.
		_broadcast_lobby_ready()
	peer_ready_changed.emit()


@rpc("any_peer", "reliable")
func _rpc_request_ready(is_ready: bool, claimed_id: int = 0) -> void:
	## Legacy path — still accept direct-to-host ready in case old clients call it.
	if not is_host() or session_active:
		return
	var sid := multiplayer.get_remote_sender_id()
	var peer_id := sid if sid > 0 else int(claimed_id)
	if peer_id <= 0:
		peer_id = int(claimed_id)
	if peer_id <= 0 or peer_id > MAX_PLAYERS:
		return
	_host_set_peer_ready(peer_id, is_ready)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_sync_lobby_ready(ready_ids: Array) -> void:
	## Host snapshot of lobby checkmarks for every guest (any_peer: relay sender id can be flaky).
	if is_host() or session_active:
		return
	var sid := multiplayer.get_remote_sender_id()
	## Accept host (1) or unknown sender (0) from the WebSocket relay.
	if sid > 1:
		return
	peers_ready.clear()
	for id in connected_peer_ids():
		peers_ready[int(id)] = false
	for rid in ready_ids:
		peers_ready[int(rid)] = true
	## Keep our own optimistic Ready if the snapshot races ahead of the host apply.
	peer_ready_changed.emit()


@rpc("any_peer", "call_local", "reliable")
func _rpc_start_session(session_seed: int) -> void:
	## LAN / legacy path — online uses Railway JSON session_start instead.
	var sid := multiplayer.get_remote_sender_id()
	if sid > 1:
		return
	_apply_session_start(session_seed)


@rpc("any_peer", "call_local", "reliable")
func _rpc_join_in_progress(session_seed: int) -> void:
	## Late joiner only — pull them into the live shift with the same seed.
	var sid := multiplayer.get_remote_sender_id()
	## Accept host (1) or unknown sender (0) from the WebSocket relay.
	if sid > 1:
		return
	_apply_session_start(session_seed)


func _update_join_seek(delta: float) -> void:
	if _join_seek_left <= 0.0 or _joining_code == "":
		return
	if is_online():
		_clear_join_seek()
		return
	_join_seek_left -= delta
	_poll_discovery()
	_poll_local_rooms()
	var found := find_room_by_code(_joining_code)
	if not found.is_empty():
		var ip := str(found.get("ip", "127.0.0.1"))
		var port := int(found.get("port", port_from_code(_joining_code)))
		if role == Role.CLIENT and not connected:
			_clear_peer_only()
		_clear_join_seek()
		join_room(ip, port, player_name)
		return
	if _join_seek_left <= 0.0:
		var code := _joining_code
		_clear_join_seek()
		leave(false)
		chat_flash.emit("No room found for code %s" % code, Color("EF5350"))
		connection_changed.emit()


func _clear_join_seek() -> void:
	_joining_code = ""
	_join_seek_left = 0.0


func _clear_peer_only() -> void:
	if _peer != null:
		_peer.close()
		_peer = null
	_enet = null
	_relay = null
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null
	role = Role.NONE
	connected = false
	online_mode = false


func _on_peer_connected(id: int) -> void:
	peers_ready[id] = false
	## New cook joins unreadied — clear everyone's Ready so the party re-confirms.
	if role == Role.HOST and not session_active:
		for pid in connected_peer_ids():
			peers_ready[int(pid)] = false
		peers_ready[id] = false
	if role == Role.HOST:
		if session_active:
			chat_flash.emit("Cook joined mid-shift — syncing kitchen...", Color("81C784"))
			_rpc_join_in_progress.rpc_id(id, last_session_seed)
			peer_joined_live.emit(id)
		else:
			chat_flash.emit("Cook joined room %s! (%d/%d)" % [room_code, peer_count(), MAX_PLAYERS], Color("81C784"))
			_broadcast_lobby_ready()
		if not online_mode:
			_write_local_room()
			_broadcast_room()
		## Full at 4 — stop taking more seats until someone leaves.
		if peer_count() >= MAX_PLAYERS and multiplayer.multiplayer_peer != null:
			multiplayer.multiplayer_peer.refuse_new_connections = true
	announce_player_name()
	connection_changed.emit()
	peer_ready_changed.emit()


func _on_peer_disconnected(id: int) -> void:
	peers_ready.erase(id)
	peer_names.erase(id)
	chat_flash.emit("Cook left the truck", Color("EF5350"))
	if role == Role.HOST:
		if multiplayer.multiplayer_peer != null:
			multiplayer.multiplayer_peer.refuse_new_connections = peer_count() >= MAX_PLAYERS
		if not session_active:
			_broadcast_lobby_ready()
		if not online_mode:
			_write_local_room()
			_broadcast_room()
	connection_changed.emit()
	peer_ready_changed.emit()


func _on_connected_to_server() -> void:
	## ENet client path.
	if online_mode:
		return
	connected = true
	_clear_join_seek()
	peers_ready[my_id()] = false
	announce_player_name()
	chat_flash.emit("Joined room %s!" % room_code, Color("81C784"))
	connection_changed.emit()


func _on_connection_failed() -> void:
	if online_mode:
		return
	if _join_seek_left > 0.0 and _joining_code != "":
		_clear_peer_only()
		chat_flash.emit("Searching LAN for room %s..." % _joining_code, Color("90CAF9"))
		connection_changed.emit()
		_ensure_listener()
		return
	chat_flash.emit("Could not join room", Color("EF5350"))
	leave()


func _on_server_disconnected() -> void:
	chat_flash.emit("Host closed the room", Color("EF5350"))
	leave()


func _default_player_name() -> String:
	var n := OS.get_environment("USERNAME")
	if n.strip_edges() == "":
		n = OS.get_environment("USER")
	if n.strip_edges() == "":
		n = "Cook"
	return n.substr(0, 12)


func _refresh_network_info() -> void:
	lan_ip = "127.0.0.1"
	_broadcast_targets = ["255.255.255.255", "127.0.0.1"]
	var addrs := IP.get_local_addresses()
	var preferred := ""
	for a in addrs:
		var ip := str(a)
		if not _is_usable_ipv4(ip):
			continue
		if preferred == "":
			preferred = ip
		if ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172."):
			preferred = ip
			break
	if preferred != "":
		lan_ip = preferred
	for a in addrs:
		var ip := str(a)
		if not _is_usable_ipv4(ip):
			continue
		var bcast := _guess_broadcast(ip)
		if bcast != "" and bcast not in _broadcast_targets:
			_broadcast_targets.append(bcast)
		if ip not in _broadcast_targets:
			_broadcast_targets.append(ip)


func _is_usable_ipv4(ip: String) -> bool:
	if ip.find(":") >= 0:
		return false
	if ip.begins_with("127.") or ip == "0.0.0.0":
		return false
	if ip.begins_with("169.254."):
		return false
	return ip.split(".").size() == 4


func _guess_broadcast(ip: String) -> String:
	var parts := ip.split(".")
	if parts.size() != 4:
		return ""
	return "%s.%s.%s.255" % [parts[0], parts[1], parts[2]]


func _ensure_broadcaster() -> void:
	if _broadcaster != null:
		return
	_broadcaster = PacketPeerUDP.new()
	_broadcaster.set_broadcast_enabled(true)


func _ensure_listener() -> void:
	if _listener != null:
		return
	_listener = PacketPeerUDP.new()
	var err := _listener.bind(DISCOVERY_PORT)
	if err != OK:
		_listener = null


func _close_listener() -> void:
	if _listener != null:
		_listener.close()
		_listener = null


func _room_payload() -> Dictionary:
	return {
		"magic": MAGIC,
		"code": room_code,
		"name": room_name,
		"port": game_port,
		"players": peer_count(),
		"max": MAX_PLAYERS,
		"host": player_name,
		"lan_ip": lan_ip,
		"updated": Time.get_unix_time_from_system(),
	}


func _broadcast_room() -> void:
	if online_mode:
		return
	if _broadcaster == null:
		_ensure_broadcaster()
	if _broadcaster == null:
		return
	_refresh_network_info()
	var bytes := JSON.stringify(_room_payload()).to_utf8_buffer()
	for addr in _broadcast_targets:
		_broadcaster.set_dest_address(addr, DISCOVERY_PORT)
		_broadcaster.put_packet(bytes)


func _poll_discovery() -> void:
	if _listener == null:
		return
	var changed := false
	while _listener.get_available_packet_count() > 0:
		var packet_ip := _listener.get_packet_ip()
		var bytes := _listener.get_packet()
		var text := bytes.get_string_from_utf8()
		var data = JSON.parse_string(text)
		if typeof(data) != TYPE_DICTIONARY:
			continue
		var magic := str(data.get("magic", ""))
		if magic != MAGIC and magic != "FTFLIP_ROOM_v1":
			continue
		var port := int(data.get("port", CODE_PORT_BASE))
		var code := str(data.get("code", "")).strip_edges()
		if code == "":
			code = code_from_port(port)
		else:
			code = normalize_code(code)
		data["code"] = code
		var ip := str(data.get("lan_ip", "")).strip_edges()
		if ip == "" or ip == "0.0.0.0" or ip.begins_with("127."):
			ip = packet_ip
		if ip == "" or ip == "0.0.0.0":
			ip = "127.0.0.1"
		if role == Role.HOST and code == room_code:
			continue
		changed = _upsert_room(ip, port, data) or changed
	if changed:
		rooms_updated.emit()


func _upsert_room(ip: String, port: int, data: Dictionary) -> bool:
	var code := normalize_code(str(data.get("code", code_from_port(port))))
	var key := code
	var entry := {
		"key": key,
		"code": code,
		"name": str(data.get("name", "Open Truck")),
		"ip": ip,
		"port": port,
		"players": int(data.get("players", 1)),
		"max": int(data.get("max", MAX_PLAYERS)),
		"host": str(data.get("host", "")),
		"updated": float(data.get("updated", Time.get_unix_time_from_system())),
	}
	for i in discovered_rooms.size():
		if str(discovered_rooms[i].get("key", "")) == key \
				or str(discovered_rooms[i].get("code", "")) == code:
			var prev: Dictionary = discovered_rooms[i]
			discovered_rooms[i] = entry
			return int(prev.get("players", -1)) != entry.players \
				or str(prev.get("name", "")) != entry.name \
				or str(prev.get("ip", "")) != entry.ip \
				or str(prev.get("host", "")) != entry.host
	discovered_rooms.append(entry)
	return true


func _prune_rooms() -> void:
	var now := Time.get_unix_time_from_system()
	var before := discovered_rooms.size()
	var keep: Array = []
	for r in discovered_rooms:
		if now - float(r.get("updated", 0.0)) <= ROOM_STALE_SEC:
			keep.append(r)
	discovered_rooms = keep
	if discovered_rooms.size() != before:
		rooms_updated.emit()


func _write_local_room() -> void:
	if role != Role.HOST or online_mode:
		return
	var rooms: Array = _read_local_rooms_raw()
	var payload := _room_payload()
	payload["ip"] = "127.0.0.1"
	payload["lan_ip"] = lan_ip
	var found := false
	for i in rooms.size():
		var r: Dictionary = rooms[i]
		if normalize_code(str(r.get("code", ""))) == room_code \
				or int(r.get("port", -1)) == game_port:
			rooms[i] = payload
			found = true
			break
	if not found:
		rooms.append(payload)
	var now := Time.get_unix_time_from_system()
	var cleaned: Array = []
	for r in rooms:
		if now - float(r.get("updated", 0.0)) <= ROOM_STALE_SEC * 2.0:
			cleaned.append(r)
	var f := FileAccess.open(LOCAL_ROOMS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(cleaned))


func _clear_local_room_entry() -> void:
	if role != Role.HOST or online_mode:
		return
	var rooms: Array = _read_local_rooms_raw()
	var cleaned: Array = []
	for r in rooms:
		if normalize_code(str(r.get("code", ""))) == room_code:
			continue
		if int(r.get("port", -1)) == game_port:
			continue
		cleaned.append(r)
	var f := FileAccess.open(LOCAL_ROOMS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(cleaned))


func _read_local_rooms_raw() -> Array:
	if not FileAccess.file_exists(LOCAL_ROOMS_PATH):
		return []
	var f := FileAccess.open(LOCAL_ROOMS_PATH, FileAccess.READ)
	if f == null:
		return []
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_ARRAY:
		return []
	return data


func _poll_local_rooms() -> void:
	var rooms := _read_local_rooms_raw()
	var now := Time.get_unix_time_from_system()
	var changed := false
	for r in rooms:
		if typeof(r) != TYPE_DICTIONARY:
			continue
		if now - float(r.get("updated", 0.0)) > ROOM_STALE_SEC:
			continue
		var code := str(r.get("code", ""))
		if code == "":
			code = code_from_port(int(r.get("port", CODE_PORT_BASE)))
		code = normalize_code(code)
		if role == Role.HOST and code == room_code:
			continue
		r["code"] = code
		var ip := str(r.get("ip", "127.0.0.1"))
		var port := int(r.get("port", port_from_code(code)))
		changed = _upsert_room(ip, port, r) or changed
	if changed:
		rooms_updated.emit()
