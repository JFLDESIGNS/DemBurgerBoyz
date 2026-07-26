extends Node
## Fake AI grill pianist — glove hand taps piano strips + HOLD drums.
## Hotkeys while playing a shift: [  p  o  ]

const UiFontsScript := preload("res://scripts/ui_fonts.gd")

const BEAT := 0.30 ## Quarter-note seconds
const HAND_HOVER_Y := 0.11
const HAND_TAP_DIP := 0.055
const HAND_MOVE_LERP := 14.0
const MAX_LEAD := 0.16 ## Fire sound even if hand is still traveling

## C-major strip indices (from screen-left): C3…B4
const C3 := 0
const D3 := 1
const E3 := 2
const F3 := 3
const G3 := 4
const A3 := 5
const B3 := 6
const C4 := 7
const D4 := 8
const E4 := 9
const F4 := 10
const G4 := 11
const A4 := 12
const B4 := 13

var game: Node3D = null
var _playing: bool = false
var _events: Array = [] ## each: {b, n1, n2, d, r}
var _event_i: int = 0
var _t: float = 0.0
var _title: String = ""
var _saved_roll: float = 0.0
var _hand: Sprite3D = null
var _hand_pos: Vector3 = Vector3.ZERO
var _hand_target: Vector3 = Vector3.ZERO
var _tap_dip: float = 0.0
var _pending: Dictionary = {} ## queued hit waiting for hand / timeout
var _title_label: Label = null
var _title_root: Control = null


func setup(host: Node3D) -> void:
	game = host
	_build_hand()
	_build_title_ui()


func is_playing() -> bool:
	return _playing


func try_hotkey(event: InputEventKey) -> bool:
	if game == null or not bool(game.get("playing")):
		return false
	if not event.pressed or event.echo:
		return false
	var code := event.keycode
	if code == KEY_NONE:
		code = event.physical_keycode
	match code:
		KEY_BRACKETLEFT:
			start_song(0)
			return true
		KEY_P:
			start_song(1)
			return true
		KEY_O:
			start_song(2)
			return true
		KEY_BRACKETRIGHT:
			start_song(3)
			return true
	return false


func start_song(idx: int) -> void:
	stop(false)
	var song: Dictionary = _song_catalog(idx)
	_title = str(song.get("title", "Song"))
	_events = song.get("events", []) as Array
	if _events.is_empty():
		return
	_event_i = 0
	_t = 0.0
	_playing = true
	_pending = {}
	_saved_roll = float(game.get("_spatula_user_roll"))
	_show_title(_title)
	var mid := _strip_world(C4)
	_hand_pos = mid + Vector3(0.0, HAND_HOVER_Y, 0.0)
	_hand_target = _hand_pos
	if _hand:
		_hand.visible = true
		_hand.global_position = _hand_pos


func stop(restore_roll: bool = true) -> void:
	_flush_pending()
	_playing = false
	_events.clear()
	_event_i = 0
	_pending = {}
	_hide_title()
	if _hand:
		_hand.visible = false
	if restore_roll and game != null and is_instance_valid(game):
		game.set("_spatula_user_roll", _saved_roll)
		if game.has_method("_refresh_grill_piano_note_labels"):
			game.call("_refresh_grill_piano_note_labels")


func _process(delta: float) -> void:
	if game == null or not is_instance_valid(game):
		return
	if _playing and not bool(game.get("playing")):
		stop(true)
		return
	if _playing:
		_t += delta
		_pump_events()
		_tick_pending(delta)
		if _event_i >= _events.size() and _pending.is_empty():
			## Hold title a beat after the last note.
			var last_b := float((_events[_events.size() - 1] as Dictionary).get("b", 0.0))
			if _t >= last_b * BEAT + 0.85:
				stop(true)
	_tick_hand(delta)


func _pump_events() -> void:
	while _event_i < _events.size():
		var ev: Dictionary = _events[_event_i] as Dictionary
		var when := float(ev.get("b", 0.0)) * BEAT
		if _t + 0.0005 < when:
			break
		## Don't queue over an unfinished hit — wait one frame.
		if not _pending.is_empty():
			break
		_queue_hit(ev)
		_event_i += 1


