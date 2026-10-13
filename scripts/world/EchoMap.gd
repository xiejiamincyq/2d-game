extends Node2D
const Backdrop = preload("res://scripts/world/ChapterMapBackdrop.gd")
## Fifth-region map and dormant beat field. Encounter/readiness remain separate gates.
@export var map_seed: int = 0
@onready var layout = $Layout
@onready var floor_view = $Floor
@onready var echo_field = $EchoField
func _ready() -> void: generate_map(map_seed)
func generate_map(seed_value: int) -> void:
	map_seed = seed_value; layout.generate_map(seed_value)
	floor_view.configure(layout.world_bounds,seed_value,layout.get_ring_profiles(),layout.get_gateways(),layout.get_echo_sites())
	echo_field.configure(layout,seed_value)
	Backdrop.install(self,layout.world_bounds,5)
