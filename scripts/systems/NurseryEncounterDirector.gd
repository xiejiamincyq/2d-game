extends "res://scripts/systems/ChapterEncounterDirector.gd"
## First chapter policy, shared clearance/reward flow stays in the base.
const BOSS_LABEL := "藤冠守卫：藤鞭、锁点根刺与王冠种雨"
const VineBoss = preload("res://scripts/actors/NurseryVineBoss.gd")
const HEART_CHANCE := 0.08
const SMALL_SHIELD_CHANCE := 0.10
const SMALL_SHIELD_VALUE := 9.0
const TrapField = preload("res://scripts/world/ReusableTrapField.gd")
var trap_field: Node2D
var supply_rng := RandomNumberGenerator.new()
var encounter_kills := 0
var encounter_hearts := 0
var encounter_shields := 0

func start_run(seed_value: int,target: PlayerBody,enemies: Node2D,projectiles: Node2D,portals: Node2D,build: BuildSystem,navigation: ArenaLayout) -> bool:
	if state!=State.IDLE or not is_instance_valid(navigation) or navigation.get_parent()==null: return false
	var field := navigation.get_parent().get_node_or_null("TrapField")
	if not is_instance_valid(field) or field.get_script()!=TrapField or not field.is_inside_tree() or field.layout!=navigation: return false
	trap_field = field
	trap_field.tree_exiting.connect(_on_trap_departure)
	return super.start_run(seed_value,target,enemies,projectiles,portals,build,navigation)

func _on_trap_departure() -> void: _fail("苗圃压板所有者离场")

func _on_state_changed(next: State) -> void:
	if is_instance_valid(trap_field): trap_field.set_active(next==State.COMBAT,4 if encounter_index==2 else 2)

func _on_run_started() -> void:
	# Supply randomness must not alter map, portal or enemy composition rolls.
	supply_rng.seed = run_seed ^ 0x4E555253
	trap_field.configure(arena_navigation,run_seed,player)

func _prepare_encounter(index: int) -> void:
	encounter_kills = 0
	encounter_hearts = 0
	encounter_shields = 0
	super._prepare_encounter(index)

func _roll_enemy_drops(_enemy: Node) -> Dictionary:
	var heart := supply_rng.randf() < HEART_CHANCE
	var shield := supply_rng.randf() < SMALL_SHIELD_CHANCE
	if state == State.COMBAT:
		encounter_kills += 1
		heart = heart or (encounter_hearts == 0 and encounter_kills >= 5)
		shield = shield or (encounter_shields == 0 and encounter_kills >= 8)
		if heart: encounter_hearts += 1
		if shield: encounter_shields += 1
	return {"heart": heart, "shield": shield, "shield_value": SMALL_SHIELD_VALUE}

func _chapter_number() -> int: return 1
func _boss_label() -> String: return BOSS_LABEL
func _boss_position() -> Vector2: return Vector2(0,-500)
func _boss_available() -> bool: return true
func _create_boss_actor() -> Node: return VineBoss.new()
func _build_encounters() -> Array[Dictionary]:
	return [
		{"id": &"root_outskirts", "name": "苗圃外围", "scrapper": spawn_rng.randi_range(14, 18), "spitter": spawn_rng.randi_range(2, 3), "rate": 0.18},
		{"id": &"spore_beds", "name": "孢子植床", "scrapper": spawn_rng.randi_range(20, 24), "spitter": spawn_rng.randi_range(4, 5), "rate": 0.15},
		{"id": &"overgrown_detour", "name": "高风险：过生根巢", "scrapper": spawn_rng.randi_range(30, 34), "spitter": spawn_rng.randi_range(6, 7), "rate": 0.12},
	]
func _encounter_kinds(encounter: Dictionary) -> Array[int]:
	var kinds: Array[int] = []
	for _count in encounter.scrapper: kinds.append(EnemyScript.EnemyKind.SCRAPPER)
	for _count in encounter.spitter: kinds.append(EnemyScript.EnemyKind.SPITTER)
	return kinds
