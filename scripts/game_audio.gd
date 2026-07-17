## Kitchen SFX: soothing ingredient tones, grill sizzle, UI clicks, flip/ding/cha-ching.
extends Node

const MIX_RATE := 22050
const SFX_POOL := 14

## Soft ascending kitchen scale — cheese is the floor, top bun the ceiling.
## Order matches the ingredient strip (hotkeys 1→9).
const INGREDIENT_MIDI := {
	"cheese": 60, ## C4 — lowest
	"tomato": 62, ## D4
	"lettuce": 64, ## E4
	"onion": 65, ## F4
	"pickle": 67, ## G4
	"bacon": 69, ## A4
	"ketchup": 71, ## B4
	"mustard": 72, ## C5
	"bun_top": 74, ## D5 — highest
	"patty": 57, ## A3 (grill scoop — under the topping scale)
	"bun_bottom": 55, ## G3 (auto under patty — not on the strip)
}

var _players: Array[AudioStreamPlayer] = []
var _player_i: int = 0
var _cache: Dictionary = {} ## key -> AudioStreamWAV
var _sizzle_player: AudioStreamPlayer
var _sizzle_gen: AudioStreamGenerator
var _sizzle_on: bool = false
var _sizzle_intensity: float = 0.5
var _hiss_player: AudioStreamPlayer
var _hiss_gen: AudioStreamGenerator
var _hiss_on: bool = false
var _hiss_lp := 0.0
var _hiss_hp := 0.0
## Extinguisher spray — continuous powder/static hiss while RMB held.
var _spray_player: AudioStreamPlayer
var _spray_gen: AudioStreamGenerator
var _spray_on: bool = false
var _spray_lp := 0.0
var _spray_bp := 0.0
var _spray_tick := 0.0
var _spray_flutter := 1.0
## Seasoning shaker — rhythmic rattle while shaking over patties.
var _shake_player: AudioStreamPlayer
var _shake_gen: AudioStreamGenerator
var _shake_on: bool = false
var _shake_lp := 0.0
var _shake_phase := 0.0
var _shake_tick := 0.0
## Live fry filters / pop state (never loops).
var _sz_mid := 0.0
var _sz_mid2 := 0.0
var _sz_high := 0.0
var _sz_high2 := 0.0
var _sz_pop_env := 0.0
var _sz_pop_bright := 0.0
var _sz_pop_tick := 0.0
var _sz_hiss_mod := 1.0
var _sz_next_pop_in := 0.0
var _sz_sample_i := 0
## Soft scrape bed while sliding a patty — fades out when you stop.
var _slide_player: AudioStreamPlayer
var _slide_gain: float = 0.0
var _slide_target: float = 0.0
## Hot oil on a lit grill — loud fry burst, then a soft 2s die-out.
var _hot_oil_full_left: float = 0.0
var _hot_oil_fade_left: float = 0.0
const HOT_OIL_FADE_SEC := 2.0
var _hot_oil_pop_cd: float = 0.0
var _hot_oil_was_active: bool = false


func _ready() -> void:
	add_to_group("game_audio")
	for i in SFX_POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	## Live procedural sizzle — no looping WAV (avoids ocean-loop feel).
	_sizzle_gen = AudioStreamGenerator.new()
	_sizzle_gen.mix_rate = MIX_RATE
	_sizzle_gen.buffer_length = 0.12
	_sizzle_player = AudioStreamPlayer.new()
	_sizzle_player.bus = "Master"
	_sizzle_player.stream = _sizzle_gen
	_sizzle_player.volume_db = -80.0
	add_child(_sizzle_player)
	_sz_next_pop_in = 0.04 + randf() * 0.12
	## Quieter idle burner hiss — obvious ON without matching cooking volume.
	_hiss_gen = AudioStreamGenerator.new()
	_hiss_gen.mix_rate = MIX_RATE
	_hiss_gen.buffer_length = 0.12
	_hiss_player = AudioStreamPlayer.new()
	_hiss_player.bus = "Master"
	_hiss_player.stream = _hiss_gen
	_hiss_player.volume_db = -80.0
	add_child(_hiss_player)
	## Live extinguisher spray static (powder / CO2 rush).
	_spray_gen = AudioStreamGenerator.new()
	_spray_gen.mix_rate = MIX_RATE
	_spray_gen.buffer_length = 0.12
	_spray_player = AudioStreamPlayer.new()
	_spray_player.bus = "Master"
	_spray_player.stream = _spray_gen
	_spray_player.volume_db = -80.0
	add_child(_spray_player)
	## Live shaker rattle while seasoning patties.
	_shake_gen = AudioStreamGenerator.new()
	_shake_gen.mix_rate = MIX_RATE
	_shake_gen.buffer_length = 0.12
	_shake_player = AudioStreamPlayer.new()
	_shake_player.bus = "Master"
	_shake_player.stream = _shake_gen
	_shake_player.volume_db = -80.0
	add_child(_shake_player)
	## Looping soft metal scrape for patty slides.
	_slide_player = AudioStreamPlayer.new()
	_slide_player.bus = "Master"
	_slide_player.stream = _make_slide_scrape()
	_slide_player.volume_db = -80.0
	add_child(_slide_player)
	set_process(true)


