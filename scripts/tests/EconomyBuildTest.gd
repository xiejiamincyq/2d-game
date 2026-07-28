extends SceneTree

const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const OverseerBossScript = preload("res://scripts/actors/OverseerBoss.gd")
const PlayerScript = preload("res://scripts/actors/Player.gd")
const UpgradeSystemScript = preload("res://scripts/systems/UpgradeSystem.gd")
const WaveDirectorScript = preload("res://scripts/systems/WaveDirector.gd")

const FAMILY_IDS: Array[String] = ["ballistics", "mobility", "automation"]
const ENEMY_KIND_BY_STAGE_KEY: Dictionary = {
	"scrapper": EnemyScript.EnemyKind.SCRAPPER,
	"dasher": EnemyScript.EnemyKind.DASHER,
	"spitter": EnemyScript.EnemyKind.SPITTER,
	"bruiser": EnemyScript.EnemyKind.BRUISER,
	"marksman": EnemyScript.EnemyKind.MARKSMAN,
	"lobber": EnemyScript.EnemyKind.LOBBER,
}
const SAMPLE_RUNS := 64
const PICKUP_EFFICIENCY := 0.85

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: EconomyBuildTest: " + message)
	quit(1)
	return false

func _flatten_offers(state: Dictionary) -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	for family_value in state.get("families", []):
		for offer_value in (family_value as Dictionary).get("offers", []):
			offers.append((offer_value as Dictionary).duplicate(true))
	return offers

func _select_free_offer(offers: Array[Dictionary], family_id: String) -> Dictionary:
	for offer in offers:
		if String(offer.get("family", "")) == family_id and String(offer.get("kind", "")) == "evolution":
			return offer
	for offer in offers:
		if String(offer.get("family", "")) == family_id and String(offer.get("kind", "")) == "core":
			return offer
	for offer in offers:
		if String(offer.get("family", "")) == family_id:
			return offer
	return {}

func _sort_purchase_priority(left: Dictionary, right: Dictionary, family_id: String) -> bool:
	var left_focus := String(left.get("family", "")) == family_id
	var right_focus := String(right.get("family", "")) == family_id
	if left_focus != right_focus:
		return left_focus
	var left_core := String(left.get("kind", "")) in ["core", "evolution"]
	var right_core := String(right.get("kind", "")) in ["core", "evolution"]
	if left_core != right_core:
		return left_core
	return int(left.get("cost", 0)) < int(right.get("cost", 0))

func _stage_coin_income(stage: Dictionary, wave_number: int) -> int:
	var income := 0
	var projectiles := Node.new()
	for stage_key in ENEMY_KIND_BY_STAGE_KEY:
		var enemy: Node = EnemyScript.new()
		enemy.setup(int(ENEMY_KIND_BY_STAGE_KEY[stage_key]), wave_number, projectiles)
		income += int(stage.get(stage_key, 0)) * int(enemy.coin_value)
		enemy.free()
	projectiles.free()
	return income

func _median(values: Array[int]) -> float:
	values.sort()
	var middle := values.size() / 2
	if values.size() % 2 == 0:
		return (float(values[middle - 1]) + float(values[middle])) * 0.5
	return float(values[middle])

func _median_float(values: Array[float]) -> float:
	values.sort()
	var middle := values.size() / 2
	if values.size() % 2 == 0:
		return (values[middle - 1] + values[middle]) * 0.5
	return values[middle]

