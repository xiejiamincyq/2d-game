extends SceneTree
const Nursery = preload("res://scripts/systems/NurseryEncounterDirector.gd")
const Legacy = preload("res://scripts/tests/fixtures/LegacyWaveDirector.gd")
const EnemyActor = preload("res://scripts/actors/Enemy.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: NurserySupplyPolicyTest " + message)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var director := Nursery.new()
	var legacy := Legacy.new()
	var enemy := EnemyActor.new()
	check(director.has_method("_roll_enemy_drops"), "first chapter lacks independent supply policy")
	if failures:
		director.free(); legacy.free(); enemy.free(); quit(1); return
	director.run_seed = 521
	# Pure drop-policy fixture. Real world start/binding is independently covered
	# by NurserySupplyRuntimeTest; never call its world hook without a map.
	director.supply_rng.seed = 521
	director.spawn_rng.seed = 521
	director.encounters = director._build_encounters()
	var counts: Array[int] = []
	for encounter in 3:
		director._prepare_encounter(encounter)
		director.state = director.State.COMBAT
		var hearts := 0
		var shields := 0
		for kill in 16:
			var drop: Dictionary = director._roll_enemy_drops(enemy)
			if drop.heart: hearts += 1
			if drop.shield:
				shields += 1
				check(drop.shield_value == 9.0, "standard first-chapter enemy lacks small shield value")
			if kill == 4: check(hearts >= 1, "no heart by fifth accepted kill")
			if kill == 7: check(shields >= 1, "no shield by eighth accepted kill")
		check(hearts >= 1 and shields >= 1, "encounter supply guarantees did not reset")
		counts.append(hearts + shields)
	check(enemy.shield_drop_value == 0.0, "policy mutated common Enemy drop eligibility")
	legacy.spawn_rng.seed = 521
	var expected := RandomNumberGenerator.new()
	expected.seed = 521
	for kill in 20:
		var expected_heart := expected.randf() < 0.025
		var drop: Dictionary = legacy._roll_enemy_drops(enemy)
		check(drop.heart == expected_heart and not drop.shield and drop.shield_value == 0.0, "legacy drop probabilities or RNG consumption changed")
	check(legacy.spawn_rng.state == expected.state, "legacy spawn RNG sequence changed")
	enemy.shield_drop_value = 17.0
	for kill in 20:
		var heart := expected.randf() < 0.025
		var shield := expected.randf() < 0.70
		var drop: Dictionary = legacy._roll_enemy_drops(enemy)
		check(drop.heart==heart and drop.shield==shield and drop.shield_value==17.0, "eligible legacy shield drops changed")
	check(legacy.spawn_rng.state==expected.state, "eligible legacy shield RNG sequence changed")
	director.free(); legacy.free(); enemy.free()
	if failures == 0: print("TEST PASS: NurserySupplyPolicyTest %d" % checks)
	quit(1 if failures else 0)
