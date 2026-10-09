extends "res://scripts/systems/CampaignProgressStore.gd"

# Fault injection at the filesystem boundary only. All fixture reads/writes and
# rollback renames remain real; this is not evidence of a real power failure.
func _rename_file(source: String, target: String) -> bool:
	if source.ends_with(".tmp"):
		return false
	return super._rename_file(source, target)
