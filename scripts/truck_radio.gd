## Truck AM/FM radio — real live internet stations (Radio Browser / public MP3 streams).
extends Node

signal status_changed(text: String)
signal channel_changed(index: int, channel_name: String)
signal powered_changed(on: bool)

enum Band { FM, AM }

## Curated live MP3 stations (real broadcasts, not canned demo tracks).
const FM_STATIONS: Array[Dictionary] = [
	{"freq": "88.5", "name": "Classic Vinyl", "url": "https://icecast.walmradio.com:8443/classic"},
	{"freq": "92.1", "name": "Smooth Jazz", "url": "http://jking.cdnstream1.com/b22139_128mp3"},
	{"freq": "95.7", "name": "Adroit Jazz", "url": "https://icecast.walmradio.com:8443/jazz"},
	{"freq": "98.3", "name": "Country .977", "url": "http://26343.live.streamtheworld.com/977_COUNTRY_SC"},
	{"freq": "101.3", "name": "Classic FM", "url": "http://ice-the.musicradio.com/ClassicFMMP3"},
	{"freq": "104.9", "name": "WALM Classical", "url": "https://icecast.walmradio.com:8443/walm2"},
	{"freq": "107.1", "name": "1LIVE Rock", "url": "http://wdr-1live-live.icecast.wdr.de/wdr/1live/live/mp3/128/stream.mp3"},
]

const AM_STATIONS: Array[Dictionary] = [
	{"freq": "680", "name": "BBC World", "url": "http://stream.live.vc.bbcmedia.co.uk/bbc_world_service"},
	{"freq": "980", "name": "CNN", "url": "https://tunein.cdnstream1.com/2868_96.mp3"},
	{"freq": "1130", "name": "Deutschlandfunk", "url": "https://st01.sslstream.dlf.de/dlf/01/128/mp3/stream.mp3?aggregator=web"},
	{"freq": "1280", "name": "BBC World Alt", "url": "http://stream.live.vc.bbcmedia.co.uk/bbc_world_service"},
	{"freq": "1510", "name": "CNN News", "url": "https://tunein.cdnstream1.com/2868_96.mp3"},
]

const START_BYTES := 72_000
const MAX_BUFFER := 2_000_000
const REFRESH_EVERY := 2.0
const RECONNECT_AFTER := 12.0

var powered: bool = false
var band: int = Band.FM
## Default: FM 92.1 Smooth Jazz (index in FM_STATIONS).
var channel_index: int = 1
var volume_linear: float = 0.80
## Temporary mute for combat theme — keeps stream alive so resume is instant.
var _combat_silenced: bool = false

var _http := HTTPClient.new()
var _player: AudioStreamPlayer
var _buffer := PackedByteArray()
var _host := ""
var _path := "/"
var _port := 80
var _tls := false
var _body_open := false
var _headers_checked := false
var _refresh_left := 0.0
var _stall_time := 0.0
var _last_buf_size := 0
var _has_playback := false
var _play_started_at_buf := 0
var _status := "Radio off"
var _redirects := 0
var _volume_fade_tween: Tween = null


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	_player.volume_db = _vol_db()
	_player.finished.connect(_on_playback_finished)
	add_child(_player)
	_emit_status("Radio off — live AM/FM")


func channel_count() -> int:
	return _stations().size()


func current_channel() -> Dictionary:
	var list := _stations()
	if list.is_empty():
		return {"freq": "—", "name": "None", "url": ""}
	return list[clampi(channel_index, 0, list.size() - 1)]


func channel_title() -> String:
	var ch := current_channel()
	var unit := "FM" if band == Band.FM else "AM"
	var suffix := " MHz" if band == Band.FM else " kHz"
	return "%s %s%s · %s" % [unit, str(ch.get("freq", "?")), suffix, str(ch.get("name", "?"))]


func short_title() -> String:
	var ch := current_channel()
	var unit := "FM" if band == Band.FM else "AM"
	return "%s %s %s" % [unit, str(ch.get("freq", "?")), str(ch.get("name", "?"))]


func set_powered(on: bool) -> void:
	if powered == on:
		return
	powered = on
	powered_changed.emit(powered)
	if powered:
		_tune_current()
	else:
		_disconnect_stream(true)
		_emit_status("Radio off")


func toggle_power() -> void:
	set_powered(not powered)


func toggle_band() -> void:
	band = Band.AM if band == Band.FM else Band.FM
	## FM boots on Smooth Jazz; AM starts at the first listing.
	channel_index = 1 if band == Band.FM else 0
	if channel_index >= channel_count():
		channel_index = 0
	channel_changed.emit(channel_index, channel_title())
	if powered:
		_tune_current()
	else:
		_emit_status("%s band ready" % ("FM" if band == Band.FM else "AM"))


