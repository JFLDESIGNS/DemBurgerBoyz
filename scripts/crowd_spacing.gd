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
 var target_z:=float(actor.get_meta("crowd_home_z",desired.z))
 var base_z:=target_z
 for other in actors:
  if not is_instance_valid(other) or other==actor or not other is Node3D or not other.visible: continue
  clearance = _clearance(other)
  var relative: Vector3=other.global_position-before
  if absf(relative.y)>1.2: continue
  if relative.x*direction>=-clearance-.17 and relative.x*direction<clearance+.65 and absf(other.global_position.z-base_z)<clearance:
   var other_moving:=Time.get_ticks_msec()-int(other.get_meta("crowd_tick",-10000))<250
   if other_moving and actor.get_instance_id()<other.get_instance_id(): continue
   target_z=maxf(target_z,other.global_position.z+clearance+.12)
 result.z=move_toward(before.z,target_z,delta*2.5)
 for other in actors:
  if not is_instance_valid(other) or other==actor or not other is Node3D or not other.visible: continue
  clearance = _clearance(other)
  var gap:=Vector2(result.x-other.global_position.x,result.z-other.global_position.z)
  if absf(result.y-other.global_position.y)<1.2 and gap.length()<clearance and gap.length()>.001:
   # Yield forward movement until there is enough lateral room to pass.
   result.x=before.x
 return result

static func _clearance(other: Node3D) -> float:
 if other.has_method("_chonk_fraction"): return .9 + other._chonk_fraction() * .9
 if other.name == "MailCatCourier": return 1.05
 return .68
