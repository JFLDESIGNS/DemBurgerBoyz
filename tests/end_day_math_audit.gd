extends SceneTree
func _initialize():call_deferred("run")
func run():
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/audit_economy_fixture.gd"));root.add_child(g);current_scene=g
 g.playing=true;g.money=1000.0;g.shift_food_sales=0;g.shift_tips=0;g.shift_ingredient_cost=0;g.shift_restock_spend=0
 g.supply_stock["bacon"]=8
 assert(g._try_use_supply("bacon",2))
 assert(is_equal_approx(g.shift_ingredient_cost,4.0) and is_equal_approx(g.money,1000.0),"Ingredient usage must not charge wallet twice")
 g._credit_ticket_payout({"base":20,"tip":3},23)
 assert(is_equal_approx(g.money,1023.0) and g.shift_food_sales==20 and g.shift_tips==3)
 g._cut_collector_cut_done=false;g.truck_bought_out=false;g.tutorial_mode=false
 g._apply_cut_collector_payout()
 assert(g.last_day_cut==10 and g.money==1013,"Boss takes half food sales, excludes tips")
 g._apply_cut_collector_payout();assert(g.money==1013,"Day close must not charge cut twice")
 assert(g._format_day_cut_recap().contains("Net food profit: $9.00"))
 for id in g.SUPPLY_IDS:g.supply_stock[id]=0
 g.supply_stock["bacon"]=2;g.supply_fresh["bacon"]=.01
 g._update_supply_freshness(.02)
 assert(g.supply_stock.bacon==1 and g.shift_ingredient_cost==6 and g.money==1013,"Spoilage counts as cost, without second cash charge")
 assert(g._format_day_cut_recap().contains("Net food profit: $7.00"))
 g.shift_restock_spend=200
 assert(g._format_day_cut_recap().contains("Net food profit: $7.00"),"Restocks must not double-count consumed stock")
 g._cut_collector_cut_done=false;g.truck_bought_out=true;g._apply_cut_collector_payout()
 assert(g.last_day_cut==0 and g.money==1013)
 g._cut_collector_cut_done=false;g.truck_bought_out=false;g.tutorial_mode=true;g._apply_cut_collector_payout()
 assert(g.last_day_cut==0 and g.money==1013)
 g.bank_savings=100;g.bank_savings_rate_pct=.5;g.bank_loan=80;g.bank_loan_rate_pct=2
 g._apply_bank_day_interest()
 assert(is_equal_approx(g.bank_savings,100.5) and is_equal_approx(g.bank_loan,81.6) and g.money==1013)
 var customer=load("res://scripts/mobile_ticket_owner.gd").new();g.add_child(customer)
 customer.order.assign(["bun_bottom","patty","bun_top","soda_cola"])
 customer.set_meta("profit_built",["bun_bottom","patty","bacon","bun_top"])
 var expected:float=2.75+.45*8*.06/.65
 assert(is_equal_approx(g._order_food_cost(customer),expected),"Actual extras and syrup costs included")
 g._credit_ticket_payout({"base":99,"tip":2},12)
 assert(g.shift_food_sales==30 and g.shift_tips==5,"Normalize inconsistent payout breakdown")
 print("END_DAY_MATH_AUDIT_OK: usage, spoilage, revenue, tips, restocks, cut idempotence, buyout, tutorial, interest, extras, syrup")
 quit()
