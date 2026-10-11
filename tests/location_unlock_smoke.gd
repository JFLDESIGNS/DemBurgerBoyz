extends SceneTree
func _initialize():call_deferred("run")
func run():
 var cfg_path="user://truck_location.cfg"
 var existed=FileAccess.file_exists(cfg_path)
 var before=FileAccess.get_file_as_bytes(cfg_path) if existed else PackedByteArray()
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/potato_network_fixture.gd"));root.add_child(g);current_scene=g
 g.money=499;g.unlocked_locations=[]
 assert(not g._purchase_location_access("downtown_row") and g.money==499)
 g.money=1500;assert(g._purchase_location_access("downtown_row") and g.money==1000)
 assert(g._purchase_location_access("downtown_row") and g.money==1000)
 assert(g._purchase_location_access("city_center_peak") and g.money==0)
 g._load_truck_location();assert(g._location_unlock_cost("downtown_row")==0 and g._location_unlock_cost("city_center_peak")==0)
 assert(not g._purchase_location_access("invalid"))
 var milk=load("res://scripts/milk_refill.gd")
 assert(milk.flight_point(Vector3.ZERO,Vector3.ONE,0)==Vector3.ZERO)
 assert(milk.flight_point(Vector3.ZERO,Vector3.ONE,1).distance_to(Vector3.ONE)<.0001)
 if existed: FileAccess.open(cfg_path,FileAccess.WRITE).store_buffer(before)
 else: DirAccess.remove_absolute(cfg_path)
 print("LOCATION_UNLOCK_OK: insufficient funds, one-time purchase, persistence, invalid stop, eased flight endpoints")
 quit()