func next_channel() -> void:
	channel_index = (channel_index + 1) % maxi(1, channel_count())
	channel_changed.emit(channel_index, channel_title())
	if powered:
		_tune_current()
	else:
		_emit_status(short_title())


func prev_channel() -> void:
	channel_index = (channel_index - 1 + channel_count()) % maxi(1, channel_count())
	channel_changed.emit(channel_index, channel_title())
	if powered:
		_tune_current()
	else:
		_emit_status(short_title())


func set_channel(index: int) -> void:
	if index < 0 or index >= channel_count():
		return
	channel_index = index
	channel_changed.emit(channel_index, channel_title())
	if powered:
		_tune_current()


func set_volume_linear(v: float) -> void:
	if _volume_fade_tween != null and is_instance_valid(_volume_fade_tween):
		_volume_fade_tween.kill()
		_volume_fade_tween = null
	volume_linear = clampf(v, 0.0, 1.0)
	if _player and not _combat_silenced:
		_player.volume_db = _vol_db()


func fade_volume_in(duration_sec: float, target_linear: float) -> void:
	## Ramp live stream volume so day start is not a full-blast hit.
	if _volume_fade_tween != null and is_instance_valid(_volume_fade_tween):
		_volume_fade_tween.kill()
		_volume_fade_tween = null
	var target := clampf(target_linear, 0.0, 1.0)
	volume_linear = 0.0
	if _player and not _combat_silenced:
		_player.volume_db = _vol_db()
	if duration_sec <= 0.0:
		set_volume_linear(target)
		return
	var tree := get_tree()
	if tree == null:
		set_volume_linear(target)
		return
	_volume_fade_tween = tree.create_tween()
	_volume_fade_tween.tween_method(_set_fade_volume_linear, 0.0, target, duration_sec)\
		.set_trans(Tween.TRANS_LINEAR)


func _set_fade_volume_linear(v: float) -> void:
	volume_linear = clampf(v, 0.0, 1.0)
	if _player and not _combat_silenced:
		_player.volume_db = _vol_db()


func set_combat_silence(on: bool) -> void:
	## Duck the live stream without powering off — gun/terror theme takes over.
	if _combat_silenced == on:
		return
	_combat_silenced = on
	if _player == null:
		return
	if on:
		_player.volume_db = -80.0
		_emit_status("Radio muted — combat")
	else:
		_player.volume_db = _vol_db()
		if powered:
			_emit_status("♪ LIVE %s" % short_title())
		else:
			_emit_status("Radio off")


func is_combat_silenced() -> bool:
	return _combat_silenced


func _stations() -> Array[Dictionary]:
	return FM_STATIONS if band == Band.FM else AM_STATIONS


## Streams are mastered hot; scale so ~5% VOL is soft background, not ear-level.
const VOL_SCALE := 0.18 ## Louder max stream level

func _vol_db() -> float:
	if _combat_silenced:
		return -80.0
	return linear_to_db(maxf(volume_linear * VOL_SCALE, 0.00005))


func _process(delta: float) -> void:
	if not powered:
		return
	_http.poll()
	_poll_http(delta)
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = REFRESH_EVERY
		if not _has_playback or not _player.playing:
			_try_play_buffer(true)
		elif _buffer.size() > _play_started_at_buf + 140_000:
			_try_play_buffer(false)


func _tune_current() -> void:
	_disconnect_stream(false)
	_redirects = 0
	channel_changed.emit(channel_index, channel_title())
	_emit_status("Tuning live %s..." % short_title())
	var url := str(current_channel().get("url", ""))
	if not _parse_url(url):
		_emit_status("Bad station URL")
		return
	_begin_connect()


func _parse_url(url: String) -> bool:
	var u := url.strip_edges()
	if u.is_empty():
		return false
	_tls = u.begins_with("https://")
	u = u.trim_prefix("https://").trim_prefix("http://")
	var slash := u.find("/")
	var hostport := u if slash < 0 else u.substr(0, slash)
	_path = "/" if slash < 0 else u.substr(slash)
	if hostport.contains(":"):
		var parts := hostport.split(":")
		_host = parts[0]
		_port = int(parts[1])
	else:
		_host = hostport
		_port = 443 if _tls else 80
	return not _host.is_empty()


func _begin_connect() -> void:
	_buffer.clear()
	_body_open = false
	_headers_checked = false
	_has_playback = false
	_play_started_at_buf = 0
	_stall_time = 0.0
	_last_buf_size = 0
	_refresh_left = 0.35
	var err: Error
	if _tls:
		err = _http.connect_to_host(_host, _port, TLSOptions.client())
	else:
		err = _http.connect_to_host(_host, _port)
	if err != OK:
		_emit_status("Connect failed")


