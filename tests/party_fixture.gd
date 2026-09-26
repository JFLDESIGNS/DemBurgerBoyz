extends "res://tests/kitchen_network_fixture.gd"
func _set_phone_app(id: String) -> void:
 if is_instance_valid(_phone_party) and not _phone_party.applying:_phone_party.choose(id)
 _phone_app_id=id
 for key in _phone_party.pages:_phone_party.pages[key].set_active(key==id)
