extends "res://scripts/systems/ChapterEncounterDirector.gd"
## Sixth-region policy only; shared director owns combat debts/reward transactions.
const Factory = preload("res://scripts/campaign/RegionalEnemyFactory.gd")
const RiftField = preload("res://scripts/world/RiftField.gd")
const Layout = preload("res://scripts/world/RiftArenaLayout.gd")
const Observer = preload("res://scripts/actors/RiftObserverBoss.gd")
var rift_field: Node2D
func bind_rift_field(field: Node2D) -> bool:
	if state!=State.IDLE or not is_instance_valid(field) or not field.is_inside_tree() or field.is_queued_for_deletion() or field.get_script()!=RiftField: return false
	if is_instance_valid(rift_field) and rift_field.tree_exiting.is_connected(_on_rift_departure): rift_field.tree_exiting.disconnect(_on_rift_departure)
	rift_field = field; rift_field.tree_exiting.connect(_on_rift_departure); return true
func _on_rift_departure() -> void: _fail("裂隙机关所有者离场")
func start_run(seed_value: int,target: PlayerBody,enemies: Node2D,projectiles: Node2D,portals: Node2D,build: BuildSystem,navigation: ArenaLayout) -> bool:
	if not is_instance_valid(rift_field) or not rift_field.is_inside_tree() or rift_field.is_queued_for_deletion() or rift_field.layout!=navigation: return false
	return super.start_run(seed_value,target,enemies,projectiles,portals,build,navigation)
func _chapter_number() -> int: return 6
func _boss_label() -> String: return "裂隙观测者 · 窄束 / 探针 / 折射"
func _boss_position() -> Vector2: return Layout.BOSS_CENTER
func _boss_available() -> bool: return true
func _create_boss_actor() -> Node: return Observer.new()
func _build_encounters() -> Array[Dictionary]:
	return [
		{"id":&"outer_calibration","name":"外沿校线","cutter":spawn_rng.randi_range(6,8),"elite":spawn_rng.randi_range(4,5),"rate":0.28},
		{"id":&"inner_cross_calibration","name":"内环交叉标定","cutter":spawn_rng.randi_range(8,10),"elite":spawn_rng.randi_range(6,7),"rate":0.26},
		{"id":&"four_sector_overload","name":"高风险：四区满载","cutter":spawn_rng.randi_range(12,14),"elite":spawn_rng.randi_range(9,11),"rate":0.24},
	]
func _encounter_kinds(encounter: Dictionary) -> Array[int]:
	var kinds: Array[int] = []
	for _count in encounter.cutter: kinds.append(EnemyScript.EnemyKind.SCRAPPER)
	for _count in encounter.elite: kinds.append(EnemyScript.EnemyKind.SPITTER)
	return kinds
func _create_enemy_actor(kind: int) -> Node:
	var role: String
	match kind:
		EnemyScript.EnemyKind.SCRAPPER: role = "space_cutter"
		EnemyScript.EnemyKind.SPITTER: role = "rift_elite"
		_: return null
	var actor := Factory.create_actor(6,role,encounter_index+6,projectile_parent,player)
	actor.world_bounds = world_bounds; return actor
func _on_run_started() -> void: rift_field.configure(arena_navigation,run_seed,player)
func _on_state_changed(next: State) -> void:
	if is_instance_valid(rift_field): rift_field.set_active(next==State.COMBAT,4 if encounter_index==2 else 2)
