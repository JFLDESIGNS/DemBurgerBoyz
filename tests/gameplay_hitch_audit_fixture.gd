extends "res://scripts/game.gd"
# Keep preparation from auto-serving before the measured action starts.
func _try_auto_serve() -> void: pass
func _try_auto_hand_finished_soda() -> void: pass
func _try_auto_hand_finished_icecream() -> void: pass
func _auto_serve_ready_fries() -> void: pass

func _process_gameplay(delta: float) -> void:
	var began := Time.get_ticks_usec()
	super._process_gameplay(delta)
	var elapsed := Time.get_ticks_usec()-began
	if elapsed > 10000: print("GAMEPLAY_PROCESS_COST_MS ",elapsed/1000.0)

func _flash(text: String, color: Color, hold_sec: float = 1.1) -> void:
	if OS.get_environment("HITCH_AUDIT_NO_FLASH") != "1" and burger_probe_mode != "no_feedback": super._flash(text,color,hold_sec)

var burger_probe_mode := OS.get_environment("HITCH_FIRST_SERVE_MODE")
func _make_review_burger_snapshot(index: int) -> Texture2D:
	if burger_probe_mode in ["no_photo", "no_records"]: return null
	return super._make_review_burger_snapshot(index)

func _render_review_burger_snapshot(index: int) -> Texture2D:
	var began := Time.get_ticks_usec()
	if burger_probe_mode == "no_records": return null
	var result := super._render_review_burger_snapshot(index)
	print("BURGER_PHOTO_BUILD ms=", (Time.get_ticks_usec()-began)/1000.0, " frame=", Engine.get_process_frames())
	return result

func _commit_social_review(stars: float, kind: String, tip: int = 0, station_index: int = -1, customer: Node3D = null, cached_pic: Texture2D = null) -> void:
	if burger_probe_mode in ["no_review", "no_records"]: return
	var began := Time.get_ticks_usec()
	super._commit_social_review(stars, kind, tip, station_index, customer, cached_pic)
	print("BURGER_REVIEW ms=", (Time.get_ticks_usec()-began)/1000.0, " frame=", Engine.get_process_frames())

func _record_order_history(base: int, tip: int, cost: float, customer: Node3D) -> void:
	if burger_probe_mode in ["no_history", "no_records"]: return
	var began := Time.get_ticks_usec()
	super._record_order_history(base, tip, cost, customer)
	print("BURGER_HISTORY ms=", (Time.get_ticks_usec()-began)/1000.0, " frame=", Engine.get_process_frames())

func _complete_serve(station_index: int, customer: Node3D = null, remote_drink: Node3D = null) -> void:
	print("BURGER_COMMIT_START frame=", Engine.get_process_frames())
	super._complete_serve(station_index, customer, remote_drink)
	print("BURGER_COMMIT_END frame=", Engine.get_process_frames())

func _play_sale_payout_fx(customer: Node3D, base: int, tip: int, from_shown: float, to_amount: float) -> void:
	if burger_probe_mode == "no_payment": return
	print("BURGER_PAYMENT frame=", Engine.get_process_frames())
	super._play_sale_payout_fx(customer, base, tip, from_shown, to_amount)

func _show_order_profit(payout: float, cost: float) -> void:
	if burger_probe_mode in ["no_profit", "no_feedback"]: return
	super._show_order_profit(payout, cost)

class NoCompletionLight extends Node3D:
	func pulse(_at: Vector3, _seconds: float) -> void: pass
	func stop() -> void: pass

func _acquire_serve_fly_root() -> Control:
	var result := super._acquire_serve_fly_root()
	if burger_probe_mode == "no_light" and result != null:
		var burst := result.get_node("BurgerCompleteBurst")
		var original = burst.get_meta("completion_light", null)
		if is_instance_valid(original): original.stop()
		var replacement := NoCompletionLight.new()
		world.add_child(replacement)
		burst.set_meta("completion_light", replacement)
	return result

func _chef_fresh_serve(customer: Object, freshness: float, payout: int) -> void:
	if burger_probe_mode == "no_feedback": return
	super._chef_fresh_serve(customer, freshness, payout)
