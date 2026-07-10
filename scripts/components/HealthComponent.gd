extends Node
class_name HealthComponent

signal health_changed(current: float, maximum: float)
signal died

@export var max_health: float = 10.0
var current_health: float
var invulnerable_time: float = 0.0

func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)

func _process(delta: float) -> void:
	if invulnerable_time > 0.0:
		invulnerable_time = maxf(0.0, invulnerable_time - delta)

func damage(amount: float) -> void:
	if amount <= 0.0 or invulnerable_time > 0.0 or current_health <= 0.0:
		return
	current_health = maxf(0.0, current_health - amount)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		died.emit()

func heal(amount: float) -> void:
	if amount <= 0.0 or current_health <= 0.0:
		return
	current_health = minf(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)

func increase_max(amount: float) -> void:
	if amount <= 0.0:
		return
	max_health += amount
	current_health += amount
	health_changed.emit(current_health, max_health)

func set_invulnerable(seconds: float) -> void:
	invulnerable_time = maxf(invulnerable_time, seconds)
