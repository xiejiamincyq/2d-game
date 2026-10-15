extends Area2D
## Destructible incubation pod: encounter birth debt, never a loot-bearing enemy.
signal hatch_requested(plant: Node)
signal retired
const Health = preload("res://scripts/components/HealthComponent.gd")
const INK := Color("1c2926")
const PAPER := Color("d6c8a4")
const SPORE := Color("93a16d")
const AMBER := Color("c4a166")
var target_player: Node2D
var health: HealthComponent
var body_radius := 9.0
var age := 0.0
var resolved := false
const HATCH_SECONDS := 3.0
var chapter_owned := false
var difficulty_index := 0
var hatch_pending := false
var hatch_retry_remaining := 0.0
func complete_placement(actor_ref: WeakRef,container_ref: WeakRef,at: Vector2) -> void:
	if is_queued_for_deletion(): return
	var actor = actor_ref.get_ref()
	var container = container_ref.get_ref()
	if not is_instance_valid(actor) or not is_instance_valid(container) or not container.is_inside_tree() or container.is_queued_for_deletion() or not actor.can_commit_plant(at):
		disarm()
		return
	position = container.to_local(at)
	container.add_child(self)
func _ready() -> void:
	add_to_group("enemies") # Existing shots/lasers can break it; no loot/death signal.
	add_to_group("capsule_plants")
	collision_layer = 1
	collision_mask = 0
	monitoring = false
	monitorable = true
	health = Health.new()
	health.max_health = 16
	add_child(health)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = body_radius
	shape.shape = circle
	add_child(shape)
	z_as_relative = false
	z_index = -1
func _physics_process(delta: float) -> void:
	if resolved or not is_finite(delta) or delta<0: return
	age += delta
	hatch_retry_remaining = maxf(0,hatch_retry_remaining-delta)
	queue_redraw()
	if age<HATCH_SECONDS or hatch_pending or hatch_retry_remaining>0: return
	hatch_pending = true # Reserve once before publishing/deferred physics work.
	if chapter_owned: hatch_requested.emit(self)
	else: disarm() # An orphan has no authority to manufacture an enemy.
func defer_hatch() -> void:
	if resolved: return
	hatch_pending = false
	hatch_retry_remaining = 0.25 # Bounded safety queries, never a per-frame burst.
func _exit_tree() -> void:
	disarm() # Removal revokes birth authority even if an owner later reinserts it.
func take_damage(amount: float,_source: StringName = &"generic",_direction: Vector2 = Vector2.ZERO) -> bool:
	if resolved or not is_finite(amount) or amount<=0: return false
	health.damage(amount,true)
	queue_redraw()
	if health.current_health<=0:
		disarm()
		return true
	return false
func disarm() -> void:
	if resolved: return
	resolved = true
	remove_from_group("enemies")
	remove_from_group("capsule_plants")
	retired.emit()
	queue_free() # Safe even from physics query callbacks.
func _draw() -> void:
	if resolved: return
	var sprout := clampf(age/0.55,0,1)
	# A compact countdown, not a damaging ground disk.
	for index in 3:
		var angle := index*TAU/3
		draw_arc(Vector2.ZERO,13,angle,angle+PI*0.42,10,INK,3,true)
		draw_arc(Vector2.ZERO,13,angle,angle+PI*0.42,10,SPORE,1.5,true)
	draw_circle(Vector2.ZERO,11,INK)
	draw_colored_polygon(PackedVector2Array([Vector2(-7,5),Vector2(-9,-3),Vector2(-4,-9),Vector2(4,-9),Vector2(9,-3),Vector2(7,5),Vector2(0,8)]),SPORE)
	draw_line(Vector2(0,6),Vector2(0,-7),INK,2,true)
	for side in [-1,1]:
		var tip := Vector2(side*(7+3*sprout),-7-5*sprout)
		draw_line(Vector2(0,-2),tip,INK,4,true)
		draw_line(Vector2(0,-2),tip,PAPER,2,true)
		draw_circle(tip,3,INK)
		draw_circle(tip,1.5,AMBER)
	draw_rect(Rect2(-10,-23,20,4),INK)
	draw_rect(Rect2(-9,-22,18*health.current_health/16,2),PAPER)
	draw_rect(Rect2(-10,-29,20,4),INK)
	draw_rect(Rect2(-9,-28,18*clampf(age/HATCH_SECONDS,0,1),2),AMBER)
