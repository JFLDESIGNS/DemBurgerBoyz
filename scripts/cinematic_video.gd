## Silent, aspect-preserving video. Music belongs to the persistent audio controller.
extends Control
@export_file("*.ogv") var video_path := ""
@export var looping := false
signal finished
var video: VideoStreamPlayer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := ColorRect.new()
	background.color = Color.BLACK
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	video = VideoStreamPlayer.new()
	video.name = "Video"
	video.expand = true
	video.volume_db = -80.0
	video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	video.stream = load(video_path) as VideoStream
	add_child(video)
	video.finished.connect(_on_finished)
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	if not is_instance_valid(video): return
	var fitted := Vector2(minf(size.x, size.y * 16.0 / 9.0), minf(size.y, size.x * 9.0 / 16.0))
	video.size = fitted
	video.position = (size - fitted) * 0.5

func prewarm() -> void:
	if not is_instance_valid(video) or video.stream == null: return
	video.play()
	# Decode the first frames while the intro/menu covers this player.
	await get_tree().create_timer(0.3).timeout
	if not is_visible_in_tree(): video.paused = true

func play() -> void:
	if is_instance_valid(video) and video.stream != null:
		if video.is_playing():
			video.paused = false
		else:
			video.paused = false
			video.play()

func hold_frame() -> void:
	if is_instance_valid(video):
		video.paused = true

func restart() -> void:
	if is_instance_valid(video) and video.stream != null:
		video.stop()
		video.paused = false
		video.play()

func stop() -> void:
	if is_instance_valid(video):
		video.stop()
		video.paused = false

func _on_finished() -> void:
	if looping and visible and is_visible_in_tree():
		video.play()
	else:
		finished.emit()
