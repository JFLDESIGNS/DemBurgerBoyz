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
## Dedicated pool for spatula piano / HOLD tings — never shared with one-shot SFX.
var _ting_players: Array[AudioStreamPlayer] = []
var _ting_player_i: int = 0
const TING_POOL := 8
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
## Seasoning shaker — rhythmic rattle while shaking over patties / scraping debris.
var _shake_player: AudioStreamPlayer
var _shake_gen: AudioStreamGenerator
var _shake_on: bool = false
var _shake_season_on: bool = false
var _scrape_move_on: bool = false ## Spatula/brush scrape bed while moving on steel
var _scrape_debris_boost: bool = false ## On actual debris — 2× scrape volumes
var _scrape_dir_pitch: float = 1.0 ## Sideways scrapes pitch up; depth scrapes pitch down
var _shake_lp := 0.0
var _shake_phase := 0.0
var _shake_tick := 0.0
## Was -27 dB; ×3 linear ≈ +9.5 dB. Debris scrape is another ×2 on top.
const SHAKER_RATTLE_DB := -17.5
const SHAKER_SCRAPE_DB := -9.0 ## base grill scrape (~+2.5 dB vs prior)
const SHAKER_SCRAPE_DEBRIS_DB := -2.5 ## debris scrape bed a little louder
var _scrape_ting_cool: float = 0.0
var _scrape_bass_pop_cool: float = 0.0 ## Subtle low pops while crust loosens
const SCRAPE_TING_INTERVAL := 0.4
const SCRAPE_BASS_POP_INTERVAL := 0.28
## Fries pack shake — papery cup + salt-crystal rattle while whipping the serving.
var _fries_shake_player: AudioStreamPlayer
var _fries_shake_gen: AudioStreamGenerator
var _fries_shake_on: bool = false
var _fries_shake_intensity: float = 0.0
var _fries_shake_lp := 0.0
var _fries_shake_phase := 0.0
var _fries_shake_tick := 0.0
## Outdoor tree leaf rustle — seasoning-like shake, a bit louder; pitch follows mouse.
var _tree_leaf_player: AudioStreamPlayer
var _tree_leaf_gen: AudioStreamGenerator
var _tree_leaf_on: bool = false
var _tree_leaf_intensity: float = 0.0
var _tree_leaf_pitch: float = 1.0
var _tree_leaf_lp := 0.0
var _tree_leaf_phase := 0.0
var _tree_leaf_tick := 0.0
const TREE_LEAF_SHAKE_DB := -13.5 ## ~+4 dB vs seasoning rattle (-17.5)
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
## Wet oil squish + steam hiss while spatula-sliding a burger.
var _oil_slide_player: AudioStreamPlayer
var _oil_slide_gain: float = 0.0
var _oil_slide_target: float = 0.0
var _oil_slide_pop_cd: float = 0.0
## 24% quieter burger-slide stack (metal + oil bed + accents).
const BURGER_SLIDE_VOL_MUL := 0.76
var _roomba_drive_player: AudioStreamPlayer
var _roomba_drive_gain: float = 0.0
var _roomba_drive_target: float = 0.0
var _roomba_drive_volume_scale: float = 1.0
## Hot oil on a lit grill — loud fry burst, then a soft 2s die-out.
var _hot_oil_full_left: float = 0.0
var _hot_oil_fade_left: float = 0.0
const HOT_OIL_FADE_SEC := 2.0
var _hot_oil_pop_cd: float = 0.0
var _hot_oil_was_active: bool = false
var _hot_oil_volume_mul: float = 1.0 ## 1 = full fry; ice-water spots use 0.5
## Fountain soda pour — continuous dispenser static.
var _soda_player: AudioStreamPlayer
var _soda_gen: AudioStreamGenerator
var _soda_on: bool = false
var _soda_lp := 0.0
var _soda_bp := 0.0
## Ice machine — crumb/crusher grind while dispensing cubes.
var _ice_player: AudioStreamPlayer
var _ice_gen: AudioStreamGenerator
var _ice_on: bool = false
var _ice_lp := 0.0
var _ice_phase := 0.0
var _ice_tick := 0.0
var _softserve_player: AudioStreamPlayer
var _softserve_gen: AudioStreamGenerator
var _softserve_on: bool = false
var _softserve_lp := 0.0
var _softserve_phase := 0.0
var _softserve_chime_phase := 0.0
var _softserve_tick := 0.0
var _fryer_player: AudioStreamPlayer
var _fryer_gen: AudioStreamGenerator
var _fryer_on: bool = false
var _fryer_intensity: float = 1.0
var _fryer_lp := 0.0
var _fryer_hp := 0.0
var _fryer_pop_env := 0.0
var _fryer_pop_tick := 2200.0
var _fryer_next_pop := 0.0
var _fryer_sample_i := 0
## Soft continuous room tone (174 / 285 / 396 Hz) — independent of grill/fire FX.
var _room_tone_player: AudioStreamPlayer
var _room_tone_gen: AudioStreamGenerator
var _room_tone_on: bool = false
var _room_tone_hz: float = 174.0
var _room_tone_vol: float = 0.0
var _room_tone_phase: float = 0.0
var _room_tone_muted: bool = false ## true during particle prewarm — no beds / no underrun hiss
const OUTDOOR_AMBIENCE_PATH := "res://sounds/outdoor_forest_ambience.mp3"
var _outdoor_ambience_player: AudioStreamPlayer = null
var _outdoor_ambience_vol: float = 0.0
var _outdoor_ambience_on: bool = false
var _outdoor_ambience_muted: bool = false


func _ready() -> void:
	add_to_group("game_audio")
	for i in SFX_POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	for i in TING_POOL:
		var tp := AudioStreamPlayer.new()
		tp.name = "SpatulaTing_%d" % i
		tp.bus = "Master"
		tp.volume_db = -80.0
		add_child(tp)
		_ting_players.append(tp)
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
	## Fries pack shake while carrying a serving.
	_fries_shake_gen = AudioStreamGenerator.new()
	_fries_shake_gen.mix_rate = MIX_RATE
	_fries_shake_gen.buffer_length = 0.12
	_fries_shake_player = AudioStreamPlayer.new()
	_fries_shake_player.bus = "Master"
	_fries_shake_player.stream = _fries_shake_gen
	_fries_shake_player.volume_db = -80.0
	add_child(_fries_shake_player)
	## Live outdoor tree leaf rustle (hold-shake).
	_tree_leaf_gen = AudioStreamGenerator.new()
	_tree_leaf_gen.mix_rate = MIX_RATE
	_tree_leaf_gen.buffer_length = 0.12
	_tree_leaf_player = AudioStreamPlayer.new()
	_tree_leaf_player.bus = "Master"
	_tree_leaf_player.stream = _tree_leaf_gen
	_tree_leaf_player.volume_db = -80.0
	add_child(_tree_leaf_player)
	## Soda fountain dispenser hiss / carbonation rush.
	_soda_gen = AudioStreamGenerator.new()
	_soda_gen.mix_rate = MIX_RATE
	_soda_gen.buffer_length = 0.12
	_soda_player = AudioStreamPlayer.new()
	_soda_player.bus = "Master"
	_soda_player.stream = _soda_gen
	_soda_player.volume_db = -80.0
	add_child(_soda_player)
	## Ice crusher grind while cubes drop.
	_ice_gen = AudioStreamGenerator.new()
	_ice_gen.mix_rate = MIX_RATE
	_ice_gen.buffer_length = 0.12
	_ice_player = AudioStreamPlayer.new()
	_ice_player.bus = "Master"
	_ice_player.stream = _ice_gen
	_ice_player.volume_db = -80.0
	add_child(_ice_player)
	_softserve_gen = AudioStreamGenerator.new()
	_softserve_gen.mix_rate = MIX_RATE
	_softserve_gen.buffer_length = 0.12
	_softserve_player = AudioStreamPlayer.new()
	_softserve_player.bus = "Master"
	_softserve_player.stream = _softserve_gen
	_softserve_player.volume_db = -80.0
	add_child(_softserve_player)
	_fryer_gen = AudioStreamGenerator.new()
	_fryer_gen.mix_rate = MIX_RATE
	_fryer_gen.buffer_length = 0.12
	_fryer_player = AudioStreamPlayer.new()
	_fryer_player.bus = "Master"
	_fryer_player.stream = _fryer_gen
	_fryer_player.volume_db = -80.0
	add_child(_fryer_player)
	## Looping soft metal scrape for patty slides.
	_slide_player = AudioStreamPlayer.new()
	_slide_player.bus = "Master"
	_slide_player.stream = _make_slide_scrape()
	_slide_player.volume_db = -80.0
	add_child(_slide_player)
	## Wet oil squish / steam hiss while sliding a burger with the spatula.
	_oil_slide_player = AudioStreamPlayer.new()
	_oil_slide_player.name = "BurgerSlideOil"
	_oil_slide_player.bus = "Master"
	_oil_slide_player.stream = _make_burger_slide_oil_loop()
	_oil_slide_player.volume_db = -80.0
	add_child(_oil_slide_player)
	_roomba_drive_player = AudioStreamPlayer.new()
	_roomba_drive_player.name = "RoombaDrive"
	_roomba_drive_player.bus = "Master"
	_roomba_drive_player.stream = _make_roomba_drive()
	_roomba_drive_player.volume_db = -80.0
	add_child(_roomba_drive_player)
	## Soft sine room bed — filled every frame while on (never underrun).
	_room_tone_gen = AudioStreamGenerator.new()
	_room_tone_gen.mix_rate = MIX_RATE
	_room_tone_gen.buffer_length = 0.12
	_room_tone_player = AudioStreamPlayer.new()
	_room_tone_player.name = "RoomTone"
	_room_tone_player.bus = "Master"
	_room_tone_player.stream = _room_tone_gen
	_room_tone_player.volume_db = -80.0
	add_child(_room_tone_player)
	_outdoor_ambience_player = AudioStreamPlayer.new()
	_outdoor_ambience_player.name = "OutdoorAmbience"
	_outdoor_ambience_player.bus = "Master"
	_outdoor_ambience_player.volume_db = -80.0
	add_child(_outdoor_ambience_player)
	set_process(true)


