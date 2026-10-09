extends Node2D
## Editable chapter map assembly. Caller assigns a fresh run seed before adding.

@export var map_seed: int = 0
@onready var layout = $Layout
@onready var floor_view = $Floor

func _ready() -> void:
	generate_map(map_seed)

func generate_map(seed_value: int) -> void:
	map_seed = seed_value
	layout.generate_map(seed_value)
	floor_view.configure(layout.world_bounds, seed_value, layout.get_obstacle_descriptors())
