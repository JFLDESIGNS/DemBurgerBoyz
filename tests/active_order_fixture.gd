extends "main_ticket_harness.gd"
var served_ids: Array = []
func _highlight_tickets() -> void: pass
func _highlight_active_station() -> void: pass
func _refresh_customer_queue_timers() -> void: pass
func _submit_serve_request(cust: Node3D, _index: int) -> void: served_ids.append(_customer_net_id(cust))
func _sides_ready_for_order(_order: Array, customer: Node3D = null) -> bool: return not customer.get_meta("blocked",false)
func _find_perfect_station_for(_order: Array) -> int: return 0