func _process(delta: float) -> void:
	## Fade crackle bed toward target (up when sliding, down when stopped).
	var fade_spd := 7.0 if _slide_target > _slide_gain else 3.2
	_slide_gain = move_toward(_slide_gain, _slide_target, delta * fade_spd)
	if _slide_player:
		if _slide_gain > 0.01:
			## Moving scrape on steel; debris hits are 2× that bed.
			var slide_mul := 1.0
			if _scrape_move_on:
				slide_mul = 5.0 if _scrape_debris_boost else 2.6
			elif _oil_slide_gain > 0.01:
				## Burger drag layers metal + oil — keep the scrape bed quieter too.
				slide_mul = BURGER_SLIDE_VOL_MUL
			_slide_player.volume_db = linear_to_db(clampf(_slide_gain * 0.42 * slide_mul, 0.02, 1.15))
			_slide_player.pitch_scale = (1.15 + _slide_gain * 0.2) * _scrape_dir_pitch
			if not _slide_player.playing:
				_slide_player.play()
		elif _slide_player.playing:
			_slide_player.stop()
			_slide_player.volume_db = -80.0
			_slide_player.pitch_scale = 1.0
			_scrape_dir_pitch = 1.0
	## Burger spatula-slide: wet oil squish bed + hiss pops (−24% vs prior).
	var oil_fade := 8.0 if _oil_slide_target > _oil_slide_gain else 4.0
	_oil_slide_gain = move_toward(_oil_slide_gain, _oil_slide_target, delta * oil_fade)
	if _oil_slide_player:
		if _oil_slide_gain > 0.01:
			_oil_slide_player.volume_db = linear_to_db(clampf(_oil_slide_gain * 0.31 * BURGER_SLIDE_VOL_MUL, 0.02, 0.38))
			_oil_slide_player.pitch_scale = 0.92 + _oil_slide_gain * 0.18
			if not _oil_slide_player.playing:
				_oil_slide_player.play()
			_oil_slide_pop_cd -= delta
			if _oil_slide_pop_cd <= 0.0:
				## Squish spit + steam hiss accents while the burger scrapes through grease.
				play_grease_pop(false)
				if randf() < 0.55:
					_play_cached(
						"slide_squish_hiss_%d" % (randi() % 4),
						_make_smash_hiss,
						0.88 + randf() * 0.2,
						(0.21 + _oil_slide_gain * 0.175) * BURGER_SLIDE_VOL_MUL
					)
				_oil_slide_pop_cd = lerpf(0.14, 0.055, clampf(_oil_slide_gain, 0.0, 1.0)) + randf() * 0.03
		elif _oil_slide_player.playing:
			_oil_slide_player.stop()
			_oil_slide_player.volume_db = -80.0
			_oil_slide_player.pitch_scale = 1.0
			_oil_slide_pop_cd = 0.0
	_tick_scrape_tings(delta)
	_roomba_drive_gain = move_toward(_roomba_drive_gain, _roomba_drive_target, delta * (4.2 if _roomba_drive_target > _roomba_drive_gain else 5.5))
	if _roomba_drive_player:
		if _roomba_drive_gain > 0.01:
			var drive_linear := clampf(_roomba_drive_gain * 0.32 * _roomba_drive_volume_scale, 0.0001, 1.4)
			_roomba_drive_player.volume_db = linear_to_db(drive_linear)
			_roomba_drive_player.pitch_scale = 1.42 + _roomba_drive_gain * 0.58
			if not _roomba_drive_player.playing:
				_roomba_drive_player.play()
		elif _roomba_drive_player.playing:
			_roomba_drive_player.stop()
			_roomba_drive_player.volume_db = -80.0
			_roomba_drive_player.pitch_scale = 1.0
	## Hot oil on lit steel — loud fry for the full window, then a 2s die-out.
	var oil_active := _hot_oil_full_left > 0.0 or _hot_oil_fade_left > 0.0
	var oil_fade_t := 1.0 ## 1 = full blast, 0 = silent
	var vol_mul := clampf(_hot_oil_volume_mul, 0.05, 1.0)
	if _hot_oil_full_left > 0.0:
		_hot_oil_full_left = maxf(0.0, _hot_oil_full_left - delta)
		_hot_oil_was_active = true
		_sizzle_on = true
		oil_fade_t = 1.0
		if _hot_oil_full_left <= 0.0:
			_hot_oil_fade_left = HOT_OIL_FADE_SEC
		if _sizzle_player != null:
			_sizzle_player.volume_db = linear_to_db(db_to_linear(-3.5) * vol_mul)
			if not _sizzle_player.playing:
				_sizzle_player.play()
		_hot_oil_pop_cd -= delta
		if _hot_oil_pop_cd <= 0.0:
			## Soften pop cluster when volume is dialed down (ice water).
			if vol_mul >= 0.85 or randf() < vol_mul:
				play_grease_pop(true)
			if vol_mul >= 0.85 and randf() < 0.55:
				play_grease_pop(true)
			_hot_oil_pop_cd = lerpf(0.06, 0.028, vol_mul) + randf() * 0.045
	elif _hot_oil_fade_left > 0.0:
		_hot_oil_fade_left = maxf(0.0, _hot_oil_fade_left - delta)
		_hot_oil_was_active = true
		_sizzle_on = true
		oil_fade_t = clampf(_hot_oil_fade_left / HOT_OIL_FADE_SEC, 0.0, 1.0)
		if _sizzle_player != null:
			## Soft linear die-out over the fade window.
			var fade_db := lerpf(-42.0, -6.0, oil_fade_t)
			_sizzle_player.volume_db = linear_to_db(db_to_linear(fade_db) * vol_mul)
			if not _sizzle_player.playing:
				_sizzle_player.play()
		_hot_oil_pop_cd -= delta
		if _hot_oil_pop_cd <= 0.0 and oil_fade_t > 0.08:
			if randf() < oil_fade_t * vol_mul:
				play_grease_pop(true)
			_hot_oil_pop_cd = lerpf(0.14, 0.04, oil_fade_t) + randf() * 0.05
	elif _hot_oil_was_active:
		_hot_oil_was_active = false
		_hot_oil_volume_mul = 1.0
		if _sizzle_on and _sizzle_player != null:
			_sizzle_player.volume_db = lerpf(-18.0, -12.0, clampf(_sizzle_intensity, 0.0, 1.0))
	if _sizzle_on and _sizzle_player != null and _sizzle_player.playing:
		var playback := _sizzle_player.get_stream_playback() as AudioStreamGeneratorPlayback
		if playback != null:
			var t := clampf(_sizzle_intensity, 0.0, 1.0)
			var oil_mul := 1.0
			if oil_active:
				oil_mul = lerpf(1.0, 2.4, oil_fade_t) * vol_mul
				t = maxf(t, oil_fade_t)
			## Quieter static bed (50%); crackles stay full strength.
			var bed_gain := lerpf(0.06, 0.1, t) * oil_mul
			var pop_chance_boost := lerpf(1.0, 1.6, t) * lerpf(1.0, 3.2, oil_fade_t if oil_active else 0.0) * vol_mul
			while playback.get_frames_available() > 0:
				var sample := _next_sizzle_sample(bed_gain, pop_chance_boost)
				if oil_active:
					sample = clampf(sample * lerpf(1.0, 1.55, oil_fade_t) * vol_mul, -1.0, 1.0)
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
	if _fries_shake_on and _fries_shake_player != null and _fries_shake_player.playing:
		var fsp := _fries_shake_player.get_stream_playback() as AudioStreamGeneratorPlayback
		if fsp != null:
			while fsp.get_frames_available() > 0:
				var fss := _next_fries_shake_sample()
				fsp.push_frame(Vector2(fss, fss))
	if _tree_leaf_on and _tree_leaf_player != null and _tree_leaf_player.playing:
		var tlp := _tree_leaf_player.get_stream_playback() as AudioStreamGeneratorPlayback
		if tlp != null:
			while tlp.get_frames_available() > 0:
				var tls := _next_tree_leaf_shake_sample()
				tlp.push_frame(Vector2(tls, tls))
	if _soda_on and _soda_player != null and _soda_player.playing:
		var sop := _soda_player.get_stream_playback() as AudioStreamGeneratorPlayback
		if sop != null:
			while sop.get_frames_available() > 0:
				var sos := _next_soda_pour_sample()
				sop.push_frame(Vector2(sos, sos))
	if _ice_on and _ice_player != null and _ice_player.playing:
		var ip := _ice_player.get_stream_playback() as AudioStreamGeneratorPlayback
		if ip != null:
			while ip.get_frames_available() > 0:
				var ics := _next_ice_grind_sample()
				ip.push_frame(Vector2(ics, ics))
	if _softserve_on and _softserve_player != null and _softserve_player.playing:
		var ssp := _softserve_player.get_stream_playback() as AudioStreamGeneratorPlayback
		if ssp != null:
			while ssp.get_frames_available() > 0:
				var ss := _next_softserve_sample()
				ssp.push_frame(Vector2(ss, ss))
	if _fryer_on and _fryer_player != null and _fryer_player.playing:
		var fp := _fryer_player.get_stream_playback() as AudioStreamGeneratorPlayback
		if fp != null:
			while fp.get_frames_available() > 0:
				var fs := _next_fryer_oil_sample()
				fp.push_frame(Vector2(fs, fs))
	## Soft room tone — keep buffer fed whenever playing so we never hiss from underrun.
	if _room_tone_on and not _room_tone_muted and _room_tone_player != null and _room_tone_player.playing:
		var rtp := _room_tone_player.get_stream_playback() as AudioStreamGeneratorPlayback
		if rtp != null:
			while rtp.get_frames_available() > 0:
				var rs := _next_room_tone_sample()
				rtp.push_frame(Vector2(rs, rs))
	## Safety: a generator left playing without fill = continuous static.
	_stop_generator_if_orphaned(_sizzle_player, _sizzle_on)
	_stop_generator_if_orphaned(_hiss_player, _hiss_on)
	_stop_generator_if_orphaned(_spray_player, _spray_on)
	_stop_generator_if_orphaned(_shake_player, _shake_on)
	_stop_generator_if_orphaned(_fries_shake_player, _fries_shake_on)
	_stop_generator_if_orphaned(_soda_player, _soda_on)
	_stop_generator_if_orphaned(_ice_player, _ice_on)
	_stop_generator_if_orphaned(_softserve_player, _softserve_on)
	_stop_generator_if_orphaned(_fryer_player, _fryer_on)
	_stop_generator_if_orphaned(_room_tone_player, _room_tone_on and not _room_tone_muted)


