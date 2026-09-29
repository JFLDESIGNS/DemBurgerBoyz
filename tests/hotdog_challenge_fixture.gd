extends "res://tests/main_ticket_harness.gd"
var credited = 0
func _create_ticket(customer: Node3D) -> void:
	if tickets.has(customer): return
	var ticket = Control.new()
	get_node("UI/Root").add_child(ticket)
	var timer_label = Label.new(); ticket.add_child(timer_label)
	ticket.set_meta("timer_label", timer_label)
	tickets[customer] = ticket
func _clear_station(index: int, _defer_visual: bool = false) -> void:
	stations[index]["items"] = []
func _credit_ticket_payout(_pay: Dictionary, payout: int, _customer: Node3D = null) -> void: credited += payout
func _update_hud() -> void: pass

func _refresh_customer_queue_timers() -> void: pass
func _sync_combat_audio() -> void: pass
