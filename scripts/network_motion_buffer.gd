extends RefCounted
## Source-time playback keeps packet jitter from changing animation speed.
var frames: Array = []
var delay_ms: float = 220.0
var clock_offset: float = INF
var cursor: float = -INF
var last_sample_ms: float = -1.0

func push(source_ms: float, received_ms: float, value: Dictionary) -> void:
 if not frames.is_empty() and source_ms <= float(frames.back().time): return
 clock_offset = minf(clock_offset, received_ms-source_ms)
 frames.append({"time":source_ms,"value":value.duplicate(true)})
 while frames.size()>32: frames.pop_front()

func sample(now_ms: float) -> Dictionary:
 if frames.is_empty(): return {}
 var target=minf(now_ms-clock_offset-delay_ms,float(frames.back().time))
 if last_sample_ms<0.0: cursor=target
 else: cursor=maxf(cursor,minf(target,cursor+maxf(0.0,now_ms-last_sample_ms)*1.10))
 last_sample_ms=now_ms
 while frames.size()>2 and float(frames[1].time)<=cursor: frames.pop_front()
 var a: Dictionary=frames[0]
 var b: Dictionary=frames[1] if frames.size()>1 else a
 var weight=clampf((cursor-float(a.time))/maxf(1.0,float(b.time)-float(a.time)),0.0,1.0)
 return {"from":a.value,"to":b.value,"weight":weight}
