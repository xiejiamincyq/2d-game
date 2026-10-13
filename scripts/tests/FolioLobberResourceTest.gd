extends SceneTree
const Validator = preload("res://scripts/art/NativeArtValidator.gd")
func _initialize() -> void:
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://docs/art/native-manifests/folio_lobber_paper_v1.json"))
	if not manifest is Dictionary or manifest.get("role") != "ordinary" or manifest.get("bone_count") != 16:
		push_error("TEST FAIL: FolioLobberResourceTest original ordinary rig declaration")
		quit(1)
		return
	var errors := Validator.new().validate_entry(manifest)
	if not errors.is_empty():
		push_error("TEST FAIL: FolioLobberResourceTest "+str(errors))
		quit(1)
		return
	print("TEST PASS: FolioLobberResourceTest 2")
	quit(0)