func _process(delta: float) -> void:
	## Fade crackle bed toward target (up when sliding, down when stopped).
	var fade_spd := 7.0 if _slide_target > _slide_gain else 3.2
	_slide_gain = move_toward(_slide_gain, _slide_target, delta * fade_spd)
	if _slide_player:
		if _slide_gain > 0.01:
			_slide_player.volume_db = linear_to_db(clampf(_slide_gain * 0.38, 0.02, 1.0))
			_slide_player.pitch_scale = 1.15 + _slide_gain * 0.2
			if not _slide_player.playing:
				_slide_player.play()
		elif _slide_player.playing:
			_slide_player.stop()
			_slide_player.volume_db = -80.0
			_slide_player.pitch_scale = 1.0
	## Hot oil on lit steel — loud fry for the full window, then a 2s die-out.
	var oil_active := _hot_oil_full_left > 0.0 or _hot_oil_fade_left > 0.0
	var oil_fade_t := 1.0 ## 1 = full blast, 0 = silent
	if _hot_oil_full_left > 0.0:
		_hot_oil_full_left = maxf(0.0, _hot_oil_full_left - delta)
		_hot_oil_was_active = true
		_sizzle_on = true
		oil_fade_t = 1.0
		if _hot_oil_full_left <= 0.0:
			_hot_oil_fade_left = HOT_OIL_FADE_SEC
		if _sizzle_player != null:
			_sizzle_player.volume_db = -3.5
			if not _sizzle_player.playing:
				_sizzle_player.play()
		_hot_oil_pop_cd -= delta
		if _hot_oil_pop_cd <= 0.0:
			play_grease_pop(true)
			if randf() < 0.55:
				play_grease_pop(true)
			_hot_oil_pop_cd = 0.028 + randf() * 0.045
	elif _hot_oil_fade_left > 0.0:
		_hot_oil_fade_left = maxf(0.0, _hot_oil_fade_left - delta)
		_hot_oil_was_active = true
		_sizzle_on = true
		oil_fade_t = clampf(_hot_oil_fade_left / HOT_OIL_FADE_SEC, 0.0, 1.0)
		if _sizzle_player != null:
			## Soft linear die-out over the fade window.
			_sizzle_player.volume_db = lerpf(-42.0, -6.0, oil_fade_t)
			if not _sizzle_player.playing:
				_sizzle_player.play()
		_hot_oil_pop_cd -= delta
		if _hot_oil_pop_cd <= 0.0 and oil_fade_t > 0.08:
			if randf() < oil_fade_t:
				play_grease_pop(true)
			_hot_oil_pop_cd = lerpf(0.14, 0.04, oil_fade_t) + randf() * 0.05
	elif _hot_oil_was_active:
		_hot_oil_was_active = false
		if _sizzle_on and _sizzle_player != null:
			_sizzle_player.volume_db = lerpf(-18.0, -12.0, clampf(_sizzle_intensity, 0.0, 1.0))
	if _sizzle_on and _sizzle_player != null and _sizzle_player.playing:
		var playback := _sizzle_player.get_stream_playback() as AudioStreamGeneratorPlayback
		if playback != null:
			var t := clampf(_sizzle_intensity, 0.0, 1.0)
			var oil_mul := 1.0
			if oil_active:
				oil_mul = lerpf(1.0, 2.4, oil_fade_t)
				t = maxf(t, oil_fade_t)
			## Quieter static bed (50%); crackles stay full strength.
			var bed_gain := lerpf(0.06, 0.1, t) * oil_mul
			var pop_chance_boost := lerpf(1.0, 1.6, t) * lerpf(1.0, 3.2, oil_fade_t if oil_active else 0.0)
			while playback.get_frames_available() > 0:
				var sample := _next_sizzle_sample(bed_gain, pop_chance_boost)
				if oil_active:
					sample = clampf(sample * lerpf(1.0, 1.55, oil_fade_t), -1.0, 1.0)
				playback.push_frame(Vector2(sample, sample))
	if _hiss_on and _hiss_player != null and _hiss_player.playing:
		var hp := _hiss_player.get_stream_playback() as AudioStreamGeneratorPlayback
		if hp != null:
			while hp.get_frames_available() > 0:
				var hs := _next_burner_hiss_sample()
				hp.push_frame(Vector2(hs, hs))
	if _spray_on and _spray_player != null and _spray_player.playing:
		var sp := _spray_player.get_stream_playback() as AudioStreamGeneratorPlayback
		if sp != null:
			while sp.get_frames_available() > 0:
				var ss := _next_ext_spray_sample()
				sp.push_frame(Vector2(ss, ss))
	if _shake_on and _shake_player != null and _shake_player.playing:
		var shp := _shake_player.get_stream_playback() as AudioStreamGeneratorPlayback
		if shp != null:
			while shp.get_frames_available() > 0:
				var shs := _next_shaker_rattle_sample()
				shp.push_frame(Vector2(shs, shs))


func set_sizzle_active(active: bool, intensity: float = 0.5) -> void:
	if _sizzle_player == null:
		return
	_sizzle_intensity = clampf(intensity, 0.0, 1.0)
	if _hot_oil_full_left > 0.0 or _hot_oil_fade_left > 0.0:
		active = true
		_sizzle_intensity = maxf(_sizzle_intensity, 0.95)
	if active:
		_sizzle_on = true
		if _hot_oil_full_left <= 0.0 and _hot_oil_fade_left <= 0.0:
			_sizzle_player.volume_db = lerpf(-18.0, -12.0, _sizzle_intensity)
		if not _sizzle_player.playing:
			_sizzle_player.play()
	else:
		_sizzle_on = false
		if _sizzle_player.playing:
			_sizzle_player.stop()


func is_hot_oil_bursting() -> bool:
	return _hot_oil_full_left > 0.0 or _hot_oil_fade_left > 0.0