func _stop_generator_if_orphaned(player: AudioStreamPlayer, active: bool) -> void:
	if player == null:
		return
	if player.playing and not active:
		player.stop()
		player.volume_db = -80.0


func silence_continuous_beds(mute_room_tone: bool = true) -> void:
	## Fire FX prewarm only — mute the room tone so compile bursts stay silent.
	## Do NOT kill grill sizzle / hiss / fry beds (those must keep working in-shift).
	if mute_room_tone:
		_room_tone_muted = true
		_room_tone_on = false
		if _room_tone_player != null and is_instance_valid(_room_tone_player):
			if _room_tone_player.playing:
				_room_tone_player.stop()
			_room_tone_player.volume_db = -80.0
		_outdoor_ambience_muted = true
		_outdoor_ambience_on = false
		if _outdoor_ambience_player != null and is_instance_valid(_outdoor_ambience_player):
			if _outdoor_ambience_player.playing:
				_outdoor_ambience_player.stop()
			_outdoor_ambience_player.volume_db = -80.0
	else:
		_room_tone_muted = false
		_outdoor_ambience_muted = false


func _load_outdoor_ambience_stream() -> AudioStreamMP3:
	## Load Midlands England birdsong MP3 from disk (avoids broken/missing .import in exports).
	if not FileAccess.file_exists(OUTDOOR_AMBIENCE_PATH):
		push_warning("Outdoor ambience missing: %s" % OUTDOOR_AMBIENCE_PATH)
		return null
	var f := FileAccess.open(OUTDOOR_AMBIENCE_PATH, FileAccess.READ)
	if f == null:
		push_warning("Outdoor ambience open failed: %s" % OUTDOOR_AMBIENCE_PATH)
		return null
	var data := f.get_buffer(f.get_length())
	f.close()
	if data.is_empty():
		return null
	var stream := AudioStreamMP3.new()
	stream.data = data
	stream.loop = true
	return stream


func set_outdoor_ambience(volume_linear: float) -> void:
	## Looping Midlands England forest birdsong. volume_linear 0 = off; up to 3.0 loud.
	_outdoor_ambience_vol = clampf(volume_linear, 0.0, 3.0)
	_outdoor_ambience_muted = false
	if _outdoor_ambience_player == null:
		return
	if _outdoor_ambience_vol <= 0.001:
		_outdoor_ambience_on = false
		if _outdoor_ambience_player.playing:
			_outdoor_ambience_player.stop()
		_outdoor_ambience_player.volume_db = -80.0
		return
	if _outdoor_ambience_player.stream == null:
		var stream := _load_outdoor_ambience_stream()
		if stream == null:
			return
		_outdoor_ambience_player.stream = stream
	_outdoor_ambience_on = true
	## Slider 1.0 ≈ −6 dB; slider 3.0 ≈ 3× that ceiling (linear 1.5).
	var linear := clampf(_outdoor_ambience_vol * 0.5, 0.0008, 1.5)
	_outdoor_ambience_player.volume_db = linear_to_db(linear)
	if not _outdoor_ambience_player.playing:
		_outdoor_ambience_player.play()


func set_room_tone(hz: float, volume_linear: float) -> void:
	## Soft sine room bed. volume_linear 0 = off; 1 = still a light bed.
	## Independent of grill / fry / fire SFX — never replaces those beds.
	_room_tone_hz = maxf(20.0, hz)
	_room_tone_vol = clampf(volume_linear, 0.0, 1.0)
	_room_tone_muted = false
	if _room_tone_player == null:
		return
	if _room_tone_vol <= 0.001:
		_room_tone_on = false
		if _room_tone_player.playing:
			_room_tone_player.stop()
		_room_tone_player.volume_db = -80.0
		return
	_room_tone_on = true
	## Cap stays quiet — slider 1.0 ≈ −30 dB, default off until unlocked/set.
	var linear := clampf(_room_tone_vol * 0.045, 0.0008, 0.05)
	_room_tone_player.volume_db = linear_to_db(linear)
	if not _room_tone_player.playing:
		_room_tone_player.play()


func _next_room_tone_sample() -> float:
	## Soft pure tone + tiny air grain so it reads as room, not a test beep.
	_room_tone_phase += _room_tone_hz / float(MIX_RATE)
	if _room_tone_phase >= 1.0:
		_room_tone_phase -= floorf(_room_tone_phase)
	var tone := sin(_room_tone_phase * TAU)
	## Very quiet octave + breath — keeps it from feeling sterile.
	var air := (randf() * 2.0 - 1.0) * 0.012
	var soft := sin(_room_tone_phase * TAU * 2.0) * 0.08
	return clampf(tone * 0.55 + soft + air, -1.0, 1.0)


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


func trigger_hot_oil(duration: float = 3.0, volume_mul: float = 1.0) -> void:
	## Oil hits a hot grill — fry for `duration`, then a 2s soft die-out.
	## `volume_mul` 0.5 = half loud (ice-water spots); full oil keeps 1.0.
	var starting := _hot_oil_full_left <= 0.05 and _hot_oil_fade_left <= 0.05
	var v := clampf(volume_mul, 0.05, 1.0)
	## Never quiet a louder burst already in progress.
	if _hot_oil_full_left > 0.05 or _hot_oil_fade_left > 0.05:
		_hot_oil_volume_mul = maxf(_hot_oil_volume_mul, v)
	else:
		_hot_oil_volume_mul = v
	_hot_oil_full_left = maxf(_hot_oil_full_left, duration)
	_hot_oil_fade_left = 0.0 ## re-hit cancels an in-progress fade
	_sizzle_on = true
	_sizzle_intensity = maxf(_sizzle_intensity, 0.95 * _hot_oil_volume_mul)
	if _sizzle_player != null:
		_sizzle_player.volume_db = linear_to_db(db_to_linear(-3.5) * _hot_oil_volume_mul)
		if not _sizzle_player.playing:
			_sizzle_player.play()
	## Kill idle hiss under the burst so the fry reads clearly.
	if _hiss_on and _hiss_player != null and _hiss_player.playing:
		_hiss_on = false
		_hiss_player.stop()
	if starting:
		if _hot_oil_volume_mul >= 0.85:
			play_hot_oil_hit()
		_hot_oil_pop_cd = 0.0
		## Immediate pop cluster on contact (softer when volume is dialed down).
		var pops := 4 if _hot_oil_volume_mul >= 0.85 else 2
		for _i in pops:
			play_grease_pop(true)


func stop_hot_oil() -> void:
	## End a plastic/oil fry burst early (cup finished melting).
	_hot_oil_full_left = 0.0
	_hot_oil_fade_left = 0.45


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
	_shake_season_on = active
	_sync_shaker_rattle()


func set_scrape_debris_rattle(active: bool) -> void:
	## Compat: debris-only scrape (brush / legacy). Prefer set_grill_scrape.
	set_grill_scrape(active, active)


func set_grill_scrape(moving: bool, on_debris: bool = false) -> void:
	## Scrape bed + soft tings while LMB-dragging the spatula on the flat-top.
	## on_debris → 2× louder rattle/slide (+ same ting cadence).
	var was := _scrape_move_on
	_scrape_move_on = moving
	_scrape_debris_boost = moving and on_debris
	if moving and not was:
		_scrape_ting_cool = randf_range(0.08, 0.22)
		_scrape_bass_pop_cool = randf_range(0.10, 0.22)
	if not moving:
		_scrape_ting_cool = 0.0
		_scrape_bass_pop_cool = 0.0
		_scrape_debris_boost = false
		_scrape_dir_pitch = 1.0
		## Snap the metal slide bed off with scrape — don't leave a stuck loop after LMB up.
		_slide_target = 0.0
		_slide_gain = 0.0
		if _slide_player != null and _slide_player.playing:
			_slide_player.stop()
			_slide_player.volume_db = -80.0
			_slide_player.pitch_scale = 1.0
	_sync_shaker_rattle()


func set_scrape_direction(dir_xz: Vector2) -> void:
	## Pitch follows scrape direction — sideways brighter, depth/forward darker.
	if dir_xz.length_squared() < 0.0000001:
		return
	var n := dir_xz.normalized()
	## n.x = grill left/right, n.y = grill depth (stored Z).
	var side := absf(n.x)
	var depth := absf(n.y)
	var target := lerpf(0.90, 1.28, side) * lerpf(1.0, 0.94, depth)
	_scrape_dir_pitch = lerpf(_scrape_dir_pitch, target, 0.35)


func _sync_shaker_rattle() -> void:
	if _shake_player == null:
		return
	var active := _shake_season_on or _scrape_move_on
	if active:
		_shake_on = true
		if _scrape_move_on:
			_shake_player.volume_db = SHAKER_SCRAPE_DEBRIS_DB if _scrape_debris_boost else SHAKER_SCRAPE_DB
			_shake_player.pitch_scale = _scrape_dir_pitch
		else:
			_shake_player.volume_db = SHAKER_RATTLE_DB
			_shake_player.pitch_scale = 1.0
		if not _shake_player.playing:
			_shake_player.play()
	else:
		_shake_on = false
		if _shake_player.playing:
			_shake_player.stop()
		_shake_player.volume_db = -80.0
		_shake_player.pitch_scale = 1.0


func _tick_scrape_tings(delta: float) -> void:
	## Soft spatula tings while scraping (~0.4s, slight irregularity).
	## Debris also gets subtle bassy fleck-pops while the crust loosens.
	if _scrape_move_on and _scrape_debris_boost:
		_scrape_bass_pop_cool = maxf(0.0, _scrape_bass_pop_cool - delta)
		if _scrape_bass_pop_cool <= 0.0:
			_scrape_bass_pop_cool = SCRAPE_BASS_POP_INTERVAL + randf_range(-0.08, 0.14)
			play_debris_bass_pop(0.55 + randf() * 0.25)
	if not _scrape_move_on:
		return
	_scrape_ting_cool = maxf(0.0, _scrape_ting_cool - delta)
	if _scrape_ting_cool > 0.0:
		return
	_scrape_ting_cool = SCRAPE_TING_INTERVAL + randf_range(-0.10, 0.12)
	var ting_vol := 0.62 if _scrape_debris_boost else 0.32
	play_spatula_ting(randi_range(69, 75), ting_vol)


