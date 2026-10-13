extends "res://scripts/systems/ChapterEncounterDirector.gd"
## Salt causeway encounters; chapter readiness waits for its real Boss and run.
const Factory = preload("res://scripts/campaign/RegionalEnemyFactory.gd")
const TidalField = preload("res://scripts/world/SaltTidalField.gd")
const TideBoss = preload("res://scripts/actors/SaltTideBoss.gd")
var tidal_field: Node2D
func bind_tidal_field(field: Node2D) -> bool:
	if state!=State.IDLE or not is_instance_valid(field) or not field.is_inside_tree() or field.get_script()!=TidalField: return false
	if is_instance_valid(tidal_field) and tidal_field.tree_exiting.is_connected(_on_tidal_departure): tidal_field.tree_exiting.disconnect(_on_tidal_departure)
	tidal_field = field
	tidal_field.tree_exiting.connect(_on_tidal_departure)
	return true
func _on_tidal_departure() -> void: _fail("盐蚀潮带所有者离场")
func start_run(seed_value: int,target: PlayerBody,enemies: Node2D,projectiles: Node2D,portals: Node2D,build: BuildSystem,navigation: ArenaLayout) -> bool:
	if not is_instance_valid(tidal_field) or not tidal_field.is_inside_tree() or tidal_field.layout!=navigation: return false
	return super.start_run(seed_value,target,enemies,projectiles,portals,build,navigation)
func _chapter_number() -> int: return 3
func _boss_label() -> String: return "潮壳巨兽 · 空心环潮 / 侧钳横扫 / 盐壳喷射"
func _boss_position() -> Vector2: return Vector2(0,-672)
func _boss_available() -> bool: return true
func _create_boss_actor() -> Node: return TideBoss.new()
func _on_boss_reinforcements_requested(owner: Node,count: int,count_limit: int = 8) -> void:
	if state!=State.BOSS or owner!=active_boss or boss_defeat_pending or boss_defeated_for_wave or count<=0 or not is_instance_valid(player): return
	count = mini(count,mini(3,maxi(0,count_limit)))
	if count==0: return
	var queues: Array[Array] = [[],[]]
	for index in count: queues[index%2].append(EnemyScript.EnemyKind.SCRAPPER if index%2==0 else EnemyScript.EnemyKind.MARKSMAN)
	_open_portals_for_queues(queues)
func _build_encounters() -> Array[Dictionary]:
	return [
		{"id":&"salt_locks","name":"盐蚀闸口","crab":spawn_rng.randi_range(10,14),"needle":spawn_rng.randi_range(4,5),"rate":0.20},
		{"id":&"crossing_causeways","name":"交错堤道","crab":spawn_rng.randi_range(14,18),"needle":spawn_rng.randi_range(6,8),"rate":0.18},
		{"id":&"flooded_causeways","name":"高风险：四堤涨潮","crab":spawn_rng.randi_range(18,22),"needle":spawn_rng.randi_range(9,11),"rate":0.15},
	]
func _encounter_kinds(encounter: Dictionary) -> Array[int]:
	var kinds: Array[int] = []
	for _count in encounter.crab: kinds.append(EnemyScript.EnemyKind.SCRAPPER)
	for _count in encounter.needle: kinds.append(EnemyScript.EnemyKind.MARKSMAN)
	return kinds
func _create_enemy_actor(kind: int) -> Node:
	var role: String
	match kind:
		EnemyScript.EnemyKind.SCRAPPER: role = "flanking_crab"
		EnemyScript.EnemyKind.MARKSMAN: role = "salt_needle"
		_: return null
	var actor := Factory.create_actor(3,role,encounter_index+3,projectile_parent,player)
	actor.world_bounds = world_bounds
	return actor
func _on_run_started() -> void:
	# All four sites exist in INTRO; risk changes only which ones are enabled.
	tidal_field.configure(arena_navigation,run_seed,player)
func _on_state_changed(next: State) -> void:
	if is_instance_valid(tidal_field): tidal_field.set_active(next==State.COMBAT,4 if encounter_index==2 else 2)
