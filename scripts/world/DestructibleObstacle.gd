extends StaticBody2D
## Six-region building authority, separate from combat enemy/loot membership.
const Health = preload("res://scripts/components/HealthComponent.gd")
const DamageView=preload("res://scripts/world/BuildingDamageView.gd")
const Debris=preload("res://scripts/effects/CombatVfx.gd")
var health: HealthComponent
var damage_feedback: Node2D
var destroyed := false
var _layout_footprint := Rect2()

func set_layout_footprint(rect: Rect2) -> void:
	_layout_footprint = rect # Preserve generator bytes; never reconstruct from rounded pivot.

func _ready() -> void:
	health = Health.new()
	health.max_health = clampf(_layout_footprint.get_area()/60.0,160.0,600.0)
	add_child(health)
	health.health_changed.connect(_on_health_changed)
	add_to_group(&"destructible_terrain")

func _on_health_changed(current: float,maximum: float) -> void:
	if destroyed or is_queued_for_deletion() or not is_inside_tree(): return
	if not is_instance_valid(damage_feedback) and current>0 and current<maximum:
		damage_feedback=DamageView.new(); damage_feedback.name="DamageFeedback"
		damage_feedback.configure(self); add_child(damage_feedback)
	# Child entry can reenter Health before its visual's _ready completes.
	# Never republish the outer signal's stale HP or a cancelled receiver.
	if destroyed or is_queued_for_deletion() or not is_inside_tree(): return
	if is_instance_valid(damage_feedback) and damage_feedback.get_parent()==self:
		damage_feedback.refresh(health.current_health,health.max_health)

func _spawn_break_effect(direction: Vector2) -> void:
	var layout:=get_parent()
	var host:=layout.get_parent() if layout.has_method("remove_destroyed_obstacle") else layout
	if not host is Node2D or host.is_queued_for_deletion(): return
	var vfx:=host.get_node_or_null("TerrainDebris")
	if vfx==null:
		vfx=Debris.new(); vfx.name="TerrainDebris"; host.add_child(vfx)
	var at: Vector2=get_node("CollisionShape2D").global_position
	for side in [-1,1]: vfx.request_effect(&"debris",at,Vector2(side,-0.4)+direction*0.3,0.65)

func get_damage_rect() -> Rect2:
	var collider := get_node("CollisionShape2D") as CollisionShape2D
	var shape := collider.shape as RectangleShape2D
	return Rect2(collider.global_position-shape.size/2,shape.size)

func get_damage_center() -> Vector2:
	return get_damage_rect().get_center()

func take_damage(amount: float,_source: StringName = &"generic",_direction: Vector2 = Vector2.ZERO) -> bool:
	if destroyed or health==null or not is_finite(amount) or amount<=0: return false
	health.damage(amount,true)
	# Health signals are synchronous; a listener may already retire this body.
	if destroyed or is_queued_for_deletion(): return false
	if health.current_health>0: return false
	destroyed = true # Reserve before navigation/callbacks can reenter damage.
	collision_layer = 0
	get_node("CollisionShape2D").set_deferred("disabled",true)
	remove_from_group(&"destructible_terrain")
	remove_from_group(&"arena_obstacles")
	_spawn_break_effect(_direction)
	var layout := get_parent()
	if layout!=null and layout.has_method("remove_destroyed_obstacle"):
		layout.remove_destroyed_obstacle(self,_layout_footprint)
	hide()
	queue_free()
	return true