func _queue_hit(ev: Dictionary) -> void:
	var n1 := int(ev.get("n1", -1))
	var n2 := int(ev.get("n2", -1))
	var drum := int(ev.get("d", -1))
	var roll := float(ev.get("r", 0.0))
	var primary := Vector3.ZERO
	var targets: Array[Vector3] = []
	if n1 >= 0:
		var w1 := _strip_world(n1)
		targets.append(w1)
		primary = w1
	if n2 >= 0 and n2 != n1:
		var w2 := _strip_world(n2)
		targets.append(w2)
		if primary == Vector3.ZERO:
			primary = w2
		else:
			primary = (primary + w2) * 0.5
	if drum >= 0:
		var wd := _drum_world(drum)
		targets.append(wd)
		if primary == Vector3.ZERO:
			primary = wd
	if primary == Vector3.ZERO:
		return
	_set_roll(roll)
	_hand_target = primary + Vector3(0.0, HAND_HOVER_Y, 0.0)
	_pending = {
		"age": 0.0,
		"n1": n1,
		"n2": n2,
		"d": drum,
		"roll": roll,
		"target": primary,
	}


func _tick_pending(delta: float) -> void:
	if _pending.is_empty():
		return
	_pending["age"] = float(_pending["age"]) + delta
	var target: Vector3 = _pending["target"]
	var hover := target + Vector3(0.0, HAND_HOVER_Y, 0.0)
	var near := _hand_pos.distance_to(hover) < 0.06
	if near or float(_pending["age"]) >= MAX_LEAD:
		_fire_pending()


func _fire_pending() -> void:
	if _pending.is_empty():
		return
	var n1 := int(_pending.get("n1", -1))
	var n2 := int(_pending.get("n2", -1))
	var drum := int(_pending.get("d", -1))
	var roll := float(_pending.get("roll", 0.0))
	_set_roll(roll)
	_tap_dip = HAND_TAP_DIP
	if n1 >= 0:
		_tap_world(_strip_world(n1), 1.0)
	if n2 >= 0 and n2 != n1:
		_tap_world(_strip_world(n2), 0.92)
	if drum >= 0:
		_tap_world(_drum_world(drum), 1.05)
	_pending = {}


func _flush_pending() -> void:
	if not _pending.is_empty():
		_fire_pending()


func _tick_hand(delta: float) -> void:
	if _hand == null or not is_instance_valid(_hand):
		return
	if not _hand.visible:
		return
	_hand_pos = _hand_pos.lerp(_hand_target, clampf(delta * HAND_MOVE_LERP, 0.0, 1.0))
	if _tap_dip > 0.0:
		_tap_dip = maxf(0.0, _tap_dip - delta * 0.45)
	var y_off := -_tap_dip
	_hand.global_position = _hand_pos + Vector3(0.0, y_off, 0.0)
	## Slight bob so it reads as a tapping cursor.
	var bob := sin(Time.get_ticks_msec() * 0.012) * 0.004
	_hand.global_position.y += bob


func _set_roll(deg: float) -> void:
	if game == null:
		return
	var snapped := snappedf(deg, 45.0)
	snapped = clampf(snapped, -90.0, 90.0)
	game.set("_spatula_user_roll", snapped)
	if game.has_method("_refresh_grill_piano_note_labels"):
		game.call("_refresh_grill_piano_note_labels")


func _tap_world(world_pos: Vector3, vol: float) -> void:
	if game == null or world_pos == Vector3.ZERO:
		return
	if game.has_method("_grill_song_tap"):
		game.call("_grill_song_tap", world_pos, vol)
	elif game.has_method("_play_grill_tap_at"):
		game.call("_play_grill_tap_at", world_pos, vol)
		if game.has_method("_spawn_spatula_tap_ring"):
			game.call("_spawn_spatula_tap_ring", world_pos)


func _strip_world(from_left: int) -> Vector3:
	if game != null and game.has_method("_grill_song_strip_world"):
		return game.call("_grill_song_strip_world", from_left) as Vector3
	return Vector3.ZERO


func _drum_world(pad: int) -> Vector3:
	if game != null and game.has_method("_grill_song_drum_world"):
		return game.call("_grill_song_drum_world", pad) as Vector3
	return Vector3.ZERO


func _build_hand() -> void:
	if game == null:
		return
	_hand = Sprite3D.new()
	_hand.name = "GrillSongHand"
	var tex: Texture2D = load("res://assets/ui/cursor_glove.png") as Texture2D
	if tex:
		_hand.texture = tex
	_hand.pixel_size = 0.0024
	_hand.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hand.shaded = false
	_hand.double_sided = true
	_hand.transparent = true
	_hand.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	_hand.render_priority = 16
	_hand.visible = false
	_hand.modulate = Color(1.0, 0.95, 0.85, 1.0)
	game.add_child(_hand)


