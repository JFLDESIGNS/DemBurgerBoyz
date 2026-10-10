extends OmniLight3D
## Short warm counter illumination, separate from the restrained 2D halo.
var elapsed := 0.0
var duration := .5
func _ready() -> void:
	light_color=Color("FFF0C4")
	omni_range=2.0
	omni_attenuation=1.4
	light_specular=.35
	shadow_enabled=true
	stop()
func pulse(at: Vector3, seconds: float) -> void:
	global_position=at
	elapsed=0.0;duration=maxf(.05,seconds)
	light_energy=0.0;show();set_process(true)
func stop() -> void:
	light_energy=0.0;hide();set_process(false)
func _process(delta: float) -> void:
	elapsed+=delta
	var t=clampf(elapsed/duration,0,1)
	if t>=1.0:stop();return
	# Bright pop, warm settle, then a smooth fade as the burger launches.
	if t<.16:light_energy=lerpf(0,3.2,smoothstep(0,.16,t))
	elif t<.40:light_energy=lerpf(3.2,1.6,smoothstep(.16,.40,t))
	else:light_energy=1.6*(1.0-smoothstep(.40,1.0,t))
