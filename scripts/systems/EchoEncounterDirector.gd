extends "res://scripts/systems/ChapterEncounterDirector.gd"
## Fifth-region mixed encounters and verified native priest combat owner.
const Factory = preload("res://scripts/campaign/RegionalEnemyFactory.gd")
const EchoField = preload("res://scripts/world/ReusableTrapField.gd")
const BellPriest = preload("res://scripts/actors/EchoBellPriestBoss.gd")
const Layout = preload("res://scripts/world/EchoArenaLayout.gd")
var echo_field: Node2D
func bind_echo_field(field: Node2D) -> bool:
	if state!=State.IDLE or not is_instance_valid(field) or not field.is_inside_tree() or field.is_queued_for_deletion() or field.get_script()!=EchoField: return false
	if is_instance_valid(echo_field) and echo_field.tree_exiting.is_connected(_on_echo_departure): echo_field.tree_exiting.disconnect(_on_echo_departure)
	echo_field = field; echo_field.tree_exiting.connect(_on_echo_departure); return true
func _on_echo_departure() -> void: _fail("回声钟座所有者离场")
func start_run(seed_value: int,target: PlayerBody,enemies: Node2D,projectiles: Node2D,portals: Node2D,build: BuildSystem,navigation: ArenaLayout) -> bool:
	if not is_instance_valid(echo_field) or not echo_field.is_inside_tree() or echo_field.is_queued_for_deletion() or echo_field.layout!=navigation: return false
	return super.start_run(seed_value,target,enemies,projectiles,portals,build,navigation)
func _chapter_number() -> int: return 5
func _boss_label() -> String: return "钟骨司祭 · 钟槌 / 双坠 / 冠钟"
func _boss_position() -> Vector2: return Layout.BOSS_CENTER
func _boss_available() -> bool: return true
func _create_boss_actor() -> Node: return BellPriest.new()
func _build_encounters() -> Array[Dictionary]:
	return [
		{"id":&"outer_bell_walk","name":"外环巡钟","sentinel":spawn_rng.randi_range(4,5),"shade":spawn_rng.randi_range(6,8),"rate":0.26},
		{"id":&"inner_shadow_court","name":"内庭错步","sentinel":spawn_rng.randi_range(7,9),"shade":spawn_rng.randi_range(8,10),"rate":0.24},
		{"id":&"four_bell_detour","name":"高风险：四钟余拍","sentinel":spawn_rng.randi_range(9,11),"shade":spawn_rng.randi_range(12,14),"rate":0.22},
	]
func _encounter_kinds(encounter: Dictionary) -> Array[int]:
	var kinds: Array[int] = []
	for _count in encounter.sentinel: kinds.append(EnemyScript.EnemyKind.SPITTER)
	for _count in encounter.shade: kinds.append(EnemyScript.EnemyKind.SCRAPPER)
	return kinds
func _create_chapter_enemy_actor(kind: int) -> Node:
	var role: String
	match kind:
		EnemyScript.EnemyKind.SPITTER: role = "echo_sentinel"
		EnemyScript.EnemyKind.SCRAPPER: role = "circling_shade"
		_: return null
	var actor := Factory.create_actor(5,role,encounter_index+5,projectile_parent,player)
	actor.world_bounds = world_bounds; return actor
func _on_run_started() -> void: echo_field.configure(arena_navigation,run_seed,player)
func _on_state_changed(next: State) -> void:
	if is_instance_valid(echo_field): echo_field.set_active(next==State.COMBAT,4 if encounter_index==2 else 2)
