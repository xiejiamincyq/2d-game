extends Node2D
const Backdrop = preload("res://scripts/world/ChapterMapBackdrop.gd")
## Editable chapter map assembly. Caller assigns a fresh run seed before adding.

@export var map_seed: int = 0
@onready var layout = $Layout
@onready var floor_view = $Floor
@onready var trap_field = $TrapField

func _ready() -> void:
	layout.obstacle_destroyed.connect(floor_view.release_obstacle)
	generate_map(map_seed)

func generate_map(seed_value: int) -> void:
	map_seed = seed_value
	layout.generate_map(seed_value)
	floor_view.configure(layout.world_bounds, seed_value, layout.get_obstacle_descriptors())
	trap_field.configure(layout,seed_value)
	Backdrop.install(self,layout.world_bounds,1)
