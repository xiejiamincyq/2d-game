extends "res://scripts/components/ArchivePageProjectile.gd"
## Canonical bounded sweep only; original opaque copper note, not page artwork.
var linked_target: WeakRef
var note_attempt: Dictionary = {}
func _init() -> void:
	super._init()
	radius = 4; damage = 6.0*3.0; lifetime = 1.05
	velocity = Vector2(440,0); damage_source = &"bell_priest_crown"
func set_target(target: Node2D,attempt: Dictionary = {}) -> void:
	linked_target = weakref(target); note_attempt = attempt
	if not note_attempt.has("attempted"): note_attempt.attempted = false
func _target_alive() -> bool:
	if linked_target==null: return false
	var target = linked_target.get_ref()
	return is_instance_valid(target) and target.is_inside_tree() and not target.is_queued_for_deletion() and target.health.current_health>0 and not target.is_stealthed()
func _physics_process(delta: float) -> void:
	if is_queued_for_deletion() or not is_finite(delta) or delta<=0: return
	if not _target_alive(): cancel(); return
	if source_actor!=null:
		var actor = source_actor.get_ref()
		if is_instance_valid(actor) and actor.get("death_resolved")==true: cancel(); return
	super._physics_process(delta)
func _try_hit(node: Node) -> void:
	if is_queued_for_deletion(): return
	if not _target_alive() or note_attempt.attempted: cancel(); return
	if node!=linked_target.get_ref(): return
	note_attempt.attempted = true # One attempt per note, before damage callbacks.
	super._try_hit(node)
func _draw() -> void:
	draw_set_transform(Vector2.ZERO,velocity.angle(),Vector2.ONE)
	var hull := PackedVector2Array([Vector2(-7,-3),Vector2(3,-3),Vector2(7,0),Vector2(3,3),Vector2(-7,3),Vector2(-4,0)])
	var core := PackedVector2Array([Vector2(-4,-1.5),Vector2(2,-1.5),Vector2(5,0),Vector2(2,1.5),Vector2(-4,1.5)])
	draw_colored_polygon(hull,Color("292435")); draw_colored_polygon(core,Color("b79361"))
	draw_line(Vector2(-2,0),Vector2(3,0),Color("ed8877"),1)