func trigger_hot_oil(duration: float = 3.0) -> void:
	## Oil hits a hot grill — loud fry for `duration`, then a 2s soft die-out.
	var starting := _hot_oil_full_left <= 0.05 and _hot_oil_fade_left <= 0.05
	_hot_oil_full_left = maxf(_hot_oil_full_left, duration)
	_hot_oil_fade_left = 0.0 ## re-hit cancels an in-progress fade
	_sizzle_on = true
	_sizzle_intensity = maxf(_sizzle_intensity, 0.95)
	if _sizzle_player != null:
		_sizzle_player.volume_db = -3.5
		if not _sizzle_player.playing:
			_sizzle_player.play()
	## Kill idle hiss under the burst so the fry reads clearly.
	if _hiss_on and _hiss_player != null and _hiss_player.playing:
		_hiss_on = false
		_hiss_player.stop()
	if starting:
		play_hot_oil_hit()
		_hot_oil_pop_cd = 0.0
		## Immediate pop cluster on contact.
		for _i in 4:
			play_grease_pop(true)


func play_hot_oil_hit() -> void:
	## One loud splash/hiss when oil first kisses hot steel.
	_play_cached("hot_oil_hit", _make_hot_oil_hit, 0.0, 1.2)


func set_burner_hiss(active: bool) -> void:
	## Hot empty flat-top — soft continuous hiss, quieter than cooking sizzle.
	if _hiss_player == null:
		return
	if active:
		_hiss_on = true
		# Boost idle hiss so "burner on" reads immediately even before patties heat up.
		_hiss_player.volume_db = -30.0
		if not _hiss_player.playing:
			_hiss_player.play()
	else:
		_hiss_on = false
		if _hiss_player.playing:
			_hiss_player.stop()


func set_ext_spray(active: bool) -> void:
	## Continuous powder-can static while the extinguisher nozzle is open.
	if _spray_player == null:
		return
	if active:
		_spray_on = true
		_spray_player.volume_db = -9.5
		if not _spray_player.playing:
			_spray_player.play()
	else:
		_spray_on = false
		if _spray_player.playing:
			_spray_player.stop()
		_spray_player.volume_db = -80.0


func set_shaker_rattle(active: bool) -> void:
	## Plastic shaker rattle + salt sprinkle while held over a patty.
	if _shake_player == null:
		return
	if active:
		_shake_on = true
		_shake_player.volume_db = -27.0
		if not _shake_player.playing:
			_shake_player.play()
	else:
		_shake_on = false
		if _shake_player.playing:
			_shake_player.stop()
		_shake_player.volume_db = -80.0


func _next_shaker_rattle_sample() -> float:
	## ~4–6 Hz shake bursts with granular sprinkle noise.
	_shake_tick += 1.0 / float(MIX_RATE)
	var shake_hz := 5.2 + sin(_shake_tick * 2.1) * 0.9
	_shake_phase += shake_hz / float(MIX_RATE)
	var pulse := maxf(0.0, sin(_shake_phase * TAU))
	pulse = pow(pulse, 0.45)
	var white := randf() * 2.0 - 1.0
	_shake_lp = _shake_lp * 0.72 + white * 0.28
	var grain := (white - _shake_lp) * 0.35 + _shake_lp * 0.08
	var tap := 0.0
	if pulse > 0.9 and randf() < 0.025:
		tap = (randf() * 2.0 - 1.0) * 0.12
	return clampf((grain * 0.22 + tap) * pulse, -1.0, 1.0)


func _next_ext_spray_sample() -> float:
	## Harsh mid/high static — pressurized powder blast, not a soft gas hiss.
	var white := randf() * 2.0 - 1.0
	_spray_lp = _spray_lp * 0.78 + white * 0.22
	var hp := white - _spray_lp
	_spray_bp = _spray_bp * 0.55 + hp * 0.45
	_spray_tick += 1.0 / float(MIX_RATE)
	if _spray_tick > 0.03 + randf() * 0.05:
		_spray_tick = 0.0
		_spray_flutter = 0.82 + randf() * 0.45
	_spray_flutter = lerpf(_spray_flutter, 1.0, 0.004)
	var rush := _spray_bp * 0.55 + hp * 0.35 + _spray_lp * 0.08
	## Occasional spit crackles in the stream.
	if randf() < 0.004:
		rush += (randf() * 2.0 - 1.0) * 0.55
	return clampf(rush * 0.42 * _spray_flutter, -1.0, 1.0)


func _next_burner_hiss_sample() -> float:
	## Soft high-band gas/metal hiss — quiet idle bed only.
	var white := randf() * 2.0 - 1.0
	_hiss_lp = _hiss_lp * 0.82 + white * 0.18
	_hiss_hp = white - _hiss_lp
	# Extra gain for a more obvious idle static cue.
	return clampf((_hiss_hp * 0.07 + _hiss_lp * 0.015) * 1.35, -1.0, 1.0)