func _disconnect_stream(stop_player: bool) -> void:
	_http.close()
	_body_open = false
	_headers_checked = false
	_buffer.clear()
	_has_playback = false
	_play_started_at_buf = 0
	if stop_player and _player:
		_player.stop()
		_player.stream = null


func _poll_http(delta: float) -> void:
	var st := _http.get_status()
	match st:
		HTTPClient.STATUS_DISCONNECTED:
			_stall_time += delta
			if _stall_time > 2.5:
				_stall_time = 0.0
				_emit_status("Reconnecting...")
				_begin_connect()
		HTTPClient.STATUS_CONNECTED:
			if not _body_open:
				var headers := PackedStringArray([
					"User-Agent: FoodTruckFlip/1.0 (AM-FM Radio)",
					"Accept: */*",
					"Icy-MetaData: 0",
					"Connection: keep-alive",
				])
				var err := _http.request(HTTPClient.METHOD_GET, _path, headers)
				if err != OK:
					_emit_status("Request failed")
				else:
					_body_open = true
		HTTPClient.STATUS_BODY:
			if not _headers_checked:
				_headers_checked = true
				if _handle_redirect():
					return
			_read_chunks()
			_check_stall(delta)
		HTTPClient.STATUS_CONNECTION_ERROR, HTTPClient.STATUS_TLS_HANDSHAKE_ERROR, HTTPClient.STATUS_CANT_CONNECT, HTTPClient.STATUS_CANT_RESOLVE:
			_stall_time += delta
			if _stall_time > 2.0:
				_stall_time = 0.0
				_emit_status("Signal lost — retrying")
				_begin_connect()
		_:
			pass


func _handle_redirect() -> bool:
	if not _http.has_response():
		return false
	var code := _http.get_response_code()
	if code != 301 and code != 302 and code != 307 and code != 308:
		return false
	if _redirects >= 4:
		_emit_status("Too many redirects")
		return false
	var hdrs := _http.get_response_headers_as_dictionary()
	var loc := str(hdrs.get("Location", hdrs.get("location", "")))
	if loc.is_empty():
		return false
	_redirects += 1
	_http.close()
	_body_open = false
	_headers_checked = false
	if loc.begins_with("/"):
		_path = loc
	elif not _parse_url(loc):
		return false
	_emit_status("Following station...")
	_begin_connect()
	return true


func _read_chunks() -> void:
	while _http.get_status() == HTTPClient.STATUS_BODY:
		var chunk: PackedByteArray = _http.read_response_body_chunk()
		if chunk.is_empty():
			break
		_buffer.append_array(chunk)
		_stall_time = 0.0
	if _buffer.size() > MAX_BUFFER:
		_buffer = _buffer.slice(_buffer.size() - int(MAX_BUFFER * 0.7))
		_has_playback = false
		_play_started_at_buf = 0


func _check_stall(delta: float) -> void:
	if _buffer.size() == _last_buf_size:
		_stall_time += delta
		if _stall_time >= RECONNECT_AFTER:
			_stall_time = 0.0
			_emit_status("Buffer stalled — retuning")
			_tune_current()
	else:
		_last_buf_size = _buffer.size()
		_stall_time = 0.0


func _on_playback_finished() -> void:
	if not powered:
		return
	_has_playback = false
	_try_play_buffer(true)


func _find_mp3_sync(data: PackedByteArray) -> int:
	var n := mini(data.size() - 1, 96_000)
	for i in n:
		if data[i] == 0xFF and (data[i + 1] & 0xE0) == 0xE0:
			return i
	return 0


func _try_play_buffer(force_restart: bool) -> void:
	if _buffer.size() < START_BYTES:
		if powered:
			_emit_status("Buffering live %s… %dk" % [
				str(current_channel().get("name", "?")),
				int(_buffer.size() / 1024.0),
			])
		return
	var sync := _find_mp3_sync(_buffer)
	var payload := _buffer.slice(sync) if sync > 0 else _buffer
	var stream: AudioStreamMP3 = AudioStreamMP3.load_from_buffer(payload)
	if stream == null:
		stream = AudioStreamMP3.new()
		stream.data = payload
	if stream == null:
		_emit_status("Can't decode live audio")
		return
	var length := stream.get_length()
	var resume := 0.0
	if not force_restart and _has_playback and _player.playing and length > 0.25:
		resume = minf(_player.get_playback_position(), maxf(0.0, length - 0.45))
	elif length > 0.3:
		resume = minf(0.1, length * 0.02)
	_player.stream = stream
	_player.volume_db = _vol_db()
	if length <= 0.05:
		_player.play()
	else:
		_player.play(resume)
	_has_playback = true
	_play_started_at_buf = _buffer.size()
	_emit_status("♪ LIVE %s" % short_title())


func _emit_status(text: String) -> void:
	if _status == text:
		return
	_status = text
	status_changed.emit(_status)
