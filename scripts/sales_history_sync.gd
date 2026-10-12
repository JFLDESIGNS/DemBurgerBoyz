extends RefCounted
const CHUNK_BYTES := 16000
var sent: Dictionary = {}
var incoming: Dictionary = {}
var pending: Array = []
var serial := 0
var next_send := 0
func queue(rows: Array, revision: int, peer: int) -> void:
 var known: Dictionary = sent.get(peer,{})
 var changes: Array = []
 var ids: Array = []
 for row in rows:
  var id:=int(row.number)
  ids.append(id)
  var stamp:=hash(row)
  if peer>0 or int(known.get(id,-1))!=stamp:
   changes.append(row)
   known[id]=stamp
 sent[peer]=known
 if changes.is_empty():return
 serial+=1
 var packet:=var_to_bytes({"revision":revision,"rows":changes,"ids":ids}).compress(FileAccess.COMPRESSION_DEFLATE)
 var count:=ceili(float(packet.size())/CHUNK_BYTES)
 for part in count:
  pending.append({"peer":peer,"serial":serial,"part":part,"count":count,"data":packet.slice(part*CHUNK_BYTES,mini(packet.size(),(part+1)*CHUNK_BYTES))})
func accept(serial_id: int, part: int, count: int, data: PackedByteArray) -> Dictionary:
 if count<1 or count>2048 or part<0 or part>=count or data.size()>CHUNK_BYTES:return {}
 var now:=Time.get_ticks_msec()
 for key in incoming.keys():
  if now-int(incoming[key].time)>60000:incoming.erase(key)
 if not incoming.has(serial_id):incoming[serial_id]={"count":count,"parts":{},"time":now}
 var transfer:Dictionary=incoming[serial_id]
 if int(transfer.count)!=count:return {}
 transfer.parts[part]=data
 if transfer.parts.size()!=count:return {}
 var packed:=PackedByteArray()
 for i in count:packed.append_array(transfer.parts[i])
 incoming.erase(serial_id)
 var result=bytes_to_var(packed.decompress_dynamic(33554432,FileAccess.COMPRESSION_DEFLATE))
 return result if result is Dictionary else {}
