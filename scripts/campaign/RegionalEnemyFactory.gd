extends RefCounted
## Closed mapping of implemented roles; readiness remains a chapter-level gate.
const BaseEnemy = preload("res://scripts/actors/Enemy.gd")
const SparkEnemy = preload("res://scripts/actors/EmberSparkEnemy.gd")
const CrabEnemy = preload("res://scripts/actors/FlankingCrabEnemy.gd")
const MoteEnemy = preload("res://scripts/actors/SplittingMoteEnemy.gd")
const PlanterEnemy = preload("res://scripts/actors/CapsulePlanterEnemy.gd")
const SentinelEnemy = preload("res://scripts/actors/EchoSentinelEnemy.gd")
const ShadeEnemy = preload("res://scripts/actors/CirclingShadeEnemy.gd")
const EliteEnemy = preload("res://scripts/actors/RiftEliteEnemy.gd")
const CutterEnemy = preload("res://scripts/actors/SpaceCutterEnemy.gd")
static func create_actor(chapter: int,role: String,wave: int,shots: Node,target: Node2D = null) -> CharacterBody2D:
	var actor: CharacterBody2D
	var kind := BaseEnemy.EnemyKind.SCRAPPER
	match [chapter,role]:
		[1,"root_pursuer"]: actor = BaseEnemy.new()
		[1,"spore_spitter"]:
			actor = BaseEnemy.new()
			kind = BaseEnemy.EnemyKind.SPITTER
		[2,"slag_charger"]:
			actor = BaseEnemy.new()
			kind = BaseEnemy.EnemyKind.DASHER
		[2,"spark_gunner"]:
			actor = SparkEnemy.new()
			kind = BaseEnemy.EnemyKind.SPITTER
		[3,"flanking_crab"]: actor = CrabEnemy.new()
		[3,"salt_needle"]:
			actor = BaseEnemy.new()
			kind = BaseEnemy.EnemyKind.MARKSMAN
		[4,"splitting_mote"]: actor = MoteEnemy.new()
		[4,"capsule_planter"]: actor = PlanterEnemy.new()
		[5,"echo_sentinel"]: actor = SentinelEnemy.new()
		[5,"circling_shade"]: actor = ShadeEnemy.new()
		[6,"rift_elite"]: actor = EliteEnemy.new()
		[6,"space_cutter"]: actor = CutterEnemy.new()
		_: return null
	actor.setup(kind,wave,shots,target)
	return actor