func play_debris_bass_pop(volume_scale: float = 1.0) -> void:
	## Subtle low thud — crust fleck letting go under the spatula.
	var key := "debris_bass_%d" % (randi() % 6)
	var gain := (0.28 + randf() * 0.14) * clampf(volume_scale, 0.0, 1.5)
	var pitch := 0.82 + randf() * 0.28
	_play_cached(key, _make_debris_bass_pop, pitch, gain)


func set_fries_shake(active: bool, intensity: float = 1.0) -> void:
	## Paper cup + salt-crystal rattle while whipping a fries pack.
	if _fries_shake_player == null:
		return
	_fries_shake_intensity = clampf(intensity, 0.0, 1.0)
	if active and _fries_shake_intensity > 0.05:
		_fries_shake_on = true
		_fries_shake_player.volume_db = lerpf(-40.0, -28.0, _fries_shake_intensity)
		if not _fries_shake_player.playing:
			_fries_shake_player.play()
	else:
		_fries_shake_on = false
		if _fries_shake_player.playing:
			_fries_shake_player.stop()
		_fries_shake_player.volume_db = -80.0


func set_soda_pour(active: bool) -> void:
	## Static drink-dispenser rush while soda is pouring.
	if _soda_player == null:
		return
	if active:
		_soda_on = true
		_soda_player.volume_db = -14.0
		if not _soda_player.playing:
			_soda_player.play()
	else:
		_soda_on = false
		if _soda_player.playing:
			_soda_player.stop()
		_soda_player.volume_db = -80.0


func set_ice_grind(active: bool) -> void:
	## Soft ice-machine hush while cubes are dispensing.
	if _ice_player == null:
		return
	if active:
		_ice_on = true
		_ice_player.volume_db = -22.0
		if not _ice_player.playing:
			_ice_player.play()
	else:
		_ice_on = false
		if _ice_player.playing:
			_ice_player.stop()
		_ice_player.volume_db = -80.0


func set_softserve_dispense(active: bool) -> void:
	if _softserve_player == null:
		return
	if active:
		_softserve_on = true
		_softserve_player.volume_db = -7.5
		if not _softserve_player.playing:
			_softserve_player.play()
	else:
		_softserve_on = false
		if _softserve_player.playing:
			_softserve_player.stop()
		_softserve_player.volume_db = -80.0


func set_fryer_oil(active: bool, intensity: float = 1.0) -> void:
	if _fryer_player == null:
		return
	_fryer_intensity = clampf(intensity, 0.0, 1.35)
	if active:
		_fryer_on = true
		_fryer_player.volume_db = -4.5
		if not _fryer_player.playing:
			_fryer_player.play()
	else:
		_fryer_on = false
		if _fryer_player.playing:
			_fryer_player.stop()
		_fryer_player.volume_db = -80.0


func play_ice_tink() -> void:
	## Soft cube settle in the cup.
	_play_cached("ice_tink_v2", _make_ice_tink, 0.92 + randf() * 0.18, 0.35 + randf() * 0.15)


func _next_soda_pour_sample() -> float:
	## Soft carbonated dispenser static — continuous fountain hiss.
	var white := randf() * 2.0 - 1.0
	_soda_lp = _soda_lp * 0.86 + white * 0.14
	var hp := white - _soda_lp
	_soda_bp = _soda_bp * 0.62 + hp * 0.38
	var rush := _soda_bp * 0.42 + hp * 0.28 + _soda_lp * 0.06
	if randf() < 0.003:
		rush += (randf() * 2.0 - 1.0) * 0.22
	return clampf(rush * 0.34, -1.0, 1.0)


func _next_ice_grind_sample() -> float:
	## Soft cooler hush — gentle rumble, light rain of crumbs (not a harsh grind).
	_ice_tick += 1.0 / float(MIX_RATE)
	var grind_hz := 9.0 + sin(_ice_tick * 1.6) * 1.5
	_ice_phase += grind_hz / float(MIX_RATE)
	var pulse := 0.78 + 0.22 * absf(sin(_ice_phase * TAU))
	var white := randf() * 2.0 - 1.0
	## Heavy low-pass so it stays soft / soothing.
	_ice_lp = _ice_lp * 0.88 + white * 0.12
	var soft := _ice_lp * 0.55 + (white - _ice_lp) * 0.08
	var flake := 0.0
	if randf() < 0.004:
		flake = (randf() * 2.0 - 1.0) * 0.08
	return clampf((soft * 0.22 + flake) * pulse, -1.0, 1.0)


func _next_softserve_sample() -> float:
	## Gentle motor plus a soft airy cream flow.
	_softserve_tick += 1.0 / float(MIX_RATE)
	var motor_hz := 54.0 + sin(_softserve_tick * 1.1) * 2.0
	_softserve_phase = fposmod(_softserve_phase + motor_hz / float(MIX_RATE), 1.0)
	_softserve_chime_phase = fposmod(_softserve_chime_phase + 247.0 / float(MIX_RATE), 1.0)
	var motor := sin(_softserve_phase * TAU) * 0.16 + sin(_softserve_phase * TAU * 2.0) * 0.035
	var white := randf() * 2.0 - 1.0
	_softserve_lp = _softserve_lp * 0.92 + white * 0.08
	var airy := _softserve_lp * 0.18 + (white - _softserve_lp) * 0.035
	var shimmer := sin(_softserve_chime_phase * TAU) * 0.035
	var pulse := 0.82 + 0.18 * sin(_softserve_tick * 4.2)
	return clampf((motor + airy + shimmer) * pulse * 0.64, -1.0, 1.0)


func _next_fryer_oil_sample() -> float:
	var t := clampf(_fryer_intensity, 0.0, 1.35)
	var white := randf() * 2.0 - 1.0
	_fryer_lp = _fryer_lp * 0.50 + white * 0.50
	_fryer_hp = white - _fryer_lp
	_fryer_next_pop -= 1.0 / float(MIX_RATE)
	if _fryer_pop_env < 0.018 and _fryer_next_pop <= 0.0:
		_fryer_pop_env = 0.8 + randf() * 1.1
		_fryer_pop_tick = 1800.0 + randf() * 3900.0
		_fryer_next_pop = 0.012 + randf() * 0.055 if randf() < 0.58 else 0.06 + randf() * 0.11
	_fryer_pop_env *= 0.80
	var bed := (_fryer_lp * 0.34 + _fryer_hp * 0.78) * lerpf(0.28, 0.48, t)
	var pop := 0.0
	if _fryer_pop_env > 0.01:
		pop = (randf() * 2.0 - 1.0) * _fryer_pop_env * 0.64
		pop += sin(float(_fryer_sample_i) * _fryer_pop_tick * TAU / float(MIX_RATE)) * _fryer_pop_env * 0.20
	_fryer_sample_i += 1
	var wet := sin(float(_fryer_sample_i) * 94.0 * TAU / float(MIX_RATE)) * 0.035
	return clampf((bed + pop + wet) * 0.82, -1.0, 1.0)


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


func _next_fries_shake_sample() -> float:
	## Soft paper-cup rustle + tiny crystal ticks while the pack is whipped.
	_fries_shake_tick += 1.0 / float(MIX_RATE)
	var shake_hz := 4.2 + sin(_fries_shake_tick * 2.0) * 0.65
	_fries_shake_phase += shake_hz / float(MIX_RATE)
	var pulse := maxf(0.0, sin(_fries_shake_phase * TAU))
	pulse = pow(pulse, 0.38)
	var white := randf() * 2.0 - 1.0
	_fries_shake_lp = _fries_shake_lp * 0.68 + white * 0.32
	var paper := (white - _fries_shake_lp) * 0.42 + _fries_shake_lp * 0.06
	var crystal := 0.0
	if pulse > 0.86 and randf() < 0.026 * lerpf(0.45, 0.9, _fries_shake_intensity):
		crystal = (randf() * 2.0 - 1.0) * 0.09
	var gain := lerpf(0.38, 0.74, _fries_shake_intensity)
	return clampf((paper * 0.15 + crystal) * pulse * gain, -1.0, 1.0)


func _next_tree_leaf_shake_sample() -> float:
	## Seasoning-cousin rustle — airier / brighter leaf grain, a touch louder.
	_tree_leaf_tick += 1.0 / float(MIX_RATE)
	var shake_hz := 6.4 + sin(_tree_leaf_tick * 2.4) * 1.15
	_tree_leaf_phase += shake_hz / float(MIX_RATE)
	var pulse := maxf(0.0, sin(_tree_leaf_phase * TAU))
	pulse = pow(pulse, 0.40)
	var white := randf() * 2.0 - 1.0
	_tree_leaf_lp = _tree_leaf_lp * 0.62 + white * 0.38
	var leaf := (white - _tree_leaf_lp) * 0.48 + _tree_leaf_lp * 0.05
	var flick := 0.0
	if pulse > 0.88 and randf() < 0.034 * lerpf(0.5, 1.0, _tree_leaf_intensity):
		flick = (randf() * 2.0 - 1.0) * 0.14
	var gain := lerpf(0.55, 1.05, _tree_leaf_intensity)
	return clampf((leaf * 0.28 + flick) * pulse * gain, -1.0, 1.0)


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
	## Buns get the hollow body thud (same as clicking the 3D pile).
	if id == "bun_top" or id == "bun_bottom":
		play_bun_thud()
		return
	var midi: int = int(INGREDIENT_MIDI.get(id, 60))
	## Soft quiet tap — stays under sizzle / radio / grade stingers.
	_play_cached("ing_%d" % midi, func(): return _make_soft_note(midi, 0.32), 0.0, 0.12)


func play_bun_thud() -> void:
	## Medium bassy body knock — lighter / hollower than the street-tree thud.
	## v3 keys force a rebuild of the louder sample; gain −20% from prior 1.35.
	_play_cached("bun_thud_v3_%d" % (randi() % 3), _make_bun_thud, 0.94 + randf() * 0.12, 1.08)


func play_cutting_board_thud() -> void:
	## Empty Build board tap — denser / quicker / deader than the hollow bun knock.
	_play_cached(
		"cutting_board_thud_v1_%d" % (randi() % 3),
		_make_cutting_board_thud,
		0.97 + randf() * 0.07,
		0.68
	)


func play_scale_jingle() -> void:
	## Quick rising arpeggio + sparkle when every strip note has been hit.
	_play_cached("scale_jingle", _make_scale_jingle, 0.0, 0.32)


