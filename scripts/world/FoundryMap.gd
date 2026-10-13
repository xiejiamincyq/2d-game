extends Node2D
const Backdrop = preload("res://scripts/world/ChapterMapBackdrop.gd")
## Distinct second chapter assembly. Readiness belongs to the campaign, not this map.
@export var map_seed: int = 0
@onready var layout = $Layout
@onready var floor_view = $Floor
@onready var heat_field = $HeatField
func _ready() -> void: generate_map(map_seed)
func generate_map(seed_value: int) -> void:
	map_seed = seed_value
	layout.generate_map(seed_value)
	floor_view.configure(layout.world_bounds,seed_value,layout.get_obstacle_descriptors())
	heat_field.configure(layout,seed_value)
	Backdrop.install(self,layout.world_bounds,2)
