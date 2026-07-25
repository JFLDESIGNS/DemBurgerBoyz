## Starts title jazz halfway through the Godot boot splash, fading volume in over 1.5s.
extends Node

const MUSIC_PATH := "res://assets/music/burger_time.mp3"
## Matches project boot_splash/minimum_display_time (2100 ms) — fire at halfway.
const START_AFTER_SEC := 1.05
const FADE_SEC := 1.5
const TARGET_DB := -9.5

var player: AudioStreamPlayer = null
var _fade_tw: Tween = null
var _started: bool = false


func _ready() -> void:
	get_tree().create_timer(START_AFTER_SEC).timeout.connect(_begin_fade_in)


func _begin_fade_in() -> void:
	if _started:
		return
	_started = true
	var stream := load(MUSIC_PATH)
	if stream == null:
		push_warning("Intro boot jazz missing: %s" % MUSIC_PATH)
		return
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	player = AudioStreamPlayer.new()
	player.name = "IntroBootJazz"
	player.bus = "Master"
	player.stream = stream
	player.volume_db = -80.0
	add_child(player)
	player.play()
	if _fade_tw != null and is_instance_valid(_fade_tw):
		_fade_tw.kill()
	_fade_tw = create_tween()
	_fade_tw.tween_property(player, "volume_db", TARGET_DB, FADE_SEC)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func ensure_playing_on_title() -> void:
	## Main scene title screen — keep jazz going if splash already started it.
	if player != null and is_instance_valid(player):
		if not player.playing:
			player.play()
		return
	if not _started:
		_begin_fade_in()


func stop() -> void:
	if _fade_tw != null and is_instance_valid(_fade_tw):
		_fade_tw.kill()
		_fade_tw = null
	if player != null and is_instance_valid(player) and player.playing:
		player.stop()


func is_playing() -> bool:
	return player != null and is_instance_valid(player) and player.playing
