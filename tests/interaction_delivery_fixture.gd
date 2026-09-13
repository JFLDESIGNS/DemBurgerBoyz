extends "main_ticket_harness.gd"
var pointer := Vector2.ZERO
var over_trash := false
var added: Array[String] = []
var credits: Array = []
var spent := 0.0
var disposed := 0
func _strip_mouse_pos(_event: InputEvent = null) -> Vector2: return pointer
func _pointer_button_pressed(_button_index: int) -> bool: return true
func _add_ingredient(id: String) -> void: added.append(id)
func _garbage_area_hit(_pos: Vector2) -> bool: return over_trash
func _refresh_spatula_ui() -> void: pass
func _physical_garbage_react() -> void: disposed += 1
func _spend(amount: float, _note: String = "", _col: Color = Color("FFAB91")) -> void: spent += amount
func _credit_supply_delivery(id: String, pack: int, kind: String) -> void: credits.append([id,pack,kind])
func _refresh_supply_ui_fast(_id: String) -> void: pass
