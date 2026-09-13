## One persistent music player across the intro, menu, and gameplay loading screen.
extends Node

const MUSIC_PATH := "res://assets/music/burger_time.mp3"
const LOADING_MUSIC_PATH := "res://sounds/considerburger.mp3"
const TARGET_DB := -9.5
var player: AudioStreamPlayer
var _fade_tw: Tween
var mode := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _play_track(path: String, next_mode: String) -> void:
	if is_instance_valid(player) and mode == next_mode and player.playing:
		return
	if is_instance_valid(_fade_tw):
		_fade_tw.kill()
	if not is_instance_valid(player):
		player = AudioStreamPlayer.new()
		player.name = "IntroAndLoadingMusic"
		player.bus = "Master"
		add_child(player)
	var stream := load(path) as AudioStream
	if stream == null:
		push_warning("Music missing: " + path)
		return
	stream = stream.duplicate() as AudioStream
	if stream is AudioStreamMP3: stream.loop = true
	elif stream is AudioStreamOggVorbis: stream.loop = true
	player.stop()
	player.stream = stream
	mode = next_mode
	player.volume_db = TARGET_DB if next_mode == "loading" else -32.0
	player.play()
	_fade_tw = null
	if next_mode != "loading":
		_fade_tw = create_tween()
		_fade_tw.tween_property(player, "volume_db", TARGET_DB, 0.45)

func ensure_playing_on_title() -> void:
	_play_track(MUSIC_PATH, "title")

func play_loading() -> void:
	_play_track(LOADING_MUSIC_PATH, "loading")

func stop_loading() -> void:
	if mode == "loading": stop()

func stop() -> void:
	if is_instance_valid(_fade_tw):
		_fade_tw.kill()
		_fade_tw = null
	if is_instance_valid(player): player.stop()
	mode = ""

func is_playing() -> bool:
	return is_instance_valid(player) and player.playing