func play_happy_four_note() -> float:
	## Short major-arpeggio sting (C–E–G–C) before the Burger Pals VO.
	var step := 0.125
	var hold := 0.20
	var tail := 0.12
	_play_cached(
		"happy_four_note",
		func(): return _make_arpeggio_tune([60, 64, 67, 72], step, hold, tail, true),
		1.0,
		0.55
	)
	return step * 3.0 + hold + tail


func play_click() -> void:
	_play_cached("ui_click", _make_click, 1.0, 0.85)


func play_cup_plastic_tap(volume_scale: float = 1.0) -> void:
	## Dull Solo-cup plastic hit on steel — soft mid thud, almost no sparkle.
	var g := clampf(volume_scale, 0.15, 1.35)
	_play_cached(
		"cup_plastic_tap_v1_%d" % (randi() % 3),
		_make_cup_plastic_tap,
		0.94 + randf() * 0.1,
		0.78 * g
	)


func play_rack_take() -> void:
	## Pleasant little thud when a cup/cone leaves its holder.
	_play_cached("rack_take_thud", _make_rack_take_thud, 0.96 + randf() * 0.08, 0.62)


func play_tree_thud() -> void:
	## Soft wood trunk hit when shaking a street tree.
	_play_cached("tree_thud_%d" % (randi() % 3), _make_tree_thud, 0.88 + randf() * 0.14, 0.78)


func play_tree_leaf_tap() -> void:
	## One-shot leaf rustle on a single tree click — seasoning-like, a bit louder.
	_play_cached(
		"tree_leaf_tap_v1_%d" % (randi() % 3),
		_make_tree_leaf_tap,
		0.94 + randf() * 0.12,
		1.05
	)


func set_tree_leaf_shake(active: bool, intensity: float = 1.0) -> void:
	## Continuous leaf shake while holding LMB and moving the mouse on a tree.
	if _tree_leaf_player == null:
		return
	_tree_leaf_intensity = clampf(intensity, 0.0, 1.5)
	if active and _tree_leaf_intensity > 0.04:
		_tree_leaf_on = true
		var linear := db_to_linear(TREE_LEAF_SHAKE_DB) * lerpf(0.45, 1.15, _tree_leaf_intensity)
		_tree_leaf_player.volume_db = linear_to_db(clampf(linear, 0.02, 1.2))
		_tree_leaf_player.pitch_scale = _tree_leaf_pitch
		if not _tree_leaf_player.playing:
			_tree_leaf_player.play()
	else:
		_tree_leaf_on = false
		_tree_leaf_intensity = 0.0
		if _tree_leaf_player.playing:
			_tree_leaf_player.stop()
		_tree_leaf_player.volume_db = -80.0
		_tree_leaf_player.pitch_scale = 1.0
		_tree_leaf_pitch = 1.0


func set_tree_leaf_shake_motion(mouse_delta: Vector2) -> void:
	## Tone follows shake direction — L/R and U/D each pull pitch.
	if mouse_delta.length_squared() < 0.0001:
		return
	var nx := clampf(mouse_delta.x / 28.0, -1.0, 1.0)
	var ny := clampf(mouse_delta.y / 28.0, -1.0, 1.0)
	## Right / up → brighter; left / down → darker.
	var target := 1.0 + nx * 0.26 - ny * 0.22
	_tree_leaf_pitch = lerpf(_tree_leaf_pitch, clampf(target, 0.76, 1.38), 0.42)
	if _tree_leaf_player != null and _tree_leaf_on:
		_tree_leaf_player.pitch_scale = _tree_leaf_pitch


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


func play_spatula_ting(midi: int = 72, volume_scale: float = 1.0) -> void:
	## tinggrill.wav — labeled C5 / MIDI 72 but reads ~3 semis flat (≈A4).
	## Grill flat taps: C major ×2 C3→B4 (request MIDI = sounded + 3).
	if _ting_players.is_empty():
		return
	var semis := float(midi - 72)
	if not _cache.has("tinggrill"):
		var loaded: AudioStream = _load_tinggrill_stream()
		if loaded == null:
			loaded = _make_spatula_ting_note(72)
		_cache["tinggrill"] = loaded
	var p: AudioStreamPlayer = _ting_players[_ting_player_i]
	_ting_player_i = (_ting_player_i + 1) % _ting_players.size()
	p.stream = _cache["tinggrill"]
	## Allow C3…key-transposed B4 (+ roll); clamp only wild HOLD/scrape callers.
	semis = clampf(semis, -24.0, 16.0)
	p.pitch_scale = pow(2.0, semis / 12.0)
	var base_gain := 1.75
	var away := absf(semis)
	## Stronger recovery when pitching the sample down toward C3.
	var pitch_boost := 1.0 + away * (0.14 if semis < 0.0 else 0.05)
	if away > 0.001:
		pitch_boost *= 1.2
	var gain := base_gain * pitch_boost * maxf(0.0, volume_scale)
	p.volume_db = linear_to_db(clampf(gain, 0.05, 3.5))
	p.play()


func play_spatula_drum(pad: int = 2, volume_scale: float = 1.0, voice: int = 0) -> void:
	## HOLD-zone taps. voice: 0 = drum · 1 = closed hi-hat · 2 = open hat / rim.
	if _players.is_empty():
		return
	var p_i := clampi(pad, 0, 4)
	var v := clampi(voice, 0, 2)
	var key := "hold_kit_v4_%d_%d" % [v, p_i]
	if not _cache.has(key):
		match v:
			1:
				_cache[key] = _make_hold_hihat(p_i, false)
			2:
				_cache[key] = _make_hold_hihat(p_i, true)
			_:
				_cache[key] = _make_hold_drum(p_i)
	var p: AudioStreamPlayer = _players[_player_i]
	_player_i = (_player_i + 1) % _players.size()
	p.stream = _cache[key]
	p.pitch_scale = 1.0
	## Flat drums stay under the piano; hats sit a touch brighter.
	var base_gain := (0.55 if v == 0 else 0.62) * maxf(0.0, volume_scale)
	p.volume_db = linear_to_db(base_gain)
	p.play()
	## Louder tin / steel layer so HOLD hits still read as metal spatula on grill.
	var ting_midi := int(round(lerpf(76.0, 69.0, float(p_i) / 4.0)))
	var ting_vol := 0.72 if v == 0 else (0.48 if v == 1 else 0.40)
	play_spatula_ting(ting_midi, ting_vol * maxf(0.0, volume_scale))


func _load_tinggrill_stream() -> AudioStream:
	const PATH := "res://sounds/tinggrill.wav"
	if ResourceLoader.exists(PATH):
		var res := load(PATH)
		if res is AudioStream:
			return res
	## Editor hasn't written .import yet — decode the WAV file directly.
	if not FileAccess.file_exists(PATH):
		return null
	return AudioStreamWAV.load_from_file(PATH)


func play_chaching() -> void:
	## Soft service bell fallback.
	play_order_up()


func play_order_up() -> void:
	## Classic kitchen “order up!” — bright double service-bell ding.
	_play_cached("order_up_bell", _make_serve_bell, 0.0, 0.72)


func play_serve_whoosh() -> void:
	## Soft air rush as the burger tosses through the window.
	_play_cached("serve_whoosh", _make_serve_whoosh, 0.0, 0.38)


func play_spatula_whoosh() -> void:
	## Air rush for the spatula flip flourish.
	## 20% quieter than prior 0.084 gain.
	_play_cached("spatula_whoosh", _make_spatula_whoosh, 0.0, 0.0672)


func play_burger_chomp() -> void:
	## Quick bite when the burger hits the customer's mouth.
	_play_cached("burger_chomp", _make_burger_chomp, 0.0, 0.55)


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


func play_grease_pop(loud: bool = false, volume_scale: float = 1.0) -> void:
	## Fast fry crackle — same family as the grill sizzle pops, a bit quicker.
	var key := "grease_pop_f_%d" % (randi() % 8)
	var gain := (0.55 + randf() * 0.25) if loud else (0.2 + randf() * 0.12)
	gain *= clampf(volume_scale, 0.0, 1.5)
	var pitch := (0.95 + randf() * 0.55) if loud else (1.15 + randf() * 0.45)
	_play_cached(key, _make_grease_pop, pitch, gain)


const SMASH_SIZZLE_VOL_MUL := 0.8 ## Place / smoosh bed — 20% quieter than prior.

func play_smash_sizzle(volume_scale: float = 1.0) -> void:
	## Press juice hiss + a few grease pops when you smash a patty.
	var vol := clampf(volume_scale, 0.0, 1.5) * SMASH_SIZZLE_VOL_MUL
	_play_cached("smash_hiss_%d" % (randi() % 4), _make_smash_hiss, 0.92 + randf() * 0.16, 0.85 * vol)
	if vol >= 0.75 * SMASH_SIZZLE_VOL_MUL:
		play_grease_pop(true, SMASH_SIZZLE_VOL_MUL)
		var tree := get_tree()
		if tree == null:
			return
		tree.create_timer(0.04).timeout.connect(func(): play_grease_pop(true, SMASH_SIZZLE_VOL_MUL))
		tree.create_timer(0.09).timeout.connect(func(): play_grease_pop(false, SMASH_SIZZLE_VOL_MUL))
		tree.create_timer(0.15).timeout.connect(func(): play_grease_pop(true, SMASH_SIZZLE_VOL_MUL))
	else:
		## Half-volume slide smoosh — one quiet pop, no cluster.
		play_grease_pop(false, SMASH_SIZZLE_VOL_MUL)


func play_cat_meow() -> void:
	_play_cached("cat_meow_%d" % (randi() % 3), _make_cat_meow, 0.92 + randf() * 0.18, 0.72)


func play_cat_purr() -> void:
	_play_cached("cat_purr_%d" % (randi() % 3), _make_cat_purr, 0.95 + randf() * 0.12, 0.55)


const WAWA_PATH := "res://sounds/wawawa.ogg"
const GROBBLE_CLIP_SEC := 3.0
const GROBBLE_FADE_IN_SEC := 0.3
const CLICK_WAWA_CLIP_SEC := 1.15
var _roomba_wawawa_player: AudioStreamPlayer = null
var _roomba_wawawa_on: bool = false
var _customer_click_wawa: AudioStreamPlayer = null
var _customer_click_wawa_tween: Tween = null
var _customer_click_wawa_stop_at_msec: int = 0
const GROBBLE_PITCH := 1.293 ## prior 1.22 × +6%