func _build_title_ui() -> void:
	if game == null:
		return
	var layer := CanvasLayer.new()
	layer.name = "GrillSongTitleLayer"
	layer.layer = 72
	game.add_child(layer)
	_title_root = Control.new()
	_title_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_title_root)
	_title_label = Label.new()
	_title_label.name = "GrillSongTitle"
	_title_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.visible = false
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.78, 1.0))
	_title_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))
	_title_label.add_theme_constant_override("outline_size", 10)
	UiFontsScript.apply_label(_title_label, true, 42)
	_title_root.add_child(_title_label)


func _show_title(text: String) -> void:
	if _title_label == null:
		return
	_title_label.text = text
	_title_label.visible = true
	_title_label.modulate.a = 1.0


func _hide_title() -> void:
	if _title_label == null:
		return
	_title_label.visible = false


func _ev(beat: float, n1: int = -1, n2: int = -1, drum: int = -1, roll: float = 0.0) -> Dictionary:
	return {"b": beat, "n1": n1, "n2": n2, "d": drum, "r": roll}


func _song_catalog(idx: int) -> Dictionary:
	match idx:
		0:
			return {"title": "Ode to Joy", "events": _song_ode_to_joy()}
		1:
			return {"title": "Twinkle Twinkle Little Star", "events": _song_twinkle()}
		2:
			return {"title": "Jingle Bells", "events": _song_jingle_bells()}
		_:
			return {"title": "Seven Nation Army", "events": _song_seven_nation()}


func _pack_melody(start_beat: float, notes: Array, step: float = 1.0, with_drums: bool = true) -> Array:
	## notes: each entry is int strip, or [n1,n2] dual, or {"n":..,"n2":..,"d":..,"r":..}
	var out: Array = []
	var b := start_beat
	for item in notes:
		var n1 := -1
		var n2 := -1
		var drum := -1
		var roll := 0.0
		var dur := step
		if item is Dictionary:
			var d: Dictionary = item
			n1 = int(d.get("n", d.get("n1", -1)))
			n2 = int(d.get("n2", -1))
			drum = int(d.get("d", -1))
			roll = float(d.get("r", 0.0))
			dur = float(d.get("dur", step))
		elif item is Array:
			var arr: Array = item
			if arr.size() >= 1:
				n1 = int(arr[0])
			if arr.size() >= 2:
				n2 = int(arr[1])
		else:
			n1 = int(item)
		if with_drums and drum < 0:
			## Kick / rim pads only — keep roll flat so melody stays in C.
			## Hat voices are reserved for explicit song events (auto key/voice switch).
			var bar_pos := int(floor(b)) % 4
			if bar_pos == 0 or bar_pos == 2:
				drum = 2
			elif bar_pos == 1 or bar_pos == 3:
				drum = 4
			roll = 0.0
		out.append(_ev(b, n1, n2, drum, roll))
		b += dur
	return out


func _song_ode_to_joy() -> Array:
	## Beethoven — white-key friendly in C.
	var phrase_a: Array = [
		E4, E4, F4, G4, G4, F4, E4, D4,
		C4, C4, D4, E4, E4, D4, {"n": D4, "dur": 2.0},
	]
	var phrase_b: Array = [
		E4, E4, F4, G4, G4, F4, E4, D4,
		C4, C4, D4, E4, D4, C4, {"n": C4, "dur": 2.0},
	]
	var bridge: Array = [
		D4, D4, E4, C4, D4, [E4, G4], F4, E4,
		D4, D4, E4, C4, D4, [E4, G4], F4, {"n": E4, "dur": 2.0},
	]
	## Mid-song key color: F-key duals for a brighter lift.
	var lift: Array = [
		{"n": E4, "n2": C4, "d": 2, "r": 0.0},
		{"n": F4, "n2": A4, "d": 1, "r": 45.0, "dur": 1.0},
		{"n": G4, "n2": E4, "d": 2, "r": 0.0},
		{"n": G4, "n2": B4, "d": 0, "r": 90.0, "dur": 2.0},
	]
	var out: Array = []
	out.append_array(_pack_melody(0.0, phrase_a))
	out.append_array(_pack_melody(16.0, phrase_b))
	out.append_array(_pack_melody(32.0, bridge))
	out.append_array(_pack_melody(48.0, lift, 1.0, false))
	out.append_array(_pack_melody(54.0, phrase_a))
	out.append_array(_pack_melody(70.0, phrase_b))
	return out


