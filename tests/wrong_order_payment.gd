extends SceneTree
func _initialize():call_deferred("run")
func run():
 var c=load("res://scripts/customer.gd").new()
 c.order.assign(["bun_bottom","patty","cheese","bun_top"])
 c.set_meta("serve_commit_hold",true)
 var pay=c.receive_burger(["bun_bottom","patty","bun_top"],1,0,1)
 assert(pay.total==0 and pay.tip==0 and pay.wrong)
 assert(c.get_meta("serve_pending_total")==0 and not c.is_leaving)
 c.set_meta("serve_missing_side",true)
 pay=c.receive_burger(c.order,1,0,1)
 assert(pay.total==0 and pay.tip==0 and not pay.wrong and pay.missing_side)
 assert(not c.is_leaving,"Scoring cannot interrupt the two-bite animation")
 c.free();print("WRONG_ORDER_AND_MISSING_SIDE_PAYMENT_OK");quit()