func play_customer_grobble(impatience: float = 0.5) -> void:
	## Random 3s slice of wawawa.ogg — pitched up, fade in over 0.3s, then stop.
	if not ResourceLoader.exists(WAWA_PATH):
		return
	if not _cache.has("wawawa"):
		var loaded: AudioStream = load(WAWA_PATH) as AudioStream
		if loaded == null:
			return
		_cache["wawawa"] = loaded
	var stream: AudioStream = _cache["wawawa"]
	var length := stream.get_length()
	## Pitched playback consumes more source per wall-clock second.
	var source_needed := GROBBLE_CLIP_SEC * GROBBLE_PITCH
	var max_start := maxf(0.0, length - source_needed)
	var start_at := randf() * max_start if max_start > 0.0 else 0.0
	## Louder as they wait — up to +8% by late patience.
	var base_gain := lerpf(0.62, 0.82, clampf(impatience, 0.0, 1.0))
	var gain := base_gain * lerpf(1.0, 1.08, clampf(impatience, 0.0, 1.0))
	var target_db := linear_to_db(gain)
	var p := AudioStreamPlayer.new()
	p.bus = "Master"
	p.stream = stream
	p.pitch_scale = GROBBLE_PITCH
	p.volume_db = -80.0
	add_child(p)
	p.play(start_at)
	var tw := create_tween()
	tw.tween_property(p, "volume_db", target_db, GROBBLE_FADE_IN_SEC)
	var tree := get_tree()
	if tree == null:
		return
	tree.create_timer(GROBBLE_CLIP_SEC).timeout.connect(func():
		if is_instance_valid(p):
			p.stop()
			p.queue_free()
	)


func play_customer_wawa_click(impatience: float = 0.5) -> void:
	## One reusable player — spam-click restarts instead of stacking voices.
	if not ResourceLoader.exists(WAWA_PATH):
		return
	if not _cache.has("wawawa"):
		var loaded: AudioStream = load(WAWA_PATH) as AudioStream
		if loaded == null:
			return
		_cache["wawawa"] = loaded
	var stream: AudioStream = _cache["wawawa"]
	var length := stream.get_length()
	var source_needed := CLICK_WAWA_CLIP_SEC * GROBBLE_PITCH
	var max_start := maxf(0.0, length - source_needed)
	var start_at := randf() * max_start if max_start > 0.0 else 0.0
	var base_gain := lerpf(0.62, 0.82, clampf(impatience, 0.0, 1.0))
	var gain := base_gain * lerpf(1.0, 1.08, clampf(impatience, 0.0, 1.0))
	var target_db := linear_to_db(gain)
	if _customer_click_wawa == null or not is_instance_valid(_customer_click_wawa):
		_customer_click_wawa = AudioStreamPlayer.new()
		_customer_click_wawa.name = "CustomerClickWawa"
		_customer_click_wawa.bus = "Master"
		add_child(_customer_click_wawa)
	if _customer_click_wawa_tween != null and is_instance_valid(_customer_click_wawa_tween):
		_customer_click_wawa_tween.kill()
	_customer_click_wawa.stream = stream
	_customer_click_wawa.pitch_scale = GROBBLE_PITCH
	_customer_click_wawa.volume_db = -80.0
	_customer_click_wawa.stop()
	_customer_click_wawa.play(start_at)
	_customer_click_wawa_tween = create_tween()
	_customer_click_wawa_tween.tween_property(_customer_click_wawa, "volume_db", target_db, GROBBLE_FADE_IN_SEC)
	_customer_click_wawa_stop_at_msec = Time.get_ticks_msec() + int(CLICK_WAWA_CLIP_SEC * 1000.0)
	var stop_token := _customer_click_wawa_stop_at_msec
	var tree := get_tree()
	if tree == null:
		return
	tree.create_timer(CLICK_WAWA_CLIP_SEC).timeout.connect(func():
		if stop_token != _customer_click_wawa_stop_at_msec:
			return
		if _customer_click_wawa != null and is_instance_valid(_customer_click_wawa):
			_customer_click_wawa.stop()
	)


func play_gunshot() -> void:
	_play_cached("gunshot_%d" % (randi() % 4), _make_gunshot, 0.92 + randf() * 0.16, 1.15)


func set_roomba_wawawa(active: bool) -> void:
	_roomba_wawawa_on = active
	if not ResourceLoader.exists(WAWA_PATH):
		return
	if _roomba_wawawa_player == null:
		var loaded: AudioStream = load(WAWA_PATH) as AudioStream
		if loaded == null:
			return
		_roomba_wawawa_player = AudioStreamPlayer.new()
		_roomba_wawawa_player.name = "RoombaWawawa"
		_roomba_wawawa_player.bus = "Master"
		_roomba_wawawa_player.stream = loaded
		add_child(_roomba_wawawa_player)
		_roomba_wawawa_player.finished.connect(func():
			if _roomba_wawawa_on and _roomba_wawawa_player != null and is_instance_valid(_roomba_wawawa_player):
				_roomba_wawawa_player.play(0.0)
		)
	_roomba_wawawa_player.pitch_scale = 2.18 ## a bit higher than prior 1.93
	_roomba_wawawa_player.volume_db = 1.0
	if active:
		if not _roomba_wawawa_player.playing:
			_roomba_wawawa_player.play(0.0)
	else:
		if _roomba_wawawa_player.playing:
			_roomba_wawawa_player.stop()


func play_roomba_wawa_chirp() -> void:
	if not ResourceLoader.exists(WAWA_PATH):
		return
	if not _cache.has("roomba_wawa_chirp"):
		var loaded: AudioStream = load(WAWA_PATH) as AudioStream
		if loaded == null:
			return
		_cache["roomba_wawa_chirp"] = loaded
	var p: AudioStreamPlayer = _players[_player_i]
	_player_i = (_player_i + 1) % _players.size()
	p.stream = _cache["roomba_wawa_chirp"]
	p.pitch_scale = 1.96 + randf() * 0.16
	p.volume_db = linear_to_db(0.56)
	p.play(randf_range(0.0, 0.65))
	var tree := get_tree()
	if tree != null:
		tree.create_timer(0.28 + randf() * 0.18).timeout.connect(func():
			if p != null and is_instance_valid(p):
				p.stop()
		)


func play_roomba_done_beep() -> void:
	_play_cached("roomba_done_beep", _make_roomba_done_beep, 1.0, 0.86)


func play_roomba_body_tap() -> void:
	## Hard plastic shell click — 2× louder + crisper than the old dull tick.
	_play_cached(
		"roomba_plastic_tap_v2_%d" % (randi() % 3),
		_make_roomba_body_tap,
		1.06 + randf() * 0.14,
		1.5
	)


func set_roomba_drive(moving: bool, speed: float = 0.0) -> void:
	if moving:
		_roomba_drive_target = clampf(0.22 + speed * 1.35, 0.22, 0.56)
	else:
		_roomba_drive_target = 0.0


func set_roomba_drive_volume_scale(scale: float) -> void:
	_roomba_drive_volume_scale = clampf(scale, 0.0, 2.5)
	if _roomba_drive_volume_scale <= 0.001 and _roomba_drive_player != null:
		_roomba_drive_player.volume_db = -80.0


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
	p.volume_db = linear_to_db(0.475) ## half prior loudness
	p.play()


func set_slide_moving(moving: bool, speed: float = 0.0) -> void:
	## Soft fast-crackle bed under the pops; fades when you stop.
	if moving:
		_slide_target = clampf(0.28 + speed * 1.4, 0.22, 0.7)
	else:
		_slide_target = 0.0


func set_burger_slide_oil(moving: bool, speed: float = 0.0) -> void:
	## Spatula dragging a burger — wet oil squish + steam hiss (not dry metal scrape).
	if moving:
		_oil_slide_target = clampf(0.38 + speed * 1.15, 0.32, 1.0)
	else:
		_oil_slide_target = 0.0


func _make_burger_slide_oil_loop() -> AudioStreamWAV:
	## Looping wet grease squish + steam hiss under a sliding burger.
	var n := int(MIX_RATE * 0.32)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	var lp := 0.0
	var hp := 0.0
	var mid := 0.0
	var pop_env := 0.0
	var pop_tick := 1800.0
	var next_pop := 0.018
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var white := randf() * 2.0 - 1.0
		lp = lp * 0.72 + white * 0.28
		mid = mid * 0.45 + white * 0.55
		hp = white - lp
		next_pop -= 1.0 / float(MIX_RATE)
		if pop_env < 0.02 and next_pop <= 0.0:
			pop_env = 0.45 + randf() * 0.7
			pop_tick = 1600.0 + randf() * 2200.0
			next_pop = 0.012 + randf() * 0.045
		pop_env *= 0.82
		## Soft steam bed + wet mid squish + bright spit.
		var hiss := hp * 0.55 + mid * 0.18
		var squish := lp * 0.42
		var spit := 0.0
		if pop_env > 0.02:
			spit = (randf() * 2.0 - 1.0) * pop_env * 0.38
			spit += sin(float(i) * pop_tick * TAU / float(MIX_RATE)) * pop_env * 0.16
		var sample := hiss * 0.7 + squish * 0.55 + spit
		var edge := 1.0
		var fade := 0.018
		if t < fade:
			edge = t / fade
		elif t > 0.32 - fade:
			edge = (0.32 - t) / fade
		_write_s16(pcm, i, int(clampf(sample * edge, -1.0, 1.0) * 14500.0))
	return _wav_from_pcm(pcm, true)


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


func _make_roomba_done_beep() -> AudioStreamWAV:
	var n := int(MIX_RATE * 0.24)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var note_a := clampf(t / 0.008, 0.0, 1.0) * exp(-t * 16.0)
		var t2 := maxf(0.0, t - 0.092)
		var note_b := clampf(t2 / 0.006, 0.0, 1.0) * exp(-t2 * 20.0)
		var wave := sin(t * 1320.0 * TAU) * note_a * 0.72
		wave += sin(t2 * 1760.0 * TAU) * note_b * 0.62
		wave += sin(t * 2640.0 * TAU) * note_a * 0.10
		_write_s16(pcm, i, int(clampf(wave, -1.0, 1.0) * 13500.0))
	return _wav_from_pcm(pcm, false)


