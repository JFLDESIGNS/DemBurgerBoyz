extends "res://tests/side_sync_fixture.gd"
func _mp_ensure_remote_icecream(peer: int) -> Node3D:
 if _mp_remote_icecreams.has(peer): return _mp_remote_icecreams[peer]
 var cone=Node3D.new();add_child(cone);_mp_remote_icecreams[peer]=cone;return cone
func _mp_apply_remote_icecream_fill(cone:Node3D,fill:float,pouring:bool)->void:
 cone.set_meta("fill",fill);cone.set_meta("pouring",pouring)
func _mp_set_remote_icecream_stream(_cone:Node3D,_pouring:bool)->void:pass
func _mp_ensure_remote_fries(peer:int)->Node3D:
 if _mp_remote_fries.has(peer):return _mp_remote_fries[peer]
 var fries=Node3D.new();add_child(fries);_mp_remote_fries[peer]=fries;return fries
func _clear_local_held_icecream_after_remote_hand()->void:
 if is_instance_valid(icecream_cone_root):icecream_cone_root.queue_free()
 icecream_cone_root=null;icecream_cone_held=false
func _complete_synced_icecream_hand(nid:int)->void:
 served.append(["icecream",nid]);_mark_customer_icecream_handed(_customer_by_net_id(nid),true)
