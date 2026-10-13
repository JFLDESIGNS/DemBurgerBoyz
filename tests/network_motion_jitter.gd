extends SceneTree
func _initialize():call_deferred("run")
func run():
 create_timer(15).timeout.connect(func():quit(1))
 var buffer=load("res://scripts/network_motion_buffer.gd").new()
 var packets:Array=[]
 for i in 100:
  if i%17==10:continue
  var jitter=[0,40,80,15,65][i%5]
  packets.append({"arrival":i*100+200+jitter,"source":i*100})
 var index=0
 var previous=-1.0
 var max_step=0.0
 for frame in 600:
  var now=frame*1000.0/60.0
  while index<packets.size() and packets[index].arrival<=now:
   var packet=packets[index]
   buffer.push(packet.source,packet.arrival,{"x":float(packet.source)*.001})
   index+=1
  var sample:Dictionary=buffer.sample(now)
  if sample.is_empty():continue
  var x=lerpf(sample["from"].x,sample["to"].x,sample.weight)
  if now>1000 and previous>=0:
   assert(x>=previous,"Buffered motion rewound")
   max_step=maxf(max_step,x-previous)
   assert(x-previous<.035,"Packet arrival produced a visible position jump")
  previous=x
 assert(max_step>.015)
 # Stale/out-of-order packets cannot replace the current trajectory.
 var count=buffer.frames.size()
 buffer.push(100,20000,{"x":-100.0})
 assert(buffer.frames.size()==count)
 var mobile=load("res://scripts/grubbah.gd").new()
 mobile.state={"number":1,"phase":"wrapping"}
 mobile.age=.9
 var presentation:Dictionary=mobile.packing_phase(0.0)
 mobile.last_phase=presentation.phase
 assert(presentation.age==0.0,"Delayed snapshot skipped the beginning of wrapping")
 mobile.state.phase="bagging"
 for i in 30:
  presentation=mobile.packing_phase(1.0/60.0);mobile.last_phase=presentation.phase
  assert(presentation.phase=="wrapping")
 for i in 50:
  presentation=mobile.packing_phase(1.0/60.0);mobile.last_phase=presentation.phase
 assert(presentation.phase=="bagging")
 mobile.state.phase="sealed"
 presentation=mobile.packing_phase(1.0/60.0);mobile.last_phase=presentation.phase
 assert(presentation.phase=="bagging","Late snapshots interrupted the burger flight")
 mobile.free()
 print("NETWORK_MOTION_JITTER_OK 400ms RTT, 80ms jitter, periodic loss; max frame step=",max_step)
 quit()
