extends SceneTree
## Synthetic metadata contract tests only, NOT ordinary chapter victories.
var assertions := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: CampaignChainEvidenceTest " + label)

func state(clears: int) -> Dictionary:
	var values: Array[int] = []
	for chapter in range(1, clears + 1): values.append(chapter)
	return {"version": 1, "cleared_chapters": values}

func fixture(chapter: int, bank: Dictionary) -> Dictionary:
	return {"valid": true, "chapter": chapter - 1, "moves": 600, "shots": 80,
		"prerequisite_fixture": [], "samples": [{"state": "CLEARED", "kills": 30}],
		"chain": {"schema": 1, "enabled": true, "used_preseed": false, "process_id": 42,
			"returned_to_main": true, "defeated_boss_instance": 777, "expected_kills": 30,
			"saved_sha256": "a".repeat(64), "saved_state": state(chapter - 1),
			"before_state": state(chapter - 2), "source_bank": bank.duplicate(true),
			"parent_report_sha256": "" if chapter == 2 else "b".repeat(64)}}

func _initialize() -> void:
	var path := "res://scripts/art/CampaignChainEvidence.gd"
	check(ResourceLoader.exists(path, "GDScript"), "fresh-campaign evidence-chain contract is missing")
	if failures: quit(1); return
	var contract = load(path)
	var methods: Array = contract.get_script_method_list()
	check(methods.any(func(item: Dictionary) -> bool: return item.name == "parse_arguments"), "explicit opt-in chain arguments are missing")
	if failures: quit(1); return
	var fresh: Dictionary = contract.parse_arguments(PackedStringArray(["stage1", "chain=FRESH"]), 1)
	check(fresh.valid and fresh.enabled and fresh.args == PackedStringArray(["stage1"]) and fresh.parent_report == "", "first chain stage is not genuinely fresh")
	var next: Dictionary = contract.parse_arguments(PackedStringArray(["stage2", "risk", "chain=stage1"]), 2)
	check(next.valid and next.enabled and next.args == PackedStringArray(["stage2", "risk"]) and next.parent_report.ends_with("/stage1/report.json"), "next-stage argument provenance lost")
	var legacy: Dictionary = contract.parse_arguments(PackedStringArray(["old_stage", "risk"]), 3)
	check(legacy.valid and not legacy.enabled and legacy.args == PackedStringArray(["old_stage", "risk"]), "optional chain mode changes legacy arguments")
	for pair in [[1, ["stage1", "chain=stage0"]], [2, ["stage2", "chain=FRESH"]], [2, ["stage2", "chain=stage2"]], [2, ["stage2", "chain=../real"]], [2, ["stage2", "chain="]], [2, ["chain=stage1"]], [7, ["stage7", "chain=stage6"]], [2, ["stage2", "chain=stage0", "chain=stage1"]]]:
		check(not contract.parse_arguments(PackedStringArray(pair[1]), pair[0]).valid, "unsafe/nonsequential chain arguments accepted")
	var bank := {"scripts/Main.gd": "c".repeat(64)}
	for chapter in range(2, 7):
		var parent := fixture(chapter, bank)
		var before := parent.duplicate(true)
		check(contract.valid_parent(parent, chapter, bank, state(chapter - 1), "a".repeat(64), 43), "valid sequential metadata contract rejected")
		for key in ["valid", "chapter", "moves", "shots", "samples", "chain"]:
			var missing := parent.duplicate(true)
			missing.erase(key)
			check(not contract.valid_parent(missing, chapter, bank, state(chapter - 1), "a".repeat(64), 43), "missing evidence accepted: " + key)
		for pair in [["valid", false], ["valid", 1], ["chapter", chapter], ["chapter", true], ["moves", 500], ["shots", 50], ["prerequisite_fixture", [1]], ["samples", []], ["chain", null]]:
			var broken := parent.duplicate(true)
			broken[pair[0]] = pair[1]
			check(not contract.valid_parent(broken, chapter, bank, state(chapter - 1), "a".repeat(64), 43), "weak parent accepted: " + str(pair[0]))
		for pair in [["schema", 2], ["schema", true], ["enabled", false], ["used_preseed", true], ["process_id", 43], ["process_id", 0], ["returned_to_main", false], ["defeated_boss_instance", 0], ["expected_kills", 0], ["saved_sha256", "wrong"], ["saved_state", state(chapter)], ["before_state", state(chapter - 1)], ["source_bank", {}], ["parent_report_sha256", "wrong"]]:
			var broken := parent.duplicate(true)
			broken.chain[pair[0]] = pair[1]
			check(not contract.valid_parent(broken, chapter, bank, state(chapter - 1), "a".repeat(64), 43), "weak chain accepted: " + str(pair[0]))
		var dead := parent.duplicate(true)
		dead.samples[-1].state = "FAILED"
		check(not contract.valid_parent(dead, chapter, bank, state(chapter - 1), "a".repeat(64), 43), "death used as a real clear")
		dead = parent.duplicate(true)
		dead.samples[-1].kills = 29
		check(not contract.valid_parent(dead, chapter, bank, state(chapter - 1), "a".repeat(64), 43), "missing actual debt/Boss kill accepted")
		check(not contract.valid_parent(parent, chapter, bank, state(chapter - 2), "a".repeat(64), 43), "save missing current real clear accepted")
		check(not contract.valid_parent(parent, chapter, bank, state(chapter - 1), "d".repeat(64), 43), "save SHA mismatch accepted")
		check(not contract.valid_parent(parent, chapter, {"scripts/Main.gd": "d".repeat(64)}, state(chapter - 1), "a".repeat(64), 43), "source drift accepted")
		check(parent == before, "validation mutates prior evidence")
	for invalid in [-1, 0, 1, 7]:
		check(not contract.valid_parent(fixture(2, bank), invalid, bank, state(1), "a".repeat(64), 43), "invalid next stage accepted")
	if not failures: print("TEST PASS: CampaignChainEvidenceTest %d" % assertions)
	quit(1 if failures else 0)
