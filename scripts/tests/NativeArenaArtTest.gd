extends "NativeArenaRuntimeTest.gd"
## Author manifest validation remains outside the shipping package.
func suite_name() -> String: return "NativeArenaArtTest"
func _check_source_contract(floor_view: Node2D) -> void:
	super._check_source_contract(floor_view)
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://docs/art/style-manifests/arena_paper_environment_v1.json"))
	check(manifest is Dictionary and manifest.contract == "native-environment-source-v1" and manifest.license_origin == "project-original" and manifest.roles == ["planter","greenhouse","tank","pipe"] and manifest.external_raster_dependencies.is_empty(), "original environment source contract missing")