func _estimate_sustained_output(player: Node) -> float:
	var projectile_multiplier: float = player.get_effective_damage_multiplier(&"projectile")
	# At the Boss engagement distance, the center line lands reliably while
	# each additional 7.5-degree side line connects about half the time.
	var expected_line_hits: float = 1.0 + float(player.weapon_lines - 1) * 0.5
	# Grenades trade 70% fire rate for 300% base damage. This assumes one
	# explosion connects per projectile and excludes incidental splash targets.
	var grenade_output_multiplier: float = 0.9 if player.active_build_evolutions.has("orbital_storm") else 1.0
	var projectile_output: float = player.weapon_damage * player.fire_rate * expected_line_hits * projectile_multiplier * grenade_output_multiplier
	var mobility_multiplier: float = player.get_effective_damage_multiplier(&"dash")
	var mobility_output: float = player.dash_melee_damage / player.dash_cooldown * 0.75 * mobility_multiplier
	if player.mine_level > 0:
		# Model a moving Boss spending 0.45s in each crossed trap. Radius and
		# spacing both affect how consistently a laid corridor connects.
		var spike_coverage: float = player.move_speed / player.spike_spacing
		var spike_ticks: float = 0.45 / player.spike_tick_interval
		var radius_factor: float = clampf(player.spike_radius / 26.0, 1.0, 1.15)
		mobility_output += player.spike_damage * spike_coverage * spike_ticks * radius_factor * mobility_multiplier
	if player.active_build_evolutions.has("rift_overdrive"):
		var burn_uptime: float = minf(1.0, 4.0 / maxf(0.01, player.dash_cooldown))
		mobility_output += player.weapon_damage * burn_uptime * mobility_multiplier
	var automation_multiplier: float = player.get_effective_damage_multiplier(&"laser")
	var automation_output: float = player.drone_count * player.drone_damage * automation_multiplier
	if player.arc_pulse_level > 0:
		automation_output += player.get_arc_pulse_damage() / player.get_arc_pulse_interval() * automation_multiplier
	return projectile_output + mobility_output + automation_output

func _estimate_signature_share(player: Node, family_id: String, total_output: float) -> float:
	if total_output <= 0.0:
		return 0.0
	var family_multiplier: float
	match family_id:
		"ballistics":
			family_multiplier = player.get_effective_damage_multiplier(&"projectile")
			var expected_line_hits: float = 1.0 + float(player.weapon_lines - 1) * 0.5
			var grenade_multiplier: float = 0.9 if player.active_build_evolutions.has("orbital_storm") else 1.0
			var signature_output: float = player.weapon_damage * player.fire_rate * expected_line_hits * family_multiplier * grenade_multiplier
			return signature_output / total_output
		"mobility":
			if player.mine_level <= 0:
				return 0.0
			family_multiplier = player.get_effective_damage_multiplier(&"spike")
			var coverage: float = player.move_speed / player.spike_spacing
			var ticks: float = 0.45 / player.spike_tick_interval
			var reliability: float = clampf(player.spike_radius / 26.0, 1.0, 1.15)
			var signature_output: float = player.spike_damage * coverage * ticks * reliability * family_multiplier
			if player.active_build_evolutions.has("rift_overdrive"):
				signature_output += player.weapon_damage * minf(1.0, 4.0 / maxf(0.01, player.dash_cooldown)) * family_multiplier
			return signature_output / total_output
		"automation":
			if player.arc_pulse_level <= 0:
				return 0.0
			family_multiplier = player.get_effective_damage_multiplier(&"arc")
			# Thunder Matrix is a combined drone-and-arc signature. Count both halves
			# now that the evolution explicitly transforms each mechanic.
			var signature_output: float = player.drone_count * player.drone_damage * family_multiplier
			signature_output += player.get_arc_pulse_damage() / player.get_arc_pulse_interval() * family_multiplier
			return signature_output / total_output
	return 0.0

func _is_route_recognizable(player: Node, family_id: String) -> bool:
	match family_id:
		"ballistics":
			return player.weapon_damage > 10.0 or player.fire_rate > 13.0 or player.weapon_lines > 1
		"mobility":
			return player.mine_level > 0 or player.dash_distance > 165.0 or player.dash_cooldown < 2.0
		"automation":
			return player.drone_count > 0 or player.arc_pulse_level > 0
	return false

