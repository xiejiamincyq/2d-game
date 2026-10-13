extends "NativeImpactRuntimeTest.gd"
## Author manifest validation remains outside the shipping package.
func suite_name() -> String: return "NativeImpactArtTest"
func _check_source_contract(art: Script) -> void:
	super._check_source_contract(art)
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://docs/art/style-manifests/paper_impact_native_v1.json"))
	check(manifest is Dictionary and manifest.contract == "native-effect-source-v1" and manifest.license_origin == "project-original" and manifest.runtime_source == art.resource_path and manifest.external_raster_dependencies.is_empty(), "native source contract missing or contradicts actual art")
