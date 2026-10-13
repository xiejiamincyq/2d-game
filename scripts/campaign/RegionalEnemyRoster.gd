extends RefCounted
## Regional encounter membership: pending split births count before settlement.
## A chapter director still owns encounters/rewards/unlocks; this is not one.
signal enemy_defeated(actor: Node,coins: int,source: StringName)
signal cleared
signal cancelled(actor: Node)
const Grid = preload("res://scripts/components/EnemyNeighborGrid.gd")
var active: Array[Node] = []
var live: Array[Node] = []
var grid := Grid.new()
var failed := false
func register_actor(actor: Enemy) -> bool:
	if failed or not is_instance_valid(actor) or actor.death_resolved or actor.is_queued_for_deletion() or active.has(actor): return false
	active.append(actor)
	actor.died.connect(_on_defeated)
	actor.tree_exiting.connect(_on_removed.bind(actor),CONNECT_ONE_SHOT)
	if actor.is_inside_tree(): _on_ready(actor)
	else: actor.ready.connect(_on_ready.bind(actor),CONNECT_ONE_SHOT)
	if actor.has_signal("offspring_prepared"):
		actor.offspring_prepared.connect(_on_prepared.bind(actor))
		actor.birth_cancelled.connect(_on_removed)
	return true
func get_active_count() -> int: return active.size()
func get_neighbors(actor: Node2D) -> Array[Node]:
	grid.refresh(live,Engine.get_physics_frames())
	return grid.neighbors(actor)
func _on_ready(actor: Node) -> void:
	if not active.has(actor) or live.has(actor): return
	live.append(actor)
	grid.invalidate()
	actor.set_neighbor_provider(get_neighbors.bind(actor))
func _on_prepared(children: Array[CharacterBody2D],parent: Enemy) -> void:
	var accepted_parent: bool = active.has(parent) and parent.health.current_health<=0
	for child in children:
		if not accepted_parent or not register_actor(child):
			if is_instance_valid(child): child.queue_free()
func _on_defeated(actor: Node,coins: int,source: StringName) -> void:
	if not active.has(actor) or not actor.death_resolved or actor.health.current_health>0: return
	active.erase(actor)
	live.erase(actor)
	grid.invalidate()
	enemy_defeated.emit(actor,coins,source)
	if active.is_empty() and not failed: cleared.emit()
func _on_removed(actor: Node) -> void:
	if not active.has(actor): return
	active.erase(actor)
	live.erase(actor)
	grid.invalidate()
	failed = true # Removal without accepted death never counts as chapter success.
	cancelled.emit(actor)
