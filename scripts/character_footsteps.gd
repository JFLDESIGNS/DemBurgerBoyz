extends Node
## Local animation-contact sounds: no audio RPCs or per-frame allocations.
static var step_stream: AudioStreamWAV
static var cartoon_stream: AudioStreamWAV
const COURIER_RUN = preload("res://sounds/courier/cartoon_running_qubodup.mp3")
var actor: Node3D
var audio: AudioStreamPlayer3D
var last_position := Vector3.ZERO
var cooldown := 0.0
var stride_distance := 0.0
var step_count := 0
var point_voice: AudioStreamPlayer3D
var skid_audio: AudioStreamPlayer3D

static func make_step(cartoon: bool) -> AudioStreamWAV:
 var stream := AudioStreamWAV.new()
 stream.format = AudioStreamWAV.FORMAT_16_BITS
 stream.mix_rate = 16000
 var data := PackedByteArray()
 data.resize(3200)
 var rng := RandomNumberGenerator.new()
 rng.seed = 71
 for i in range(1600):
  var t := float(i)/16000.0
  var envelope := exp(-t*42.0)*minf(t*1000.0,1.0)
  var tone := sin(TAU*(310.0 if cartoon else 180.0)*t-1400.0*t*t)
  var sample := (tone*.65+rng.randf_range(-.22,.22))*envelope
  data.encode_s16(i*2, int(clampf(sample,-1,1)*20000))
 stream.data = data
 return stream

func _ready() -> void:
 name = "CharacterFootsteps"
 actor = get_parent() as Node3D
 last_position = actor.global_position
 if step_stream == null:
  step_stream = make_step(false)
  cartoon_stream = make_step(true)
 audio = AudioStreamPlayer3D.new()
 audio.bus = "SFX"
 audio.unit_size = 3.0
 audio.max_distance = 22.0
 add_child(audio)

func _process(delta: float) -> void:
 cooldown = maxf(0,cooldown-delta)
 var at := actor.global_position
 var distance := Vector2(at.x-last_position.x,at.z-last_position.z).length()
 last_position = at
 _update_point_voice()
 if bool(actor.get_meta("delivery_driver",false)) or bool(actor.get_meta("recruited_running",false)) or audio.stream == COURIER_RUN:
  var recruited := bool(actor.get_meta("recruited_running",false))
  var running := actor.is_visible_in_tree() and not bool(actor.get_meta("footstep_sliding",false)) and (bool(actor.get_meta("courier_running",false)) or recruited)
  if running:
   if audio.stream != COURIER_RUN or not audio.playing:
    audio.stream=COURIER_RUN;audio.volume_db=-19 if recruited else -10;audio.pitch_scale=1.15;audio.play()
  elif audio.stream == COURIER_RUN:
   audio.stop()
  return
 if not actor.is_visible_in_tree() or bool(actor.get_meta("footstep_sliding",false)):
  stride_distance = 0.0
  return
 # Distance travelled is reliable for local tweens, manual animation and replicated poses.
 # Animation half-cycle sampling used to miss steps whenever movement arrived on another frame.
 if distance > 1.0:
  stride_distance=0.0
  return
 var horizontal := distance
 if horizontal < .00005: return
 stride_distance += horizontal
 var player = actor.get("_anim_player")
 var running := is_instance_valid(player) and str(player.current_animation).to_lower().contains("run")
 var stride := .62 if running else .48
 if stride_distance < stride or cooldown > 0.0: return
 stride_distance=fmod(stride_distance,stride)
 cooldown=.16 if running else .24
 step_count+=1
 audio.stream=cartoon_stream if running else step_stream
 # Footsteps are foreground feedback even when the visible sidewalk is far from the camera.
 audio.attenuation_model=AudioStreamPlayer3D.ATTENUATION_DISABLED
 audio.max_distance=0.0
 audio.attenuation_filter_db=0.0
 audio.volume_db=-12.0 if bool(actor.get("is_street_pedestrian")) else -7.0
 audio.pitch_scale=1.1 if step_count%2==0 else .98
 audio.play()

func play_skid(duration: float = .75) -> void:
 if not is_instance_valid(skid_audio):
  skid_audio = AudioStreamPlayer3D.new()
  skid_audio.bus = "SFX"
  skid_audio.unit_size = 3.0
  skid_audio.max_distance = 22.0
  skid_audio.stream = preload("res://sounds/vehicles/mail_truck_tire_screech.mp3")
  skid_audio.volume_db = -9.0
  skid_audio.pitch_scale = 1.35
  add_child(skid_audio)
 audio.stop()
 skid_audio.play()
 # A separate player keeps the skid timeout from cutting off returning footsteps.
 get_tree().create_timer(duration).timeout.connect(stop_skid)

func stop_skid() -> void:
 if is_instance_valid(skid_audio): skid_audio.stop()

func _update_point_voice() -> void:
 var player = actor.get("_anim_player")
 var pointing: bool = actor.is_visible_in_tree() and is_instance_valid(player) and player.is_playing() and str(player.current_animation).ends_with("Point_Finger_Yell")
 if not pointing:
  if is_instance_valid(point_voice): point_voice.stop()
  return
 if not is_instance_valid(point_voice):
  point_voice = AudioStreamPlayer3D.new()
  point_voice.bus = "SFX"
  point_voice.unit_size = 4.0
  point_voice.volume_db = -9.0
  point_voice.pitch_scale = 1.28
  add_child(point_voice)
 if not point_voice.playing:
  point_voice.stream = preload("res://scripts/customer_voice.gd").stream(actor.get_customer_voice(),false)
  point_voice.play()
