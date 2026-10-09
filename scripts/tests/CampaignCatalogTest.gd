extends SceneTree

var assertions := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: CampaignCatalogTest " + message)

func _initialize() -> void:
	var path := "res://scripts/systems/ChapterCatalog.gd"
	check(FileAccess.file_exists(path), "six-chapter catalog is not implemented")
	if failures > 0:
		quit(1)
		return
	var catalog = load(path)
	check(catalog.CHAPTER_COUNT == 6, "campaign must have exactly six chapters")
	var identifiers := {}
	for field in ["theme_id", "map_profile_id", "enemy_family_id", "boss_id", "mechanic_id"]:
		identifiers[field] = []
	for chapter in range(1, 7):
		var definition: Dictionary = catalog.get_chapter(chapter)
		check(definition.get("id") == chapter, "chapter IDs must be sequential")
		for field in ["name", "boss_name", "description"]:
			check(definition.get(field, "") is String and not String(definition.get(field, "")).is_empty(), "chapter %d missing %s" % [chapter, field])
		for field in identifiers:
			var identifier: String = definition.get(field, "")
			check(not identifier.is_empty() and identifier.is_valid_identifier(), "invalid chapter key: " + field)
			check(identifier not in identifiers[field], "chapter content metadata duplicates " + field)
			identifiers[field].append(identifier)
		check(definition.get("enemy_roles", []) is Array and definition.get("enemy_roles", []).size() >= 2, "chapter needs at least two enemy roles")
		# UI/build tools may edit a copy without mutating the canonical catalog.
		definition["name"] = "changed"
		definition["enemy_roles"].clear()
		check(catalog.get_chapter(chapter)["name"] != "changed", "caller mutated catalog name")
		check(catalog.get_chapter(chapter)["enemy_roles"].size() >= 2, "caller mutated nested enemy roles")
	for invalid in [-100, -1, 0, 7, 999]:
		check(catalog.get_chapter(invalid).is_empty(), "out-of-range chapter must not clamp to playable chapter")
	if failures == 0:
		print("TEST PASS: CampaignCatalogTest %d" % assertions)
	quit(0 if failures == 0 else 1)
