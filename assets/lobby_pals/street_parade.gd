## Reusable, self-contained street parade. No physics or Blender runtime required.
extends Node3D

signal parade_started(reason: String)
signal parade_finished(reason: String)

@export_range(2.0, 60.0) var duration: float = 20.0 / 1.5
@export var start_x: float = -11.0
@export var finish_x: float = 11.0
@export var spacing: float = 1.55
@export var color_tint := Color(0.90, 0.90, 0.88, 1.0)

var active := false
var elapsed := 0.0
var event_reason := ""
var _last_pose := -1
var _players: Array[AnimationPlayer] = []
var _clips: Array[StringName] = []
var _queued_reason := ""

func _ready() -> void:
	var actors := $Actors
	for i in actors.get_child_count():
		var actor := actors.get_child(i) as Node3D
		actor.position.x = (i - 1) * spacing
		for node in actor.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			# Baked mesh bounds must cover every kicked foot, glove and sauce spurt.
			mesh.custom_aabb = AABB(Vector3(-1.25, -0.15, -1.0), Vector3(2.5, 2.65, 2.0))
			for surface in mesh.mesh.get_surface_count():
				var original := mesh.get_active_material(surface) as StandardMaterial3D
				if original == null:
					continue
				var material := original.duplicate() as StandardMaterial3D
				material.albedo_color *= color_tint
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
				mesh.set_surface_override_material(surface, material)
		var found := actor.find_children("*", "AnimationPlayer", true, false)
		if found.is_empty():
			push_error("Parade actor has no MarchLoop: " + actor.name)
			continue
		var player := found[0] as AnimationPlayer
		var clip: StringName = &"MarchLoop"
		if not player.has_animation(clip):
			for candidate in player.get_animation_list():
				if String(candidate).ends_with("MarchLoop"):
					clip = candidate
		if not player.has_animation(clip):
			push_error("Parade actor is missing MarchLoop: " + actor.name)
			continue
		player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		_players.append(player)
		_clips.append(clip)
	stop_parade()

## An already-running pass is not restarted by repeated network updates.
## An end-of-day pass queues once if a challenge pass is still finishing.
func start_parade(reason: String = "challenge") -> bool:
	if active:
		if reason == "end_of_day" and event_reason != reason:
			_queued_reason = reason
		return false
	if _players.size() != 3:
		return false
	event_reason = reason
	elapsed = 0.0
	_last_pose = -1
	active = true
	visible = true
	position.x = start_x
	for i in _players.size():
		_players[i].play(_clips[i])
		_players[i].pause()
	_update_pose()
	set_process(true)
	parade_started.emit(reason)
	return true

func stop_parade() -> void:
	active = false
	visible = false
	elapsed = 0.0
	_last_pose = -1
	_queued_reason = ""
	for player in _players:
		player.stop()
	set_process(false)

func _process(delta: float) -> void:
	advance_parade(delta)

## Public deterministic tick also used by the asset smoke test.
func advance_parade(delta: float) -> void:
	if not active:
		return
	elapsed = minf(elapsed + maxf(delta, 0.0), duration)
	position.x = lerpf(start_x, finish_x, elapsed / maxf(duration, 0.001))
	_update_pose()
	if elapsed >= duration:
		var finished_reason := event_reason
		var next_reason := _queued_reason
		stop_parade()
		parade_finished.emit(finished_reason)
		if not next_reason.is_empty():
			start_parade(next_reason)

func _update_pose() -> void:
	var pose := int(floor(elapsed * 18.0)) % 48
	if pose == _last_pose:
		return
	_last_pose = pose
	for player in _players:
		player.seek(float(pose) / 12.0, true)