func _next_sizzle_sample(bed_gain: float, pop_boost: float) -> float:
	## Mid/high fry only — almost no bass so it doesn't read as ocean waves.
	var white := randf() * 2.0 - 1.0
	_sz_mid = _sz_mid * 0.72 + white * 0.28
	_sz_mid2 = _sz_mid2 * 0.48 + _sz_mid * 0.52
	_sz_high = _sz_high * 0.28 + white * 0.72
	_sz_high2 = _sz_high2 * 0.15 + _sz_high * 0.85
	## Gentle random hiss swell (not a slow sine loop).
	if randf() < 0.002:
		_sz_hiss_mod = 0.75 + randf() * 0.55
	_sz_hiss_mod = lerpf(_sz_hiss_mod, 1.0, 0.0015)
	var bed := (_sz_mid2 * 0.55 + _sz_high2 * 0.7) * bed_gain * _sz_hiss_mod
	## Schedule irregular grease pops (never a fixed rhythm).
	_sz_next_pop_in -= 1.0 / float(MIX_RATE)
	if _sz_pop_env < 0.015 and _sz_next_pop_in <= 0.0:
		## Clusters: sometimes a single pop, sometimes 2–3 close together.
		_sz_pop_env = 0.7 + randf() * 1.1
		_sz_pop_bright = 0.75 + randf() * 1.0
		_sz_pop_tick = 1800.0 + randf() * 2800.0
		if randf() < 0.35 * pop_boost:
			_sz_next_pop_in = 0.012 + randf() * 0.04 ## follow-up pop
		else:
			_sz_next_pop_in = (0.05 + randf() * 0.22) / pop_boost
	_sz_pop_env *= 0.82
	var pop := 0.0
	if _sz_pop_env > 0.01:
		var crackle := (randf() * 2.0 - 1.0) * (0.55 + absf(_sz_high2) * 0.8)
		pop = crackle * _sz_pop_env * _sz_pop_bright * 0.42
		if _sz_pop_env > 0.65:
			var phase := float(_sz_sample_i) * _sz_pop_tick * TAU / float(MIX_RATE)
			pop += sin(phase) * _sz_pop_env * 0.18
	_sz_sample_i += 1
	return clampf(bed + pop, -1.0, 1.0)


func play_ingredient(id: String) -> void:
	var midi: int = int(INGREDIENT_MIDI.get(id, 60))
	## Soft quiet tap — stays under sizzle / radio / grade stingers.
	_play_cached("ing_%d" % midi, func(): return _make_soft_note(midi, 0.32), 0.0, 0.12)


func play_scale_jingle() -> void:
	## Quick rising arpeggio + sparkle when every strip note has been hit.
	_play_cached("scale_jingle", _make_scale_jingle, 0.0, 0.32)


func play_click() -> void:
	_play_cached("ui_click", _make_click, 1.0, 0.85)


func play_stove_light() -> void:
	## Gas-stove ignite when the burner comes on.
	if not _cache.has("stove_light"):
		var stream: AudioStream = null
		if ResourceLoader.exists("res://sounds/stovelight.ogg"):
			stream = load("res://sounds/stovelight.ogg") as AudioStream
		if stream == null:
			return
		_cache["stove_light"] = stream
	var p: AudioStreamPlayer = _players[_player_i]
	_player_i = (_player_i + 1) % _players.size()
	p.stream = _cache["stove_light"]
	p.pitch_scale = 1.0
	p.volume_db = linear_to_db(0.475)
	p.play()


func play_flip() -> void:
	_play_cached("flip", _make_flip, 0.0, 0.28)


func play_ready() -> void:
	## Soft “ding” when flip/scoop is ready.
	_play_cached("ready", _make_ready_ding, 0.0, 0.25)


func play_scoop() -> void:
	_play_cached("scoop", _make_scoop, 0.0, 0.9)


func play_chaching() -> void:
	## Soft service bell fallback.
	play_order_up()


func play_order_up() -> void:
	## Classic kitchen “order up!” — bright double service-bell ding.
	_play_cached("order_up_bell", _make_serve_bell, 0.0, 0.72)


func play_grade_tune(label: String) -> void:
	## Distinct cool stingers for ticket-speed grades — a bit lower + softer.
	match label:
		"Wow!":
			_play_cached("grade_wow", _make_wow_tune, 0.88, 0.52)
		"Perfect!":
			_play_cached("grade_perfect", _make_perfect_tune, 0.88, 0.46)
		"Great!":
			_play_cached("grade_great", _make_great_tune, 0.88, 0.40)
		"Good":
			_play_cached("grade_good", _make_good_tune, 0.90, 0.34)
		_:
			play_chaching()


func play_trash() -> void:
	_play_cached("trash", _make_trash, 0.0, 0.85)


func play_error() -> void:
	## Short descending buzz — already holding a patty / invalid grab.
	_play_cached("error_buzz", _make_error, 0.0, 0.55)


func play_grease_pop(loud: bool = false) -> void:
	## Fast fry crackle — same family as the grill sizzle pops, a bit quicker.
	var key := "grease_pop_f_%d" % (randi() % 8)
	var gain := (0.55 + randf() * 0.25) if loud else (0.2 + randf() * 0.12)
	var pitch := (0.95 + randf() * 0.55) if loud else (1.15 + randf() * 0.45)
	_play_cached(key, _make_grease_pop, pitch, gain)


func play_smash_sizzle() -> void:
	## Press juice hiss + a few grease pops when you smash a patty.
	_play_cached("smash_hiss_%d" % (randi() % 4), _make_smash_hiss, 0.92 + randf() * 0.16, 0.85)
	play_grease_pop(true)
	var tree := get_tree()
	if tree == null:
		return
	tree.create_timer(0.04).timeout.connect(func(): play_grease_pop(true))
	tree.create_timer(0.09).timeout.connect(func(): play_grease_pop(false))
	tree.create_timer(0.15).timeout.connect(func(): play_grease_pop(true))


func play_cat_meow() -> void:
	_play_cached("cat_meow_%d" % (randi() % 3), _make_cat_meow, 0.92 + randf() * 0.18, 0.72)


func play_cat_purr() -> void:
	_play_cached("cat_purr_%d" % (randi() % 3), _make_cat_purr, 0.95 + randf() * 0.12, 0.55)


func play_gunshot() -> void:
	_play_cached("gunshot_%d" % (randi() % 4), _make_gunshot, 0.92 + randf() * 0.16, 1.15)


const COMBAT_THEME_PATH := "res://assets/music/double_agent.mp3"
var _combat_player: AudioStreamPlayer = null
var _combat_theme_on: bool = false


