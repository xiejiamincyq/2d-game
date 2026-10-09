extends SceneTree

const Validator = preload("res://scripts/art/NativeArtValidator.gd")
const DIRECTORY := "res://docs/art/native-manifests"

func _initialize() -> void:
	var validator := Validator.new()
	var files := DirAccess.get_files_at(DIRECTORY)
	files.sort()
	var count := 0
	var failed := false
	var seen: Array[String] = []
	for filename in files:
		if not filename.ends_with(".json"):
			continue
		count += 1
		var entry = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY.path_join(filename)))
		if not entry is Dictionary:
			push_error("TEST FAIL: NativeArtCatalog invalid manifest " + filename)
			failed = true
			continue
		var errors := validator.validate_entry(entry)
		var id := str(entry.get("asset_id", ""))
		if id in seen:
			errors.append("duplicate native asset identifier")
		seen.append(id)
		for error in errors:
			push_error("TEST FAIL: NativeArtCatalog " + filename + ": " + error)
			failed = true
	if count == 0:
		push_error("TEST FAIL: NativeArtCatalog contains no declared resources")
		failed = true
	if not failed:
		print("NATIVE CATALOG PASS: %d declared editable resources; not a full-goal completion claim" % count)
	quit(1 if failed else 0)
