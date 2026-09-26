extends RefCounted

# Clip only at the scraper circle boundary; untouched strokes retain their vertices.
static func interval(a: Vector3, b: Vector3, center: Vector3, radius: float) -> Vector2:
 var origin := Vector2(a.x-center.x,a.z-center.z)
 var direction := Vector2(b.x-a.x,b.z-a.z)
 var length_squared := direction.length_squared()
 if length_squared < 0.00000001:
  return Vector2(0,1) if origin.length_squared() < radius*radius else Vector2(-1,-1)
 var projection := origin.dot(direction)
 var discriminant := projection*projection-length_squared*(origin.length_squared()-radius*radius)
 if discriminant <= 0.0:return Vector2(-1,-1)
 var root := sqrt(discriminant)
 var lo := maxf(0.0,(-projection-root)/length_squared)
 var hi := minf(1.0,(-projection+root)/length_squared)
 return Vector2(lo,hi) if hi>lo else Vector2(-1,-1)

static func touches(segments: PackedVector3Array, center: Vector3, radius: float) -> bool:
 for i in range(0,segments.size()-1,2):
  if interval(segments[i],segments[i+1],center,radius).x>=0:return true
 return false

static func cut(segments: PackedVector3Array, center: Vector3, radius: float) -> Dictionary:
 var kept := PackedVector3Array()
 var removed := PackedVector3Array()
 for i in range(0,segments.size()-1,2):
  var a := segments[i]
  var b := segments[i+1]
  var span := interval(a,b,center,radius)
  if span.x<0:
   kept.append(a);kept.append(b);continue
  var entry := a.lerp(b,span.x)
  var leave := a.lerp(b,span.y)
  if span.x>0.00001:kept.append(a);kept.append(entry)
  removed.append(entry);removed.append(leave)
  if span.y<0.99999:kept.append(leave);kept.append(b)
 return {"kept":kept,"cut":removed}
