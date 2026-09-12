extends SceneTree

const CustomerScript := preload("res://scripts/customer.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var bundled_dir := "res://defaults/characters"
	var bundled := DirAccess.open(bundled_dir)
	assert(bundled != null)
	var expected := [
		"char1.json",
		"char2.json",
		"char33.json",
		"man.json",
		"man5.json",
		"man6.json",
		"man9.json",
		"woman2.json",
		"woman4.json",
		"last_character.json",
	]
	for file_name in expected:
		var path := "%s/%s" % [bundled_dir, file_name]
		assert(FileAccess.file_exists(path), "missing bundled character %s" % file_name)
		var preset: Dictionary = CustomerScript._parse_saved_character_file(path)
		assert(not preset.is_empty(), "bundled character failed to parse: %s" % file_name)
		assert(str(preset.get("name", "")) != "")
	CustomerScript.ensure_saved_character_files()
	assert(CustomerScript.has_usable_saved_characters())
	print("bundled_character_backup_smoke OK")
	quit(0)
