extends Node
## Local animation-contact sounds: no audio RPCs or per-frame allocations.
static var step_stream: AudioStreamWAV
static var cartoon_stream: AudioStreamWAV
var actor: Node3D
var audio: AudioStreamPlayer3D
var last_position := Vector3.ZERO
var last_contact := -1
var last_animation := ""
var cooldown := 0.0

static func make_step(cartoon: bool) -> AudioStreamWAV:
 var stream := AudioStreamWAV.new()
 stream.format = AudioStreamWAV.FORMAT_16_BITS
 stream.mix_rate = 16000
 var data := PackedByteArray()
 data.resize(1920)
 var rng := RandomNumberGenerator.new()
 rng.seed = 71
 for i in range(960):
  var t := float(i)/16000.0
  var envelope := exp(-t*65.0)*minf(t*1000.0,1.0)
  var tone := sin(TAU*(310.0 if cartoon else 115.0)*t-1400.0*t*t)
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
 var distance := at.distance_to(last_position)
 last_position = at
 if not actor.is_visible_in_tree() or bool(actor.get_meta("footstep_sliding",false)):
  last_contact = -1
  return
 var player = actor.get("_anim_player")
 if not is_instance_valid(player) or not player.is_playing(): return
 var animation := str(player.current_animation)
 var length := float(player.current_animation_length)
 if length <= 0 or (not animation.to_lower().contains("walk") and not animation.to_lower().contains("run")):
  last_contact = -1
  return
 var contact := int(floor(fposmod(float(player.current_animation_position)/length,1.0)*2.0))
 var changed := contact != last_contact and animation == last_animation and last_contact >= 0
 last_animation = animation
 last_contact = contact
 # Ignore teleports, snapshots and stationary walk loops.
 if not changed or distance < .00005 or distance > 1.0 or cooldown > 0: return
 cooldown = .12
 var courier := bool(actor.get_meta("delivery_driver",false))
 audio.stream = cartoon_stream if courier else step_stream
 audio.volume_db = -9.0 if courier else (-30.0 if bool(actor.get("is_street_pedestrian")) else -20.0)
 audio.pitch_scale = 1.07 if contact == 0 else .96
 audio.play()

func play_skid() -> void:
 audio.stream = preload("res://sounds/vehicles/mail_truck_tire_screech.mp3")
 audio.volume_db = -17.0
 audio.pitch_scale = 1.65
 audio.play()
 # One short cartoon squeak; don't play a whole tire recording at the counter.
 get_tree().create_timer(.22).timeout.connect(func():
  if is_instance_valid(audio): audio.stop())
