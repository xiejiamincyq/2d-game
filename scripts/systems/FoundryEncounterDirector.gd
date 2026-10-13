extends "res://scripts/systems/ChapterEncounterDirector.gd"
## Second-chapter encounter/heat policy and its actual native Furnace Boss.
const Factory = preload("res://scripts/campaign/RegionalEnemyFactory.gd")
const HeatField = preload("res://scripts/world/FoundryHeatField.gd")
const FurnaceBoss = preload("res://scripts/actors/FoundryFurnaceBoss.gd")
var heat_field: Node2D
func bind_heat_field(field: Node2D) -> bool:
	if state!=State.IDLE or not is_instance_valid(field) or not field.is_inside_tree() or field.get_script()!=HeatField: return false
	if is_instance_valid(heat_field) and heat_field.tree_exiting.is_connected(_on_heat_departure): heat_field.tree_exiting.disconnect(_on_heat_departure)
	heat_field = field
	heat_field.tree_exiting.connect(_on_heat_departure)
	return true
func _on_heat_departure() -> void: _fail("铸坊热区所有者离场")
func start_run(seed_value: int,target: PlayerBody,enemies: Node2D,projectiles: Node2D,portals: Node2D,build: BuildSystem,navigation: ArenaLayout) -> bool:
	if not is_instance_valid(heat_field) or not heat_field.is_inside_tree() or heat_field.layout!=navigation: return false
	return super.start_run(seed_value,target,enemies,projectiles,portals,build,navigation)
func _chapter_number() -> int: return 2
func _boss_label() -> String: return "炉心督工 · 短扇喷 / 冲撞 / 热喷口"
func _boss_position() -> Vector2: return Vector2(0,-660)
func _boss_available() -> bool: return true
func _create_boss_actor() -> Node: return FurnaceBoss.new()
func _on_boss_reinforcements_requested(owner: Node,count: int,count_limit: int = 8) -> void:
	if state!=State.BOSS or owner!=active_boss or boss_defeat_pending or boss_defeated_for_wave or count<=0 or not is_instance_valid(player): return
	count = mini(count,mini(3,maxi(0,count_limit)))
	if count==0: return
	var queues: Array[Array] = [[],[]]
	for index in count: queues[index%2].append(EnemyScript.EnemyKind.DASHER if index%2==0 else EnemyScript.EnemyKind.SPITTER)
	_open_portals_for_queues(queues)
func _build_encounters() -> Array[Dictionary]:
	return [
		{"id":&"slag_workshop","name":"废渣工位","dasher":spawn_rng.randi_range(14,18),"spitter":spawn_rng.randi_range(3,4),"rate":0.18},
		{"id":&"ember_conduits","name":"余烬管廊","dasher":spawn_rng.randi_range(18,22),"spitter":spawn_rng.randi_range(5,6),"rate":0.16},
		{"id":&"overheated_workshop","name":"高风险：过热工位","dasher":spawn_rng.randi_range(24,28),"spitter":spawn_rng.randi_range(8,9),"rate":0.12},
	]
func _encounter_kinds(encounter: Dictionary) -> Array[int]:
	var kinds: Array[int] = []
	for _count in encounter.dasher: kinds.append(EnemyScript.EnemyKind.DASHER)
	for _count in encounter.spitter: kinds.append(EnemyScript.EnemyKind.SPITTER)
	return kinds
func _create_enemy_actor(kind: int) -> Node:
	var role := "spark_gunner" if kind==EnemyScript.EnemyKind.SPITTER else "slag_charger"
	var actor := Factory.create_actor(2,role,encounter_index+2,projectile_parent,player)
	actor.world_bounds = world_bounds
	return actor
func _on_run_started() -> void:
	# Show all fixed sites in INTRO. Risk enables more, never materializes a new
	# vent under the player at the moment danger starts.
	heat_field.configure(arena_navigation,run_seed,player,16)
func _on_state_changed(next: State) -> void:
	if not is_instance_valid(heat_field): return
	heat_field.set_active(next==State.COMBAT,16 if encounter_index==2 else 10)