func _initialize() -> void:
	var director: Node = WaveDirectorScript.new()
	var stage_incomes: Array[int] = []
	for stage_index in range(5):
		stage_incomes.append(_stage_coin_income(director.waves[stage_index], stage_index + 1))
	if not _assert_true(stage_incomes == [52, 95, 149, 212, 247], "official stage coin incomes changed without an economy review: %s" % [stage_incomes]):
		return

	var route_median_outputs: Dictionary = {}
	var route_median_ttks: Dictionary = {}
	var route_median_paid: Dictionary = {}
	var route_median_signature_share: Dictionary = {}
	for family_index in range(FAMILY_IDS.size()):
		var family_id := FAMILY_IDS[family_index]
		var paid_counts: Array[int] = []
		var double_opportunities := 0
		var no_purchase_windows := 0
		var buyout_windows := 0
		var evolution_runs := 0
		var route_outputs: Array[float] = []
		var signature_shares: Array[float] = []
		var boss_ttks: Array[float] = []
		var paid_by_stage: Array[Array] = [[], [], [], [], []]
		var recognizable_by_second := 0
		var evolution_on_wave_five := 0
		var viable_ttk_runs := 0
		for sample_index in range(SAMPLE_RUNS):
			seed(0x610000 + family_index * 1000 + sample_index)
			var player: Node = PlayerScript.new()
			root.add_child(player)
			# SceneTree script initialization runs before a newly added child receives
			# its deferred ready notification, so initialize the real player contract now.
			player._ready()
			player.set_physics_process(false)
			var upgrades: Node = UpgradeSystemScript.new()
			upgrades.setup(player)
			for settlement_wave in range(1, 6):
				upgrades.add_coins(roundi(float(stage_incomes[settlement_wave - 1]) * PICKUP_EFFICIENCY))
				if not _assert_true(upgrades.prepare_settlement(settlement_wave), "%s sample %d could not prepare settlement %d" % [family_id, sample_index, settlement_wave]):
					return
				var state: Dictionary = upgrades.get_settlement_state()
				var offers := _flatten_offers(state)
				var free_offer := _select_free_offer(offers, family_id)
				if not _assert_true(not free_offer.is_empty() and upgrades.claim_free_offer(free_offer), "%s sample %d could not claim its focused reward" % [family_id, sample_index]):
					return
				var candidates: Array[Dictionary] = []
				for offer in _flatten_offers(upgrades.get_settlement_state()):
					if not bool(offer.get("sold", false)) and not bool(offer.get("capped", false)):
						candidates.append(offer)
				candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return _sort_purchase_priority(left, right, family_id))
				var costs: Array[int] = []
				for candidate in candidates:
					costs.append(int(candidate.get("cost", 0)))
				costs.sort()
				if costs.size() >= 2 and costs[0] + costs[1] <= upgrades.coins:
					double_opportunities += 1
				if costs.is_empty() or costs[0] > upgrades.coins:
					no_purchase_windows += 1
				var paid_this_wave := 0
				for candidate in candidates:
					if upgrades.purchase_settlement_offer(candidate):
						paid_this_wave += 1
				paid_counts.append(paid_this_wave)
				paid_by_stage[settlement_wave - 1].append(paid_this_wave)
				if paid_this_wave >= 5:
					buyout_windows += 1
				if not _assert_true(upgrades.complete_settlement({"transaction": state["transaction"]}), "%s sample %d could not close settlement %d" % [family_id, sample_index, settlement_wave]):
					return
				if settlement_wave == 2 and _is_route_recognizable(player, family_id):
					recognizable_by_second += 1
				if settlement_wave == 5 and not String(upgrades.acquired_evolution_id).is_empty():
					evolution_on_wave_five += 1
			if not String(upgrades.acquired_evolution_id).is_empty():
				evolution_runs += 1
			var sustained_output := _estimate_sustained_output(player)
			route_outputs.append(sustained_output)
			signature_shares.append(_estimate_signature_share(player, family_id, sustained_output))
			var boss_ttk: float = OverseerBossScript.BASE_MAX_HEALTH / sustained_output
			boss_ttks.append(boss_ttk)
			if boss_ttk >= 15.0 and boss_ttk <= 45.0:
				viable_ttk_runs += 1
			upgrades.free()
			root.remove_child(player)
			player.free()
		var window_count := SAMPLE_RUNS * 5
		var double_rate := float(double_opportunities) / float(window_count)
		var no_purchase_rate := float(no_purchase_windows) / float(window_count)
		var buyout_rate := float(buyout_windows) / float(window_count)
		var median_paid := _median(paid_counts)
		var median_output := _median_float(route_outputs)
		var median_boss_ttk := _median_float(boss_ttks)
		var median_signature_share := _median_float(signature_shares)
		var stage_paid_medians: Array[float] = []
		for stage_values_value in paid_by_stage:
			var stage_values: Array[int] = []
			stage_values.assign(stage_values_value)
			stage_paid_medians.append(_median(stage_values))
		route_median_outputs[family_id] = median_output
		route_median_ttks[family_id] = median_boss_ttk
		route_median_paid[family_id] = median_paid
		route_median_signature_share[family_id] = median_signature_share
		print("ECONOMY: family=%s samples=%d stage_paid=%s median_paid=%.2f double_rate=%.3f no_purchase_rate=%.3f buyout_rate=%.3f recognizable_rate=%.3f evolution_rate=%.3f output=%.1f signature_share=%.3f boss_ttk=%.1fs viable_rate=%.3f" % [family_id, SAMPLE_RUNS, stage_paid_medians, median_paid, double_rate, no_purchase_rate, buyout_rate, float(recognizable_by_second) / float(SAMPLE_RUNS), float(evolution_runs) / float(SAMPLE_RUNS), median_output, median_signature_share, median_boss_ttk, float(viable_ttk_runs) / float(SAMPLE_RUNS)])
		if not _assert_true(median_paid >= 1.0 and median_paid <= 2.0, "%s median paid purchases %.2f escaped the one-to-two target" % [family_id, median_paid]):
			return
		if not _assert_true(double_rate >= 0.20, "%s did not offer a meaningful save-for-two purchase rate: %.3f" % [family_id, double_rate]):
			return
		if not _assert_true(no_purchase_rate <= 0.20, "%s was unable to afford any purchase too often: %.3f" % [family_id, no_purchase_rate]):
			return
		if not _assert_true(buyout_rate <= 0.02, "%s could regularly buy out all five paid offers: %.3f" % [family_id, buyout_rate]):
			return
		if not _assert_true(evolution_runs == SAMPLE_RUNS, "%s did not reach its evolution before the Boss in every focused run" % family_id):
			return
		if not _assert_true(float(recognizable_by_second) / float(SAMPLE_RUNS) >= 0.90, "%s was mechanically recognizable by the second settlement in fewer than 90%% of focused runs" % family_id):
			return
		if not _assert_true(evolution_on_wave_five == SAMPLE_RUNS, "%s evolution did not arrive at the fifth settlement in every focused run" % family_id):
			return
		if not _assert_true(float(viable_ttk_runs) / float(SAMPLE_RUNS) >= 0.80, "%s focused-build Boss TTK viability rate was below 80%%" % family_id):
			return
		var minimum_signature_share: float = {"ballistics": 0.50, "mobility": 0.25, "automation": 0.20}[family_id]
		if not _assert_true(median_signature_share >= minimum_signature_share, "%s signature mechanic contributed only %.1f%% of focused output" % [family_id, median_signature_share * 100.0]):
			return
	var output_values: Array[float] = []
	var paid_values: Array[float] = []
	for family_id in FAMILY_IDS:
		output_values.append(float(route_median_outputs[family_id]))
		paid_values.append(float(route_median_paid[family_id]))
	output_values.sort()
	paid_values.sort()
	if not _assert_true(paid_values[-1] - paid_values[0] <= 0.5, "focused routes had unequal purchase access: %s" % [route_median_paid]):
		return
	var output_ratio := output_values[-1] / output_values[0]
	if not _assert_true(output_ratio <= 1.35, "focused route output ratio %.3f exceeded the 1.35 balance band: %s" % [output_ratio, route_median_outputs]):
		return
	for family_id in FAMILY_IDS:
		var median_ttk := float(route_median_ttks[family_id])
		if not _assert_true(median_ttk >= 15.0 and median_ttk <= 45.0, "%s median Boss TTK proxy %.1fs escaped the focused-build 15-45s band" % [family_id, median_ttk]):
			return
	director.free()
	print("TEST PASS: EconomyBuildTest %d" % assertions)
	quit(0)