func _song_twinkle() -> Array:
	var line1: Array = [C4, C4, G4, G4, A4, A4, {"n": G4, "dur": 2.0}]
	var line2: Array = [F4, F4, E4, E4, D4, D4, {"n": C4, "dur": 2.0}]
	var line3: Array = [G4, G4, F4, F4, E4, E4, {"n": D4, "dur": 2.0}]
	var line4: Array = [G4, G4, F4, F4, E4, E4, {"n": D4, "dur": 2.0}]
	var finale: Array = [
		C4, C4, G4, G4, A4, A4, {"n": G4, "n2": E4, "dur": 2.0},
		F4, F4, E4, E4, D4, D4, {"n": C4, "n2": E4, "dur": 2.0},
	]
	var out: Array = []
	out.append_array(_pack_melody(0.0, line1))
	out.append_array(_pack_melody(8.0, line2))
	out.append_array(_pack_melody(16.0, line3))
	out.append_array(_pack_melody(24.0, line4))
	out.append_array(_pack_melody(32.0, finale))
	## Open-hat sparkle on the last chord.
	out.append(_ev(48.0, -1, -1, 0, 90.0))
	return out


func _song_jingle_bells() -> Array:
	var a: Array = [
		E4, E4, {"n": E4, "dur": 2.0},
		E4, E4, {"n": E4, "dur": 2.0},
		E4, G4, C4, D4, {"n": E4, "dur": 4.0},
	]
	var b: Array = [
		F4, F4, F4, F4, E4, E4, E4, E4,
		D4, D4, E4, D4, {"n": G4, "dur": 2.0},
	]
	var c: Array = [
		E4, E4, {"n": E4, "dur": 2.0},
		E4, E4, {"n": E4, "dur": 2.0},
		E4, G4, C4, D4, {"n": E4, "dur": 4.0},
	]
	var d: Array = [
		F4, F4, F4, F4, E4, E4, E4, E4,
		G4, G4, F4, D4, {"n": C4, "n2": E4, "dur": 2.0},
	]
	var out: Array = []
	out.append_array(_pack_melody(0.0, a))
	out.append_array(_pack_melody(12.0, b))
	out.append_array(_pack_melody(26.0, c))
	out.append_array(_pack_melody(38.0, d))
	## Drum fill into the final chord.
	out.append(_ev(52.0, -1, -1, 4, 0.0))
	out.append(_ev(52.5, -1, -1, 3, 0.0))
	out.append(_ev(53.0, -1, -1, 2, 45.0))
	out.append(_ev(53.5, -1, -1, 0, 90.0))
	out.append(_ev(54.0, C4, G4, 2, 0.0))
	return out


func _song_seven_nation() -> Array:
	## White Stripes riff approximated on C-major strips (E-centered).
	var riff: Array = [
		{"n": E3, "dur": 1.5},
		{"n": E3, "dur": 0.5},
		{"n": G3, "dur": 1.0},
		{"n": E3, "dur": 1.0},
		{"n": D3, "dur": 1.0},
		{"n": C3, "dur": 2.0},
		{"n": E3, "dur": 2.0}, ## No B2 on the grill — resolve back to E
	]
	var riff_hi: Array = [
		{"n": E4, "dur": 1.5},
		{"n": E4, "dur": 0.5},
		{"n": G4, "dur": 1.0},
		{"n": E4, "dur": 1.0},
		{"n": D4, "dur": 1.0},
		{"n": C4, "dur": 2.0},
		{"n": E4, "dur": 2.0},
	]
	var punch: Array = [
		{"n": E3, "n2": E4, "d": 2, "r": 0.0, "dur": 1.0},
		{"n": G3, "n2": G4, "d": 1, "r": 45.0, "dur": 1.0},
		{"n": E3, "n2": E4, "d": 2, "r": 0.0, "dur": 1.0},
		{"n": D3, "n2": D4, "d": 4, "r": 0.0, "dur": 1.0},
		{"n": C3, "n2": C4, "d": 2, "r": 0.0, "dur": 2.0},
		{"n": E3, "n2": E4, "d": 0, "r": 90.0, "dur": 2.0},
	]
	var out: Array = []
	out.append_array(_pack_melody(0.0, riff, 1.0, true))
	out.append_array(_pack_melody(9.0, riff, 1.0, true))
	out.append_array(_pack_melody(18.0, riff_hi, 1.0, true))
	out.append_array(_pack_melody(27.0, punch, 1.0, false))
	out.append_array(_pack_melody(35.0, riff_hi, 1.0, true))
	out.append(_ev(44.0, -1, -1, 0, 90.0))
	out.append(_ev(44.5, E4, G4, 2, 0.0))
	out.append(_ev(46.0, E3, E4, 2, 0.0))
	return out