func _make_roomba_body_tap() -> AudioStreamWAV:
	## Crisp ABS click — snappy HF transient, almost no dull mid thump.
	var n := int(MIX_RATE * 0.048)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	var f0 := 1560.0 + randf() * 280.0
	var f1 := 2420.0 + randf() * 360.0
	var f2 := 3180.0 + randf() * 420.0
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var attack := clampf(t / 0.00055, 0.0, 1.0)
		var env := attack * exp(-t * 95.0)
		## Sharp noise spike at contact.
		var click := (randf() * 2.0 - 1.0) * exp(-t * 220.0) * 0.85
		var shell := sin(t * f0 * TAU) * exp(-t * 78.0) * 0.48
		var ring := sin(t * f1 * TAU) * exp(-t * 110.0) * 0.32
		var sparkle := sin(t * f2 * TAU) * exp(-t * 145.0) * 0.18
		_write_s16(pcm, i, int(clampf((click + shell + ring + sparkle) * env, -1.0, 1.0) * 21000.0))
	return _wav_from_pcm(pcm, false)


func _make_cup_plastic_tap() -> AudioStreamWAV:
	## Dull thin plastic on steel — muted mid knock, short hollow shell, no bright click.
	var n := int(MIX_RATE * 0.09)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	var body_f := 210.0 + randf() * 55.0
	var shell_f := 480.0 + randf() * 90.0
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var attack := clampf(t / 0.0018, 0.0, 1.0)
		var env := attack * exp(-t * 38.0)
		var body := sin(t * body_f * TAU) * 0.62 + sin(t * (body_f * 1.7) * TAU) * 0.22
		var shell := sin(t * shell_f * TAU) * exp(-t * 52.0) * 0.34
		var grit := (randf() * 2.0 - 1.0) * exp(-t * 90.0) * 0.08
		_write_s16(pcm, i, int(clampf((body + shell + grit) * env, -1.0, 1.0) * 15000.0))
	return _wav_from_pcm(pcm, false)


func _make_rack_take_thud() -> AudioStreamWAV:
	var n := int(MIX_RATE * 0.16)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var bump_env := clampf(t / 0.012, 0.0, 1.0) * exp(-t * 18.0)
		var tick_env := exp(-t * 48.0)
		var bump := sin(t * 128.0 * TAU) * 0.72 + sin(t * 246.0 * TAU) * 0.18
		var tick := sin(t * 1120.0 * TAU) * 0.12 + (randf() * 2.0 - 1.0) * 0.035
		var sample := bump * bump_env + tick * tick_env
		_write_s16(pcm, i, int(clampf(sample, -1.0, 1.0) * 12500.0))
	return _wav_from_pcm(pcm, false)


func _make_tree_thud() -> AudioStreamWAV:
	## Low woody trunk knock — denser / longer than rack take.
	var n := int(MIX_RATE * 0.22)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var env := clampf(t / 0.008, 0.0, 1.0) * exp(-t * 11.5)
		var body := sin(t * 72.0 * TAU) * 0.78 + sin(t * 118.0 * TAU) * 0.28
		var wood := sin(t * 210.0 * TAU) * exp(-t * 22.0) * 0.22
		var grit := (randf() * 2.0 - 1.0) * exp(-t * 55.0) * 0.06
		_write_s16(pcm, i, int(clampf((body + wood + grit) * env, -1.0, 1.0) * 15500.0))
	return _wav_from_pcm(pcm, false)


func _make_tree_leaf_tap() -> AudioStreamWAV:
	## Short leaf rustle burst — seasoning-rattle cousin, brighter and a bit louder.
	var n := int(MIX_RATE * 0.20)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	var lp := 0.0
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var env := clampf(t / 0.008, 0.0, 1.0) * exp(-t * 16.0)
		var pulse := maxf(0.0, sin(t * 28.0 * TAU))
		pulse = pow(pulse, 0.42)
		var white := randf() * 2.0 - 1.0
		lp = lp * 0.60 + white * 0.40
		var leaf := (white - lp) * 0.55 + lp * 0.04
		var flick := 0.0
		if pulse > 0.82 and randf() < 0.05:
			flick = (randf() * 2.0 - 1.0) * 0.18
		_write_s16(pcm, i, int(clampf((leaf * 0.32 + flick) * pulse * env, -1.0, 1.0) * 17500.0))
	return _wav_from_pcm(pcm, false)


func _make_bun_thud() -> AudioStreamWAV:
	## Tree-cousin knock — shorter, lighter, hollow soft-bread cavity (louder body).
	var n := int(MIX_RATE * 0.17)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var env := clampf(t / 0.005, 0.0, 1.0) * exp(-t * 14.5)
		## Mid-bass body (lighter than tree 72 Hz).
		var body := sin(t * 96.0 * TAU) * 0.78 + sin(t * 148.0 * TAU) * 0.30
		## Hollow airy shell — soft cavity resonance, decays faster.
		var hollow := sin(t * 255.0 * TAU) * exp(-t * 26.0) * 0.38
		hollow += sin(t * 380.0 * TAU) * exp(-t * 38.0) * 0.14
		var crumb := (randf() * 2.0 - 1.0) * exp(-t * 65.0) * 0.04
		_write_s16(pcm, i, int(clampf((body + hollow + crumb) * env, -1.0, 1.0) * 19000.0))
	return _wav_from_pcm(pcm, false)


func _make_cutting_board_thud() -> AudioStreamWAV:
	## Short dead wood knock — dense mid body, almost no hollow cavity, quick decay.
	var n := int(MIX_RATE * 0.078)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var env := clampf(t / 0.0025, 0.0, 1.0) * exp(-t * 42.0)
		var body := sin(t * 118.0 * TAU) * 0.82 + sin(t * 188.0 * TAU) * 0.28
		## Tiny hard shell only — no hollow bun air.
		var shell := sin(t * 265.0 * TAU) * exp(-t * 70.0) * 0.07
		var grit := (randf() * 2.0 - 1.0) * exp(-t * 95.0) * 0.045
		_write_s16(pcm, i, int(clampf((body + shell + grit) * env, -1.0, 1.0) * 15500.0))
	return _wav_from_pcm(pcm, false)


func _make_ice_tink() -> AudioStreamWAV:
	## Soft muffled tap when a cube settles in the cup.
	var n := int(MIX_RATE * 0.11)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var env := exp(-t * 26.0)
		var ping := sin(t * 980.0 * TAU) * 0.42 + sin(t * 1480.0 * TAU) * 0.18
		var tick := (randf() * 2.0 - 1.0) * exp(-t * 70.0) * 0.08
		_write_s16(pcm, i, int(clampf((ping + tick) * env, -1.0, 1.0) * 11000.0))
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


func _make_serve_whoosh() -> AudioStreamWAV:
	var n := int(MIX_RATE * 0.28)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var u := t / 0.28
		var env := sin(clampf(u, 0.0, 1.0) * PI) * exp(-u * 1.4)
		var noise := (randf() * 2.0 - 1.0) * 0.55
		var tone := sin(t * lerpf(420.0, 180.0, u) * TAU) * 0.22
		_write_s16(pcm, i, int(clampf((noise + tone) * env, -1.0, 1.0) * 14000.0))
	return _wav_from_pcm(pcm, false)


func _make_spatula_whoosh() -> AudioStreamWAV:
	## Quick air swipe — matches the flourish spin (~0.55s).
	var dur := 0.42
	var n := int(MIX_RATE * dur)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var u := t / dur
		var env := sin(clampf(u, 0.0, 1.0) * PI) * exp(-u * 0.85)
		var noise := (randf() * 2.0 - 1.0) * 0.62
		var tone := sin(t * lerpf(520.0, 140.0, u) * TAU) * 0.28
		var hiss := sin(t * lerpf(1800.0, 600.0, u) * TAU) * (randf() * 0.12)
		_write_s16(pcm, i, int(clampf((noise + tone + hiss) * env, -1.0, 1.0) * 16500.0))
	return _wav_from_pcm(pcm, false)


func _make_burger_chomp() -> AudioStreamWAV:
	var n := int(MIX_RATE * 0.16)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var env := exp(-t * 22.0)
		var thud := sin(t * 95.0 * TAU) * 0.7
		var crunch := (randf() * 2.0 - 1.0) * exp(-t * 40.0) * 0.45
		var slap := sin(t * 260.0 * TAU) * exp(-t * 30.0) * 0.35
		_write_s16(pcm, i, int(clampf((thud + crunch + slap) * env, -1.0, 1.0) * 21000.0))
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


func _make_spatula_ting() -> AudioStreamWAV:
	return _make_spatula_ting_note(84)


func _make_spatula_ting_note(midi: int) -> AudioStreamWAV:
	## Sharp steel ting — bright / short / inharmonic (not a thuddy drum).
	## Octave up from the strip MIDI so each key still differs but stays crisp.
	var freq := 440.0 * pow(2.0, float(midi - 69) / 12.0) * 2.0
	var n := int(MIX_RATE * 0.14)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		## Fast attack, quick decay — triangle / spoon-on-steel feel.
		var env := exp(-t * 28.0)
		if t < 0.0012:
			env *= t / 0.0012
		var ting := (
			sin(t * freq * TAU) * 0.38 * exp(-t * 18.0)
			+ sin(t * freq * 2.76 * TAU) * 0.42 ## inharmonic clang
			+ sin(t * freq * 5.15 * TAU) * 0.22 * exp(-t * 26.0)
			+ sin(t * freq * 8.4 * TAU) * 0.12 * exp(-t * 40.0)
			+ sin(t * freq * 12.1 * TAU) * 0.07 * exp(-t * 55.0)
		)
		var spark := (randf() * 2.0 - 1.0) * exp(-t * 120.0) * 0.22
		_write_s16(pcm, i, int(clampf((ting + spark) * env, -1.0, 1.0) * 26000.0))
	return _wav_from_pcm(pcm, false)


