extends Node2D
const Backdrop = preload("res://scripts/world/ChapterMapBackdrop.gd")
## Sixth map owns dormant faults; only an encounter director may activate them.
@export var map_seed: int = 0
@onready var layout = $Layout
@onready var floor_view = $Floor
@onready var rift_field = $RiftField
func _ready() -> void: generate_map(map_seed)
func generate_map(seed_value: int) -> void:
	rift_field.clear()
	map_seed = seed_value; layout.generate_map(seed_value)
	floor_view.configure(layout.world_bounds,layout.get_islands(),layout.get_bypass_routes())
	rift_field.configure(layout,seed_value)
	Backdrop.install(self,layout.world_bounds,6)
