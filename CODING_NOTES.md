# Coding notes

## Open / Closed window sign textures

- Files: `IMAGES/WEAREOPEN.png`, `IMAGES/WEARECLOSED.png` (alpha cuts already in the PNGs).
- Status: QuadMesh hang-sign faces (`_build_open_closed_sign` in `scripts/game.gd`), same seat as the old text sign `(-1.08, 1.78, 1.14)`.
- Load via `FileAccess.get_file_as_bytes` + `Image.load_png_from_buffer` — never `Image.load(res://)` (broken in exports).
- Keep PNGs listed in `export_presets.cfg` `include_filter` so they ship inside the PCK (do not rely on `.import` / `.ctex`).


## Spatula piano flourish (REMOVED from live code — restore from here)

Status: disabled 2026-07-25. Live game keeps normal scrape bed/tings + LMB piano taps only.

### game.gd — state
```gdscript
var _spatula_piano_slide_last_strip: int = -1 ## Cook-zone glissando strip tracker
var _spatula_piano_gliss_armed: bool = false ## True after first clean-steel slide this hold
```

### game.gd — helpers (call from `_update_spatula_grill_scrape` each hold frame)
```gdscript
func _grill_piano_world_at_strip(from_left: int, tip_z: float) -> Vector3:
	## Center of a cook piano strip (screen-left = low notes = high world X).
	var b := _grill_cook_x_bounds()
	var i := clampi(from_left, 0, GRILL_PIANO_SECTIONS - 1)
	var sec := (GRILL_PIANO_SECTIONS - 1) - i
	var u := (float(sec) + 0.5) / float(GRILL_PIANO_SECTIONS)
	return Vector3(lerpf(b.x, b.y, u), GRILL_SURFACE_Y, tip_z)


func _grill_piano_strip_f_from_left(world_pos: Vector3) -> float:
	## Fractional strip index (0…13) — used so flourish pitch glides between notes.
	var b := _grill_cook_x_bounds()
	var span := maxf(0.001, b.y - b.x)
	var u := (world_pos.x - b.x) / span
	## +X = screen-left / low notes, so invert like the integer strip helper.
	return clampf((float(GRILL_PIANO_SECTIONS) - 1.0) - u * float(GRILL_PIANO_SECTIONS), 0.0, float(GRILL_PIANO_SECTIONS - 1))


func _grill_piano_sounding_at_f(from_left_f: float) -> float:
	## Heard pitch between neighboring C-major strips (for continuous gliss).
	var f := clampf(from_left_f, 0.0, float(GRILL_PIANO_SECTIONS - 1))
	var i0 := int(floor(f))
	var i1 := mini(i0 + 1, GRILL_PIANO_SECTIONS - 1)
	var t := f - float(i0)
	return lerpf(
		float(_grill_piano_sounding_at_index(i0)),
		float(_grill_piano_sounding_at_index(i1)),
		t
	)


func _stop_spatula_piano_gliss() -> void:
	_spatula_piano_gliss_armed = false
	if game_audio != null and game_audio.has_method("set_spatula_gliss"):
		game_audio.set_spatula_gliss(false)


func _update_spatula_piano_slide(tip_pos: Vector3, scraping_debris: bool = false, moved: float = 0.0) -> void:
	## Hold + slide across cook strips → tinggrill pitch-glide (½ tap vol).
	## Actively scraping debris: no flourish — keep original scrape tings / bed.
	if tip_pos == Vector3.ZERO:
		_spatula_piano_slide_last_strip = -1
		_stop_spatula_piano_gliss()
		if game_audio != null and game_audio.has_method("set_scrape_tings_muted"):
			game_audio.set_scrape_tings_muted(false)
		return
	var zone := _grill_zone_at(tip_pos)
	var on_cook := not zone.is_empty() and str(zone.get("id", "")) != "hold"
	if not on_cook:
		_spatula_piano_slide_last_strip = -1
		_stop_spatula_piano_gliss()
		if game_audio != null and game_audio.has_method("set_scrape_tings_muted"):
			game_audio.set_scrape_tings_muted(false)
		return
	if scraping_debris:
		_spatula_piano_slide_last_strip = _grill_piano_strip_index_from_left(tip_pos)
		_stop_spatula_piano_gliss()
		if game_audio != null and game_audio.has_method("set_scrape_tings_muted"):
			game_audio.set_scrape_tings_muted(false)
		return
	if game_audio != null and game_audio.has_method("set_scrape_tings_muted"):
		game_audio.set_scrape_tings_muted(true)
	var cur_f := _grill_piano_strip_f_from_left(tip_pos)
	var cur_i := clampi(int(floor(cur_f + 0.0001)), 0, GRILL_PIANO_SECTIONS - 1)
	if _spatula_piano_slide_last_strip < 0:
		_spatula_piano_slide_last_strip = cur_i
		return
	if cur_i != _spatula_piano_slide_last_strip:
		var step := 1 if cur_i > _spatula_piano_slide_last_strip else -1
		var i := _spatula_piano_slide_last_strip + step
		while true:
			_flash_grill_tap_pad(_grill_piano_world_at_strip(i, tip_pos.z))
			if i == cur_i:
				break
			i += step
		_spatula_piano_slide_last_strip = cur_i
		_spatula_piano_gliss_armed = true
	var moving := moved >= SPATULA_SCRAPE_MIN_MOVE * 0.35
	if moving:
		_spatula_piano_gliss_armed = true
	var midi_f := _grill_piano_sounding_at_f(cur_f) + float(GRILL_PIANO_SAMPLE_COMP) \
		+ float(_spatula_roll_midi_offset())
	var tap_vol := 0.92 if absf(_spatula_user_roll) < 22.5 else 1.68
	var slide_vol := tap_vol * 0.5
	if game_audio != null and game_audio.has_method("set_spatula_gliss"):
		game_audio.set_spatula_gliss(_spatula_piano_gliss_armed, midi_f, slide_vol)
```

