extends "res://tests/full_restock_fixture.gd"
var feedback: Array[String] = []
func _flash(text: String, _color: Color = Color.WHITE, _duration: float = 1.8) -> void: feedback.append(text)
func _note_machine_used(_id: String) -> void: pass
func _refresh_fryer_basket_visual(_index: int) -> void: pass