func play_combat_theme() -> void:
	## "008 Double Agent" — loops while hostiles are out or the glock is drawn.
	if _combat_player == null:
		_combat_player = AudioStreamPlayer.new()
		_combat_player.name = "CombatTheme"
		_combat_player.bus = "Master"
		add_child(_combat_player)
	if _combat_theme_on and _combat_player.playing:
		return
	if not ResourceLoader.exists(COMBAT_THEME_PATH):
		push_warning("Combat theme missing: %s" % COMBAT_THEME_PATH)
		return
	var stream: AudioStream = load(COMBAT_THEME_PATH) as AudioStream
	if stream == null:
		return
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_combat_player.stream = stream
	_combat_player.volume_db = linear_to_db(0.72)
	_combat_player.pitch_scale = 1.0
	_combat_player.play()
	_combat_theme_on = true


func stop_combat_theme() -> void:
	_combat_theme_on = false
	if _combat_player != null and is_instance_valid(_combat_player):
		_combat_player.stop()


func is_combat_theme_playing() -> bool:
	return _combat_theme_on and _combat_player != null and _combat_player.playing


func play_wilhelm_scream(include_burger_why: bool = true) -> void:
	## Classic Wilhelm scream (CC0 — USC / Wikimedia).
	if not _cache.has("wilhelm"):
		var stream: AudioStream = null
		if ResourceLoader.exists("res://sounds/wilhelm_scream.ogg"):
			stream = load("res://sounds/wilhelm_scream.ogg") as AudioStream
		if stream == null:
			return
		_cache["wilhelm"] = stream
	var p: AudioStreamPlayer = _players[_player_i]
	_player_i = (_player_i + 1) % _players.size()
	p.stream = _cache["wilhelm"]
	p.pitch_scale = 0.96 + randf() * 0.1
	p.volume_db = linear_to_db(1.05)
	p.play()
	## 65% — follow with BURGERWHY (regular customers only; not hostiles).
	if include_burger_why and randf() < 0.65:
		var delay := 1.05
		if p.stream != null and p.stream.get_length() > 0.05:
			delay = p.stream.get_length() / maxf(p.pitch_scale, 0.5)
		get_tree().create_timer(delay).timeout.connect(_play_burger_why)


func _play_burger_why() -> void:
	if not _cache.has("burger_why"):
		var stream: AudioStream = null
		if ResourceLoader.exists("res://sounds/BURGERWHY.wav"):
			stream = load("res://sounds/BURGERWHY.wav") as AudioStream
		if stream == null:
			return
		_cache["burger_why"] = stream
	if _players.is_empty():
		return
	var p: AudioStreamPlayer = _players[_player_i]
	_player_i = (_player_i + 1) % _players.size()
	p.stream = _cache["burger_why"]
	p.pitch_scale = 1.0
	p.volume_db = linear_to_db(0.95)
	p.play()


func set_slide_moving(moving: bool, speed: float = 0.0) -> void:
	## Soft fast-crackle bed under the pops; fades when you stop.
	if moving:
		_slide_target = clampf(0.28 + speed * 1.4, 0.22, 0.7)
	else:
		_slide_target = 0.0


func _play_cached(key: String, builder: Callable, pitch: float, gain: float) -> void:
	if _players.is_empty():
		return
	if not _cache.has(key):
		_cache[key] = builder.call()
	var p: AudioStreamPlayer = _players[_player_i]
	_player_i = (_player_i + 1) % _players.size()
	p.stream = _cache[key]
	p.pitch_scale = 1.0 if pitch <= 0.0 else pitch
	p.volume_db = linear_to_db(clampf(gain, 0.05, 1.5))
	p.play()


func _make_soft_note(midi: int, duration: float) -> AudioStreamWAV:
	var freq := 440.0 * pow(2.0, float(midi - 69) / 12.0)
	var n := maxi(64, int(MIX_RATE * duration))
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var phase := t * freq
		## Soft quiet sine blip — low harmonics, quick fade.
		var wave := sin(phase * TAU) * 0.9 + sin(phase * TAU * 2.0) * 0.08
		var attack := clampf(t / 0.03, 0.0, 1.0)
		var env := attack * exp(-t * 5.5)
		_write_s16(pcm, i, int(clampf(wave * env, -1.0, 1.0) * 11000.0))
	return _wav_from_pcm(pcm, false)


func _make_scale_jingle() -> AudioStreamWAV:
	## Ascending C major run (cheese→mustard) then a bright resolving sparkle.
	var notes := [60, 62, 64, 65, 67, 69, 71, 72, 79, 84]
	var step := 0.068
	var hold := 0.11
	var total := step * float(notes.size() - 1) + 0.55
	var n := int(MIX_RATE * total)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var sample := 0.0
		for ni in notes.size():
			var start := float(ni) * step
			var u := t - start
			if u < 0.0 or u > hold + 0.25:
				continue
			var midi: int = int(notes[ni])
			var freq := 440.0 * pow(2.0, float(midi - 69) / 12.0)
			var attack := clampf(u / 0.012, 0.0, 1.0)
			var env := attack * exp(-u * (3.2 if ni < notes.size() - 2 else 1.8))
			var bright := 1.0 + float(ni) * 0.04
			var wave := (
				sin(u * freq * TAU) * 0.7
				+ sin(u * freq * 2.0 * TAU) * 0.18
				+ sin(u * freq * 3.0 * TAU) * 0.08
			)
			sample += wave * env * bright
		## Soft shimmer tail after the peak.
		if t > step * 8.5:
			var v := t - step * 8.5
			sample += sin(t * 1318.5 * TAU) * exp(-v * 4.5) * 0.22
			sample += sin(t * 1760.0 * TAU) * exp(-v * 5.5) * 0.12
		_write_s16(pcm, i, int(clampf(sample, -1.0, 1.0) * 14000.0))
	return _wav_from_pcm(pcm, false)


