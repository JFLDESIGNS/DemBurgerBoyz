extends "res://scripts/game.gd"
var advance_delivery := false
var saw_flight := false
var taps_received := 0
var highest_meows := 0
func _ready() -> void: pass
func _physics_process(_delta: float) -> void: pass
func _process(delta: float) -> void:
	if not advance_delivery: return
	if is_instance_valid(mail_delivery_truck): highest_meows=maxi(highest_meows,mail_delivery_truck.meow_count)
	for fx in supply_delivery_fx:
		if fx.get("kind")=="machine" and fx.mesh.visible:saw_flight=true
	_update_supply_orders(delta*5.0)
func _flash(_text:String,_color:Color=Color.WHITE,_duration:float=1.8)->void:pass
func _refresh_phone_ui()->void:pass
func _update_hud()->void:pass
func _refresh_ingredient_stock_bars(_id:String="",_refresh_fridge:bool=true)->void:pass
func _refresh_ready_fries_visuals()->void:pass
func _refresh_gold_spatula_finish()->void:pass
func _flash_grill_tap_pad(_at:Vector3)->void:pass
func _spawn_spatula_tap_ring(_at:Vector3)->void:pass
func _sfx_click()->void:pass
func _register_grill_dance_tap(at:Vector3,roll:float)->void:
	taps_received+=1
	super._register_grill_dance_tap(at,roll)
