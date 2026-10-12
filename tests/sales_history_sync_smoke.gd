extends SceneTree
func _initialize():
 var sender=load("res://scripts/sales_history_sync.gd").new()
 var receiver=load("res://scripts/sales_history_sync.gd").new()
 var photo:=Crypto.new().generate_random_bytes(180000)
 var rows=[{"number":1,"photo":photo,"profit":25}]
 sender.queue(rows,1,0)
 assert(sender.pending.size()>4)
 var result:Dictionary={}
 var packets: Array=sender.pending.duplicate();packets.reverse()
 for packet in packets:
  assert(packet.data.size()<=16000)
  var decoded:Dictionary=receiver.accept(packet.serial,packet.part,packet.count,packet.data)
  if not decoded.is_empty():result=decoded
 assert(result.rows[0].photo==photo and result.revision==1)
 sender.pending.clear();sender.queue(rows,1,0)
 assert(sender.pending.is_empty(),"Unchanged photo history must not retransmit")
 rows.append({"number":2,"profit":30})
 sender.queue(rows,2,0)
 assert(sender.pending.size()==1,"New sale must not resend old photograph")
 var packet:Dictionary=sender.pending[0]
 result=receiver.accept(packet.serial,packet.part,packet.count,packet.data)
 assert(result.rows.size()==1 and result.rows[0].number==2 and result.ids==[1,2])
 print("SALES_HISTORY_CHUNKS_OK");quit()