func _make_good_tune() -> AudioStreamWAV:
	## Warm major triad bump — friendly “nice one”.
	return _make_arpeggio_tune([60, 64, 67], 0.11, 0.22, 0.35, false)


func _make_great_tune() -> AudioStreamWAV:
	## Bouncy climb with a resolving fifth — punchier than Good.
	return _make_arpeggio_tune([62, 66, 69, 74], 0.085, 0.18, 0.42, true)


func _make_perfect_tune() -> AudioStreamWAV:
	## Flashy sparkle run + shimmer crown — big celebration.
	var notes := [60, 64, 67, 72, 76, 79, 84]
	var step := 0.07
	var hold := 0.16
	var total := step * float(notes.size() - 1) + 0.7
	var n := int(MIX_RATE * total)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var sample := 0.0
		for ni in notes.size():
			var start := float(ni) * step
			var u := t - start
			if u < 0.0 or u > hold + 0.3:
				continue
			var midi: int = int(notes[ni])
			var freq := 440.0 * pow(2.0, float(midi - 69) / 12.0)
			var attack := clampf(u / 0.01, 0.0, 1.0)
			var decay := 2.4 if ni < notes.size() - 1 else 1.35
			var env := attack * exp(-u * decay)
			var wave := (
				sin(u * freq * TAU) * 0.65
				+ sin(u * freq * 2.0 * TAU) * 0.22
				+ sin(u * freq * 3.0 * TAU) * 0.1
			)
			sample += wave * env * (1.0 + float(ni) * 0.05)
		## Golden shimmer after the peak.
		var crown_t := step * float(notes.size() - 2)
		if t > crown_t:
			var v := t - crown_t
			sample += sin(t * 1568.0 * TAU) * exp(-v * 3.2) * 0.28
			sample += sin(t * 2093.0 * TAU) * exp(-v * 4.0) * 0.18
			sample += sin(t * 2637.0 * TAU) * exp(-v * 5.0) * 0.1
		_write_s16(pcm, i, int(clampf(sample, -1.0, 1.0) * 15500.0))
	return _wav_from_pcm(pcm, false)


func _make_wow_tune() -> AudioStreamWAV:
	## Ultra-fast dazzle — bigger/brighter than Perfect for sub-3s serves.
	var notes := [67, 71, 74, 79, 83, 86, 91, 95]
	var step := 0.055
	var hold := 0.14
	var total := step * float(notes.size() - 1) + 0.85
	var n := int(MIX_RATE * total)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var sample := 0.0
		for ni in notes.size():
			var start := float(ni) * step
			var u := t - start
			if u < 0.0 or u > hold + 0.28:
				continue
			var midi: int = int(notes[ni])
			var freq := 440.0 * pow(2.0, float(midi - 69) / 12.0)
			var attack := clampf(u / 0.008, 0.0, 1.0)
			var decay := 2.8 if ni < notes.size() - 1 else 1.2
			var env := attack * exp(-u * decay)
			var wave := (
				sin(u * freq * TAU) * 0.6
				+ sin(u * freq * 2.0 * TAU) * 0.25
				+ sin(u * freq * 4.0 * TAU) * 0.12
			)
			sample += wave * env * (1.05 + float(ni) * 0.06)
		var crown_t := step * float(notes.size() - 2)
		if t > crown_t:
			var v := t - crown_t
			sample += sin(t * 2093.0 * TAU) * exp(-v * 2.8) * 0.32
			sample += sin(t * 2794.0 * TAU) * exp(-v * 3.4) * 0.22
			sample += sin(t * 3136.0 * TAU) * exp(-v * 4.2) * 0.14
			sample += sin(t * 3729.0 * TAU) * exp(-v * 5.0) * 0.08
		_write_s16(pcm, i, int(clampf(sample, -1.0, 1.0) * 16000.0))
	return _wav_from_pcm(pcm, false)


func _make_arpeggio_tune(notes: Array, step: float, hold: float, tail: float, bounce: bool) -> AudioStreamWAV:
	var total := step * float(maxi(notes.size() - 1, 0)) + hold + tail
	var n := int(MIX_RATE * total)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var sample := 0.0
		for ni in notes.size():
			var start := float(ni) * step
			var u := t - start
			if u < 0.0 or u > hold + 0.28:
				continue
			var midi: int = int(notes[ni])
			var freq := 440.0 * pow(2.0, float(midi - 69) / 12.0)
			var attack := clampf(u / 0.014, 0.0, 1.0)
			var env := attack * exp(-u * (3.0 if ni < notes.size() - 1 else 1.7))
			if bounce and ni == notes.size() - 1:
				env *= 1.15
			var wave := (
				sin(u * freq * TAU) * 0.72
				+ sin(u * freq * 2.0 * TAU) * 0.16
				+ sin(u * freq * 3.0 * TAU) * 0.07
			)
			sample += wave * env
		if bounce and t > step * float(notes.size() - 1):
			var v := t - step * float(notes.size() - 1)
			sample += sin(t * 1175.0 * TAU) * exp(-v * 4.2) * 0.16
		_write_s16(pcm, i, int(clampf(sample, -1.0, 1.0) * 14500.0))
	return _wav_from_pcm(pcm, false)


func _make_click() -> AudioStreamWAV:
	var n := int(MIX_RATE * 0.045)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var env := exp(-t * 70.0)
		var wave := sin(t * 1800.0 * TAU) * 0.55 + (randf() * 2.0 - 1.0) * 0.15
		_write_s16(pcm, i, int(wave * env * 16000.0))
	return _wav_from_pcm(pcm, false)


