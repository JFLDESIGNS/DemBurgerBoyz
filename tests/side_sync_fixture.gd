extends "res://tests/kitchen_network_fixture.gd"
var served:Array=[]
var side_visuals:Array=[]
func _complete_fries_only_serve(customer:Node3D=null)->void:served.append(["fries_only",_customer_net_id(customer)])
func _highlight_tickets()->void:pass
func _refresh_ticket_checkmarks()->void:pass
func _mp_broadcast_economy()->void:pass
func _mp_broadcast_customers()->void:pass
func _begin_soda_only_serve(customer:Node3D,peer:int=0,held:bool=false)->void:
 served.append(["soda",_customer_net_id(customer),peer,held]);customer.set_meta("serve_in_progress",true)
func _begin_early_drink_hand(customer:Node3D,flavor:String,remote:Node3D=null)->void:
 served.append([flavor,_customer_net_id(customer)]);_mark_customer_soda_handed(customer,true)
 if is_instance_valid(remote):remote.queue_free()
func _mp_ensure_remote_cup(peer:int)->Node3D:
 var cup=Node3D.new();add_child(cup);_mp_remote_cups[peer]=cup;return cup
func _mp_apply_remote_cup_fill(cup:Node3D,flavor:String,_fill:float,_ice:float,_fizz:float,_pouring:bool=false)->void:cup.set_meta("flavor",flavor)
func _start_side_food_3d(customer:Node3D,kind:String,origin:Vector3,done:Callable,flavor:String="cola",delay:float=0.0,replicated:bool=false)->void:
 side_visuals.append(kind)
 if customer.order==["fries"] and not replicated:customer.is_waiting=false
 if mp_enabled and get_node("/root/NetManager").is_host() and not replicated:mp_side_food_visual.rpc(_customer_net_id(customer),kind,origin,flavor,delay)
 done.call()
func _clear_local_held_cup_after_remote_hand()->void:
 if is_instance_valid(cup_root):cup_root.queue_free()
 cup_root=null;cup_held=false