func _make_hold_drum(pad: int) -> AudioStreamWAV:
	## Spatula on HOLD — kick/tom with pitch drop + beater click (less sine-y).
	## pad 0 (window) = higher tom; pad 4 (cook edge) = deeper kick.
	var p := clampf(float(pad), 0.0, 4.0) / 4.0
	var f_start := lerpf(210.0, 105.0, p)
	var f_end := lerpf(118.0, 48.0, p)
	var n := int(MIX_RATE * 0.28)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5200 + pad * 31
	var phase := 0.0
	for i in n:
		var t := float(i) / float(MIX_RATE)
		## Classic drum pitch sweep — tight attack, warm body.
		var sweep := exp(-t * 22.0)
		var freq := lerpf(f_end, f_start, sweep)
		phase += freq * TAU / float(MIX_RATE)
		var env_body := exp(-t * 11.0)
		var env_click := exp(-t * 70.0)
		if t < 0.0014:
			var a := t / 0.0014
			env_body *= a
			env_click *= a
		var body := sin(phase) * 0.55 + sin(phase * 1.5) * 0.16 * exp(-t * 20.0)
		## Beater / stick click — short filtered noise + mid tick.
		var click := (
			(rng.randf() * 2.0 - 1.0) * 0.38
			+ sin(t * lerpf(2600.0, 1800.0, p) * TAU) * 0.26
		) * env_click
		## Soft sub thump under the body.
		var sub := sin(t * f_end * 0.5 * TAU) * 0.20 * exp(-t * 8.0)
		## Baked tin clang — spatula-on-steel character mixed into the drum.
		var f_tin := lerpf(1180.0, 780.0, p)
		var tin := (
			sin(t * f_tin * TAU) * 0.28
			+ sin(t * f_tin * 2.76 * TAU) * 0.18 * exp(-t * 36.0)
			+ sin(t * f_tin * 5.2 * TAU) * 0.10 * exp(-t * 50.0)
		) * exp(-t * 26.0)
		var wave := (body * env_body + click + sub + tin) * 0.90
		_write_s16(pcm, i, int(clampf(wave, -1.0, 1.0) * 23000.0))
	return _wav_from_pcm(pcm, false)


func _make_hold_hihat(pad: int, open_hat: bool) -> AudioStreamWAV:
	## Tilted spatula on HOLD — closed hat (±45°) or open hat / rim (±90°).
	var p := clampf(float(pad), 0.0, 4.0) / 4.0
	var dur := 0.11 if not open_hat else 0.22
	var n := int(MIX_RATE * dur)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = (9100 if open_hat else 7300) + pad * 19
	## Band-ish metal partials — brighter toward the window pad.
	var f_met := lerpf(9200.0, 6200.0, p)
	var decay := 55.0 if not open_hat else 18.0
	var hp := 0.0
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var env := exp(-t * decay)
		if t < 0.0006:
			env *= t / 0.0006
		## Bright noise through a crude high-pass + ringing partials.
		var nse := rng.randf() * 2.0 - 1.0
		hp = lerpf(hp, nse, 0.55)
		var air := (nse - hp) * (0.72 if not open_hat else 0.55)
		var ring := (
			sin(t * f_met * TAU) * 0.22
			+ sin(t * f_met * 1.41 * TAU) * 0.16
			+ sin(t * f_met * 2.17 * TAU) * 0.10
			+ sin(t * lerpf(4800.0, 3200.0, p) * TAU) * 0.12 * exp(-t * 40.0)
		)
		## Open hat: extra sizzle + lower “chick” body; closed: tighter chick.
		var chick := sin(t * lerpf(340.0, 220.0, p) * TAU) * (0.08 if open_hat else 0.14) * exp(-t * 48.0)
		var sizzle := 0.0
		if open_hat:
			sizzle = (rng.randf() * 2.0 - 1.0) * 0.18 * exp(-t * 12.0)
		var wave := (air * 0.85 + ring + chick + sizzle) * env
		_write_s16(pcm, i, int(clampf(wave, -1.0, 1.0) * 22000.0))
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


func _make_debris_bass_pop() -> AudioStreamWAV:
	## Soft bassy thud — stuck crust peeling loose from the steel.
	var n := int(MIX_RATE * 0.07)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	var fund := 72.0 + randf() * 48.0
	var body := 140.0 + randf() * 60.0
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var env := exp(-t * 38.0)
		if t < 0.002:
			env *= t / 0.002
		var thump := sin(t * fund * TAU) * 0.72
		thump += sin(t * body * TAU) * 0.28 * exp(-t * 55.0)
		## Tiny soft noise click so it doesn't read as a pure sine.
		var grit := (randf() * 2.0 - 1.0) * 0.12 * exp(-t * 90.0)
		_write_s16(pcm, i, int(clampf((thump + grit) * env, -1.0, 1.0) * 15000.0))
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


func _make_roomba_drive() -> AudioStreamWAV:
	var n := int(MIX_RATE * 0.34)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	var lp := 0.0
	var phase := 0.0
	var whine_phase := 0.0
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var white := randf() * 2.0 - 1.0
		lp = lp * 0.72 + white * 0.28
		var wobble := sin(t * TAU * 7.0) * 18.0
		phase += (118.0 + wobble) / float(MIX_RATE)
		whine_phase += (520.0 + sin(t * TAU * 11.0) * 42.0) / float(MIX_RATE)
		var motor := sin(phase * TAU) * 0.16 + sin(phase * TAU * 2.0) * 0.07
		var servo := sin(whine_phase * TAU) * 0.18 + sin(whine_phase * TAU * 1.51) * 0.07
		var chatter := sin(t * TAU * 38.0) * 0.045
		var sample := motor + servo + lp * 0.07 + chatter
		var edge := 1.0
		var fade := 0.018
		if t < fade:
			edge = t / fade
		elif t > 0.34 - fade:
			edge = (0.34 - t) / fade
		_write_s16(pcm, i, int(clampf(sample * edge, -1.0, 1.0) * 13500.0))
	return _wav_from_pcm(pcm, true)


func debug_playing_sounds_report(scene_tree: SceneTree = null) -> String:
	## Press 9 — list every playing AudioStreamPlayer / 3D voice + loop flag.
	var tree := scene_tree if scene_tree != null else get_tree()
	var lines: PackedStringArray = []
	var n_playing := 0
	if tree != null and tree.root != null:
		n_playing = _debug_collect_playing_audio(tree.root, lines)
	## Intent flags for continuous beds (catch “flag on but silent” / orphaned loops).
	var beds: PackedStringArray = []
	_debug_append_bed_flag(beds, "sizzle", _sizzle_on, _sizzle_player)
	_debug_append_bed_flag(beds, "hiss", _hiss_on, _hiss_player)
	_debug_append_bed_flag(beds, "spray", _spray_on, _spray_player)
	_debug_append_bed_flag(beds, "shake/scrape", _shake_on, _shake_player)
	_debug_append_bed_flag(beds, "fries_shake", _fries_shake_on, _fries_shake_player)
	_debug_append_bed_flag(beds, "soda", _soda_on, _soda_player)
	_debug_append_bed_flag(beds, "ice", _ice_on, _ice_player)
	_debug_append_bed_flag(beds, "softserve", _softserve_on, _softserve_player)
	_debug_append_bed_flag(beds, "fryer", _fryer_on, _fryer_player)
	_debug_append_bed_flag(beds, "room_tone", _room_tone_on and not _room_tone_muted, _room_tone_player)
	_debug_append_bed_flag(beds, "outdoor_ambience", _outdoor_ambience_on and not _outdoor_ambience_muted, _outdoor_ambience_player)
	_debug_append_bed_flag(beds, "roomba_wawawa", _roomba_wawawa_on, _roomba_wawawa_player)
	_debug_append_bed_flag(beds, "combat_theme", _combat_theme_on, _combat_player)
	var slide_on := _slide_target > 0.01 or (_slide_player != null and _slide_player.playing)
	_debug_append_bed_flag(beds, "burger_slide", slide_on, _slide_player)
	var oil_slide_on := _oil_slide_target > 0.01 or (_oil_slide_player != null and _oil_slide_player.playing)
	_debug_append_bed_flag(beds, "oil_slide", oil_slide_on, _oil_slide_player)
	var roomba_drive_on := _roomba_drive_target > 0.01 or (_roomba_drive_player != null and _roomba_drive_player.playing)
	_debug_append_bed_flag(beds, "roomba_drive", roomba_drive_on, _roomba_drive_player)
	var out := "PLAYING VOICES (%d)\n" % n_playing
	if lines.is_empty():
		out += "  (none)\n"
	else:
		out += "\n".join(lines) + "\n"
	out += "BED FLAGS\n"
	if beds.is_empty():
		out += "  (none active)\n"
	else:
		out += "\n".join(beds) + "\n"
	return out


func _debug_append_bed_flag(beds: PackedStringArray, label: String, want_on: bool, player: AudioStreamPlayer) -> void:
	if not want_on and (player == null or not is_instance_valid(player) or not player.playing):
		return
	var playing := player != null and is_instance_valid(player) and player.playing
	var state := "ON+playing" if want_on and playing else ("ON but silent" if want_on else "playing w/ flag OFF")
	beds.append("  [%s] %s" % [label, state])


func _debug_collect_playing_audio(node: Node, lines: PackedStringArray) -> int:
	var count := 0
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
		var p = node
		if bool(p.playing):
			count += 1
			lines.append("  " + _debug_format_audio_player(p))
	for c in node.get_children():
		count += _debug_collect_playing_audio(c, lines)
	return count


func _debug_format_audio_player(p: Node) -> String:
	var stream: AudioStream = p.get("stream") as AudioStream
	var looping := _debug_stream_is_looping(stream)
	var kind := "GENERATOR" if stream is AudioStreamGenerator else ("LOOP" if looping else "ONESHOT")
	var stream_name := "<null>"
	if stream != null:
		stream_name = stream.resource_path.get_file() if not stream.resource_path.is_empty() \
			else stream.get_class()
	var vol := float(p.get("volume_db"))
	var pitch := float(p.get("pitch_scale"))
	var tpos := 0.0
	if p.has_method("get_playback_position"):
		tpos = float(p.call("get_playback_position"))
	var path := str(p.get_path())
	## Keep path short — show from GameAudio / Radio / root child.
	var short := path
	if path.contains("/GameAudio/"):
		short = "GameAudio/" + path.get_file()
	elif path.length() > 48:
		short = "…" + path.substr(path.length() - 46, 46)
	return "%s | %s | %s | vol=%.1fdB pitch=%.2f t=%.2fs | %s" % [
		str(p.name), kind, stream_name, vol, pitch, tpos, short
	]


func _debug_stream_is_looping(stream: AudioStream) -> bool:
	if stream == null:
		return false
	if stream is AudioStreamGenerator:
		return true
	if stream is AudioStreamWAV:
		return (stream as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED
	if stream is AudioStreamOggVorbis:
		return bool((stream as AudioStreamOggVorbis).loop)
	if stream is AudioStreamMP3:
		return bool((stream as AudioStreamMP3).loop)
	return false


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