func _make_flip() -> AudioStreamWAV:
	var n := int(MIX_RATE * 0.22)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var env := exp(-t * 9.0)
		## Whoosh + soft meat slap.
		var whoosh := (randf() * 2.0 - 1.0) * exp(-t * 18.0) * 0.45
		var slap := sin(t * 220.0 * TAU) * exp(-t * 28.0) * 0.7
		_write_s16(pcm, i, int(clampf((whoosh + slap) * env, -1.0, 1.0) * 20000.0))
	return _wav_from_pcm(pcm, false)


func _make_ready_ding() -> AudioStreamWAV:
	var n := int(MIX_RATE * 0.55)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var env := exp(-t * 3.5)
		if t < 0.02:
			env *= t / 0.02
		## Two soft bell partials.
		var wave := sin(t * 880.0 * TAU) * 0.55 + sin(t * 1320.0 * TAU) * 0.28 + sin(t * 1760.0 * TAU) * 0.12
		_write_s16(pcm, i, int(wave * env * 18000.0))
	return _wav_from_pcm(pcm, false)


func _make_scoop() -> AudioStreamWAV:
	var n := int(MIX_RATE * 0.18)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var env := exp(-t * 14.0)
		var wave := sin(t * 140.0 * TAU) * 0.5 + (randf() * 2.0 - 1.0) * exp(-t * 30.0) * 0.25
		_write_s16(pcm, i, int(wave * env * 17000.0))
	return _wav_from_pcm(pcm, false)


func _make_serve_bell() -> AudioStreamWAV:
	## Kitchen service bell — bright “order up!” ding-ding.
	var n := int(MIX_RATE * 1.35)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	## Classic desk bell ~G5 / D6 sparkle.
	var f0 := 784.0
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var wave := 0.0
		## First strike.
		var a0 := clampf(t / 0.004, 0.0, 1.0) * exp(-t * 3.1)
		wave += (
			sin(t * f0 * TAU) * 0.62
			+ sin(t * f0 * 2.0 * TAU) * 0.22 * exp(-t * 5.0)
			+ sin(t * f0 * 2.76 * TAU) * 0.28 * exp(-t * 3.8)
			+ sin(t * f0 * 5.15 * TAU) * 0.12 * exp(-t * 7.0)
		) * a0
		## Second “order up” ding.
		if t >= 0.16:
			var u := t - 0.16
			var a1 := clampf(u / 0.004, 0.0, 1.0) * exp(-u * 3.0) * 0.92
			var f1 := f0 * 1.5
			wave += (
				sin(u * f1 * TAU) * 0.58
				+ sin(u * f1 * 2.0 * TAU) * 0.2 * exp(-u * 5.0)
				+ sin(u * f1 * 2.76 * TAU) * 0.24 * exp(-u * 3.6)
			) * a1
		_write_s16(pcm, i, int(clampf(wave, -1.0, 1.0) * 16000.0))
	return _wav_from_pcm(pcm, false)


func _make_trash() -> AudioStreamWAV:
	var n := int(MIX_RATE * 0.16)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var env := exp(-t * 16.0)
		var wave := (randf() * 2.0 - 1.0) * 0.55 + sin(t * 90.0 * TAU) * 0.25
		_write_s16(pcm, i, int(wave * env * 15000.0))
	return _wav_from_pcm(pcm, false)


func _make_error() -> AudioStreamWAV:
	## Two low buzz notes falling — clear “nope” without being harsh.
	var n := int(MIX_RATE * 0.22)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var sample := 0.0
		## First hit ~E3.
		if t < 0.12:
			var u := t
			var env := clampf(u / 0.008, 0.0, 1.0) * exp(-u * 18.0)
			sample += sin(u * 164.8 * TAU) * 0.7 * env
			sample += sin(u * 329.6 * TAU) * 0.2 * env
		## Second hit lower ~C3.
		if t >= 0.08:
			var u2 := t - 0.08
			var env2 := clampf(u2 / 0.01, 0.0, 1.0) * exp(-u2 * 14.0)
			sample += sin(u2 * 130.8 * TAU) * 0.75 * env2
			sample += sin(u2 * 261.6 * TAU) * 0.18 * env2
		_write_s16(pcm, i, int(clampf(sample, -1.0, 1.0) * 16000.0))
	return _wav_from_pcm(pcm, false)


func _make_grease_pop() -> AudioStreamWAV:
	## Quick fry pop — same crackle DNA as the grill sizzle, shorter/faster.
	var n := int(MIX_RATE * 0.028)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	var tick := 2400.0 + randf() * 2200.0
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var env := exp(-t * 95.0)
		if t < 0.001:
			env *= t / 0.001
		var crackle := (randf() * 2.0 - 1.0) * 0.65
		var ping := sin(t * tick * TAU) * 0.35 * exp(-t * 120.0)
		## Tiny bright spit like the live sizzle pops.
		if env > 0.55:
			crackle += (randf() * 2.0 - 1.0) * 0.25
		_write_s16(pcm, i, int(clampf((crackle + ping) * env, -1.0, 1.0) * 13000.0))
	return _wav_from_pcm(pcm, false)