### game.gd — wire into scrape (inside `_update_spatula_grill_scrape`)
```gdscript
## After computing scraping_debris / moved:
_update_spatula_piano_slide(tip_pos, scraping_debris, moved)
## On scrape stop:
_stop_spatula_piano_gliss()
```

### game_audio.gd — tinggrill pitch-glide gliss (last working non-theremin version)
```gdscript
## Flourish gliss — same tinggrill sample, pitch-bent + soft overlaps (not a synth).
var _gliss_players: Array[AudioStreamPlayer] = []
var _gliss_player_i: int = 0
const GLISS_POOL := 4
var _gliss_on: bool = false
var _gliss_midi: float = 72.0 ## request MIDI (includes tinggrill sample comp)
var _gliss_midi_smooth: float = 72.0
var _gliss_vol: float = 0.0
var _gliss_vol_target: float = 0.0
var _gliss_retrigger: float = 0.0
const GLISS_RETRIGGER := 0.05
var _scrape_tings_muted: bool = false ## mute random scrape tings during clean-steel gliss

## In _ready():
for i in GLISS_POOL:
	var gp := AudioStreamPlayer.new()
	gp.name = "SpatulaGliss_%d" % i
	gp.bus = "Master"
	gp.volume_db = -80.0
	add_child(gp)
	_gliss_players.append(gp)

## In _process():
_tick_spatula_gliss(delta)

func set_scrape_tings_muted(muted: bool) -> void:
	_scrape_tings_muted = muted

## In _tick_scrape_tings: early-out if _scrape_tings_muted

func set_spatula_gliss(active: bool, midi: float = 72.0, volume_scale: float = 0.5) -> void:
	## Flourish uses tinggrill itself — pitch glides; soft overlaps keep it connected.
	if active:
		var was := _gliss_on
		_gliss_on = true
		_gliss_midi = clampf(midi, 48.0, 96.0)
		_gliss_vol_target = clampf(volume_scale, 0.0, 1.5)
		if not was:
			_gliss_midi_smooth = _gliss_midi
			_gliss_retrigger = 0.0
			_fire_gliss_ting(true)
	else:
		_gliss_on = false
		_gliss_vol_target = 0.0


func _tinggrill_stream() -> AudioStream:
	if not _cache.has("tinggrill"):
		var loaded: AudioStream = _load_tinggrill_stream()
		if loaded == null:
			loaded = _make_spatula_ting_note(72)
		_cache["tinggrill"] = loaded
	return _cache["tinggrill"]


func _gliss_ting_gain(midi: float, volume_scale: float) -> float:
	var semis := clampf(midi - 72.0, -24.0, 16.0)
	var away := absf(semis)
	var pitch_boost := 1.0 + away * (0.14 if semis < 0.0 else 0.05)
	if away > 0.001:
		pitch_boost *= 1.2
	return 1.75 * pitch_boost * maxf(0.0, volume_scale) * 0.62


func _fire_gliss_ting(soft_attack: bool = false) -> void:
	if _gliss_players.is_empty():
		return
	var p: AudioStreamPlayer = _gliss_players[_gliss_player_i]
	_gliss_player_i = (_gliss_player_i + 1) % _gliss_players.size()
	p.stream = _tinggrill_stream()
	var semis := clampf(_gliss_midi_smooth - 72.0, -24.0, 16.0)
	p.pitch_scale = pow(2.0, semis / 12.0)
	var gain := _gliss_ting_gain(_gliss_midi_smooth, maxf(_gliss_vol, _gliss_vol_target))
	p.volume_db = linear_to_db(clampf(gain * (0.7 if soft_attack else 0.85), 0.05, 2.4))
	p.play(0.012)


func _tick_spatula_gliss(delta: float) -> void:
	var fade_up := _gliss_vol_target > _gliss_vol
	_gliss_vol = move_toward(_gliss_vol, _gliss_vol_target, delta * (12.0 if fade_up else 6.0))
	var follow := 1.0 - exp(-delta * 22.0)
	_gliss_midi_smooth = lerpf(_gliss_midi_smooth, _gliss_midi, follow)
	var semis := clampf(_gliss_midi_smooth - 72.0, -24.0, 16.0)
	var pitch := pow(2.0, semis / 12.0)
	var gain := _gliss_ting_gain(_gliss_midi_smooth, _gliss_vol)
	var vol_db := linear_to_db(clampf(gain * 0.85, 0.05, 2.4)) if _gliss_vol > 0.01 else -80.0
	for p in _gliss_players:
		if p == null or not is_instance_valid(p) or not p.playing:
			continue
		p.pitch_scale = pitch
		p.volume_db = vol_db
	if _gliss_on and _gliss_vol > 0.01:
		_gliss_retrigger = maxf(0.0, _gliss_retrigger - delta)
		if _gliss_retrigger <= 0.0:
			_fire_gliss_ting(false)
			_gliss_retrigger = GLISS_RETRIGGER + randf_range(-0.008, 0.012)
	elif _gliss_vol <= 0.01 and not _gliss_on:
		for p2 in _gliss_players:
			if p2 != null and is_instance_valid(p2) and p2.playing:
				p2.stop()
				p2.volume_db = -80.0
```

Notes:
- Do NOT restore the additive AudioStreamGenerator "theremin" version — user rejected it.
- Piano strip layout (14× C major) and LMB tap tings stay live; only hold-slide flourish was removed.
