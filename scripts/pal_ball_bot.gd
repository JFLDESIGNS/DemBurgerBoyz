extends RefCounted
static func choose(me: Dictionary, rivals: Array, radius: float) -> Dictionary:
 var pos:Vector2=me.position
 var velocity:Vector2=me.velocity
 var opponent:Dictionary={}
 var nearest:=INF
 for other in rivals:
  if not other.alive:continue
  var distance:float=pos.distance_to(other.position)
  if distance<nearest:nearest=distance;opponent=other
 var future:=pos+velocity*(.3+velocity.length()/14.0)
 var margin:=radius-maxf(absf(future.x),absf(future.y))
 if margin<.9:
  var brake:=(-velocity*1.5-pos.normalized()*3.0).limit_length(1.0)
  return {"direction":brake,"burst":false}
 if opponent.is_empty():return {"direction":(-pos-velocity).limit_length(1.0),"burst":false}
 var enemy:Vector2=opponent.position
 var target:Vector2=enemy+opponent.velocity*.28
 # Approach from the middle so the collision sends the rival toward the edge.
 if pos.length()>enemy.length()+.4:target-=enemy.normalized()*.9
 target=target.clamp(Vector2.ONE*(-radius+1.0),Vector2.ONE*(radius-1.0))
 var offset:=target-pos
 var desired:=offset.normalized()*minf(4.8,offset.length()*3.5)
 var direction:Vector2=(desired-velocity).limit_length(1.0)
 var landing:Vector2=pos+velocity*.35+direction*.45
 var enemy_landing:Vector2=enemy+opponent.velocity*.45
 var safe:=radius-maxf(absf(landing.x),absf(landing.y))>1.0
 var burst:bool=float(me.cooldown)<=0 and safe and landing.distance_to(enemy_landing)<1.8 and nearest<2.5
 return {"direction":direction,"burst":burst}
