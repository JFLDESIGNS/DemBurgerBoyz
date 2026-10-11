extends SceneTree
func _initialize():call_deferred("run")
func run():
 var g=load("res://scripts/game.gd").new()
 g.mp_bootstrap_step("mp_order_history",[[{"number":1,"sale":20,"tip":3,"cost":4.0,"profit":19.0}],1])
 assert(g.order_history_revision==1 and g.order_history.size()==1 and g.order_history[0].profit==19.0,"Late join keeps earlier sales")
 g.mp_bootstrap_step("mp_order_history",[[],0])
 assert(g.order_history.size()==1,"Older bootstrap history cannot erase newer sales")
 g.mp_bootstrap_step("_spend",[50.0])
 assert(g.money==0.0,"Bootstrap must continue rejecting unlisted methods")
 g.free();print("BOOTSTRAP_HISTORY_AUDIT_OK");quit()