func _make_hot_oil_hit() -> AudioStreamWAV:
	## Loud wet hiss when oil hits hot steel — about 0.35s of fury.
	var n := int(MIX_RATE * 0.38)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	var lp := 0.0
	var hp := 0.0
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var white := randf() * 2.0 - 1.0
		lp = lp * 0.55 + white * 0.45
		hp = white - lp
		var env := 1.0
		if t < 0.02:
			env = t / 0.02
		else:
			env = exp(-(t - 0.02) * 4.2)
		## Bright spit + mid fry roar.
		var roar := lp * 0.45 + hp * 0.9
		var spit := 0.0
		if randf() < 0.08:
			spit = (randf() * 2.0 - 1.0) * 0.7
		var whoosh := sin(t * 90.0 * TAU) * exp(-t * 8.0) * 0.35
		var sample := (roar + spit + whoosh) * env
		_write_s16(pcm, i, int(clampf(sample, -1.0, 1.0) * 22000.0))
	return _wav_from_pcm(pcm, false)


func _make_smash_hiss() -> AudioStreamWAV:
	## Short steam hiss when juice hits hot steel — pops layered separately.
	var n := int(MIX_RATE * 0.22)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	var lp := 0.0
	var hp := 0.0
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var white := randf() * 2.0 - 1.0
		lp = lp * 0.62 + white * 0.38
		hp = white - lp
		var env := 1.0
		if t < 0.012:
			env = t / 0.012
		else:
			env = exp(-(t - 0.012) * 7.5)
		var roar := lp * 0.35 + hp * 0.85
		var spit := 0.0
		if randf() < 0.12:
			spit = (randf() * 2.0 - 1.0) * 0.55
		var sample := (roar + spit) * env
		_write_s16(pcm, i, int(clampf(sample, -1.0, 1.0) * 18000.0))
	return _wav_from_pcm(pcm, false)


func _make_cat_meow() -> AudioStreamWAV:
	## Soft cartoon meow — short rising then falling chirp.
	var n := int(MIX_RATE * 0.28)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	var base := 680.0 + randf() * 90.0
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var glide := 1.0
		if t < 0.08:
			glide = 0.85 + t / 0.08 * 0.35
		else:
			glide = 1.2 - (t - 0.08) * 1.6
		glide = maxf(0.55, glide)
		var freq := base * glide
		var wave := sin(t * freq * TAU) * 0.7 + sin(t * freq * 2.0 * TAU) * 0.18
		var env := 1.0
		if t < 0.02:
			env = t / 0.02
		else:
			env = exp(-(t - 0.02) * 7.0)
		_write_s16(pcm, i, int(clampf(wave * env, -1.0, 1.0) * 14000.0))
	return _wav_from_pcm(pcm, false)


func _make_cat_purr() -> AudioStreamWAV:
	## Gentle throaty purr / pet chirp.
	var n := int(MIX_RATE * 0.32)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var pulse := 0.55 + 0.45 * sin(t * 28.0 * TAU)
		var rumble := sin(t * 55.0 * TAU) * 0.35 + sin(t * 110.0 * TAU) * 0.2
		var chirp := sin(t * 920.0 * TAU) * exp(-t * 9.0) * 0.25
		var env := 1.0
		if t < 0.03:
			env = t / 0.03
		elif t > 0.26:
			env = (0.32 - t) / 0.06
		var sample := (rumble * pulse + chirp) * env
		_write_s16(pcm, i, int(clampf(sample, -1.0, 1.0) * 11000.0))
	return _wav_from_pcm(pcm, false)


func _make_gunshot() -> AudioStreamWAV:
	## Sharp crack + short body boom.
	var n := int(MIX_RATE * 0.22)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	var lp := 0.0
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var white := randf() * 2.0 - 1.0
		lp = lp * 0.72 + white * 0.28
		var crack := white * exp(-t * 85.0)
		var body := lp * exp(-t * 18.0) * 0.85
		var thump := sin(t * 90.0 * TAU) * exp(-t * 28.0) * 0.55
		var env := 1.0
		if t < 0.002:
			env = t / 0.002
		var sample := (crack * 0.9 + body + thump) * env
		_write_s16(pcm, i, int(clampf(sample, -1.0, 1.0) * 24000.0))
	return _wav_from_pcm(pcm, false)


func _make_slide_scrape() -> AudioStreamWAV:
	## Looping fast grease-pop bed — similar to grill crackle, slightly quicker.
	var n := int(MIX_RATE * 0.28)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	var lp := 0.0
	var hp := 0.0
	var pop_env := 0.0
	var pop_tick := 2000.0
	var next_pop := 0.02
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var white := randf() * 2.0 - 1.0
		lp = lp * 0.55 + white * 0.45
		hp = white - lp
		next_pop -= 1.0 / float(MIX_RATE)
		if pop_env < 0.02 and next_pop <= 0.0:
			pop_env = 0.55 + randf() * 0.9
			pop_tick = 2000.0 + randf() * 2600.0
			## Faster clusters than the main sizzle bed.
			if randf() < 0.45:
				next_pop = 0.008 + randf() * 0.02
			else:
				next_pop = 0.025 + randf() * 0.06
		pop_env *= 0.78
		var bed := hp * 0.12 + lp * 0.05
		var pop := 0.0
		if pop_env > 0.02:
			pop = (randf() * 2.0 - 1.0) * pop_env * 0.45
			pop += sin(float(i) * pop_tick * TAU / float(MIX_RATE)) * pop_env * 0.2
		var sample := bed + pop
		var edge := 1.0
		var fade := 0.015
		if t < fade:
			edge = t / fade
		elif t > 0.28 - fade:
			edge = (0.28 - t) / fade
		_write_s16(pcm, i, int(clampf(sample * edge, -1.0, 1.0) * 10000.0))
	return _wav_from_pcm(pcm, true)


static func _wav_from_pcm(pcm: PackedByteArray, loop: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = pcm
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(pcm.size() / 2)
	else:
		stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return stream


static func _write_s16(pcm: PackedByteArray, sample_index: int, value: int) -> void:
	pcm.encode_s16(sample_index * 2, clampi(value, -32768, 32767))
