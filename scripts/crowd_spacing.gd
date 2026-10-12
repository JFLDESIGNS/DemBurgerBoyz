extends RefCounted
# Deterministic local steering. Only the host drives world actors; existing pose RPCs mirror it.
static func steer(actor: Node3D, before: Vector3, desired: Vector3, actors: Array, delta: float) -> Vector3:
 var direction:=signf(desired.x-before.x)
 if absf(desired.x-before.x)<.0001: return desired
 actor.set_meta("crowd_direction",direction)
 actor.set_meta("crowd_tick",Time.get_ticks_msec())
 if not actor.has_meta("crowd_home_z"): actor.set_meta("crowd_home_z",desired.z)
 var result:=desired
 var clearance:=.68
 var street := bool(actor.get_meta("street_spacing",false))
 var target_z:=float(actor.get_meta("crowd_home_z",desired.z))
 var base_z:=target_z
 for other in actors:
  if not is_instance_valid(other) or other==actor or not other is Node3D or not other.visible: continue
  if int(actor.get_meta("street_pair",0)) != 0 and int(actor.get_meta("street_pair",0)) == int(other.get_meta("street_pair",0)): continue
  clearance = maxf(_clearance(other),1.15 if street else 0.0)
  var relative: Vector3=other.global_position-before
  if absf(relative.y)>1.2: continue
  if relative.x*direction>=-clearance-.17 and relative.x*direction<clearance+.65 and absf(other.global_position.z-base_z)<clearance:
   if street and bool(other.get_meta("street_spacing",false)) and relative.x*direction > 0.0 and absf(relative.z)<.85:
    # Follow the walker ahead instead of squeezing alongside them.
    var available := maxf(0.0,relative.x*direction-1.15)
    result.x = before.x + direction * minf(absf(result.x-before.x),available)
    continue
   var other_moving:=Time.get_ticks_msec()-int(other.get_meta("crowd_tick",-10000))<250
   if other_moving and not other.has_method("_chonk_fraction") and actor.get_instance_id()<other.get_instance_id(): continue
   target_z=maxf(target_z,other.global_position.z+clearance+.12)
 result.z=move_toward(before.z,target_z,delta*2.5)
 for other in actors:
  if not is_instance_valid(other) or other==actor or not other is Node3D or not other.visible: continue
  if int(actor.get_meta("street_pair",0)) != 0 and int(actor.get_meta("street_pair",0)) == int(other.get_meta("street_pair",0)): continue
  clearance = maxf(_clearance(other),1.15 if street else 0.0)
  var gap:=Vector2(result.x-other.global_position.x,result.z-other.global_position.z)
  if absf(result.y-other.global_position.y)<1.2 and gap.length()<clearance and gap.length()>.001:
   # Yield forward movement until there is enough lateral room to pass.
   result.x=before.x
 return result

static func _clearance(other: Node3D) -> float:
 if other.has_method("_chonk_fraction"): return .9 + other._chonk_fraction() * .9
 if other.name == "MailCatCourier": return 1.05
 return .68
