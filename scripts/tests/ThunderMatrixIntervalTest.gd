extends SceneTree

const PlayerScript = preload("res://scripts/actors/Player.gd")
const UpgradeScript = preload("res://scripts/systems/UpgradeSystem.gd")
const ArcScript = preload("res://scripts/components/ArcPulseVisual.gd")
var assertions := 0
var failures := 0
var fixture: Node2D

func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("TEST FAIL: ThunderMatrixIntervalTest: " + message)

func _initialize() -> void:
	await process_frame
	fixture = Node2D.new()
	root.add_child(fixture)
	for base in [1.85, 1.15]:
		for level in [1, 4, 20]:
			for overdrive in [false, true]:
				await test_interval(base, level, overdrive)
	await test_restore()
	fixture.queue_free()
	await process_frame
	if failures == 0:
		print("TEST PASS: ThunderMatrixIntervalTest %d" % assertions)
	else:
		print("THUNDER_INTERVAL_RED: assertions=%d failures=%d" % [assertions, failures])
	quit(0 if failures == 0 else 1)

func make_player() -> Node:
	var player := PlayerScript.new()
	fixture.add_child(player)
	player.set_physics_process(false)
	player.health.set_process(false)
	return player

func arc_count(shots: Node) -> int:
	var result := 0
	for child in shots.get_children():
		if child.get_script() == ArcScript:
			child.set_process(false)
			result += 1
	return result

func test_interval(base: float, level: int, overdrive: bool) -> void:
	var player := make_player()
	var shots := Node2D.new()
	fixture.add_child(shots)
	player.projectile_parent = shots
	player.arc_base_interval = base
	player.arc_pulse_level = level
	player.set_overdrive_active(overdrive)
	var normal := maxf(0.7, base - level * 0.2) / (1.5 if overdrive else 1.0)
	check(is_equal_approx(player.get_arc_pulse_interval(), normal), "ordinary arc changed: base %.2f level %d overdrive %s" % [base, level, overdrive])
	check(player.activate_build_evolution("thunder_matrix"), "matrix activation failed")
	var expected := normal * 1.5
	print("THUNDER_INTERVAL: base=%.2f level=%d overdrive=%s actual=%.5f expected=%.5f" % [base, level, overdrive, player.get_arc_pulse_interval(), expected])
	check(is_equal_approx(player.get_arc_pulse_interval(), expected), "matrix interval not 150 percent of same-level ordinary arc")
	check(not player.activate_build_evolution("thunder_matrix"), "duplicate matrix activation accepted")
	check(is_equal_approx(player.arc_base_interval, base), "matrix mutated upgradeable base interval")
	player.arc_timer = 0.0
	player._update_passives(0.001)
	check(arc_count(shots) == 1, "initial actual arc emission missing")
	# Deterministic manual game steps: real emitted wave nodes, not a constant-only test.
	var elapsed := 0.0
	while elapsed < expected - 0.002:
		var step := minf(0.001, expected - 0.002 - elapsed)
		player._update_passives(step)
		arc_count(shots)
		elapsed += step
	check(arc_count(shots) == 1, "matrix emitted second wave before its extended interval")
	player._update_passives(0.005)
	check(arc_count(shots) == 2, "matrix did not emit its second real wave after the extended interval")
	player.queue_free()
	shots.queue_free()
	await process_frame

func test_restore() -> void:
	var original := make_player()
	var upgrades := UpgradeScript.new()
	fixture.add_child(upgrades)
	upgrades.setup(original)
	for id in ["arc", "drone", "arc_relay", "arc_capacitor", "thunder_matrix"]:
		upgrades._apply_card(id)
	upgrades.acquired_evolution_id = "thunder_matrix"
	var state: Dictionary = upgrades.get_snapshot_state()
	var expected := maxf(0.7, original.arc_base_interval - original.arc_pulse_level * 0.2) * 1.5
	check(is_equal_approx(original.get_arc_pulse_interval(), expected), "upgraded matrix interval wrong before save")
	for generation in range(3):
		var restored := make_player()
		var restored_upgrades := UpgradeScript.new()
		fixture.add_child(restored_upgrades)
		restored_upgrades.setup(restored)
		check(restored_upgrades.restore_snapshot_state(state), "growth snapshot restore rejected")
		check(restored.active_build_evolutions.has("thunder_matrix"), "restore lost matrix evolution")
		check(is_equal_approx(restored.get_arc_pulse_interval(), expected), "save/restore generation %d accumulated or lost interval multiplier" % generation)
		check(is_equal_approx(restored.arc_base_interval, original.arc_base_interval), "save/restore changed upgraded base interval")
		restored.set_overdrive_active(true)
		check(is_equal_approx(restored.get_arc_pulse_interval(), expected / 1.5), "restored matrix lost overdrive frequency modifier")
		restored.set_overdrive_active(false)
		state = restored_upgrades.get_snapshot_state()
		restored.queue_free()
		restored_upgrades.queue_free()
		await process_frame
	original.queue_free()
	upgrades.queue_free()
	await process_frame
