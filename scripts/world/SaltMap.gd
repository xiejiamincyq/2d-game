extends Node2D
const Backdrop = preload("res://scripts/world/ChapterMapBackdrop.gd")
## Third-region map-only assembly; no readiness, hazard or victory fabrication.
@export var map_seed: int = 0
@onready var layout = $Layout
@onready var floor_view = $Floor
@onready var tidal_field = $TidalField
func _ready() -> void: generate_map(map_seed)
func generate_map(seed_value: int) -> void:
	map_seed = seed_value
	tidal_field.set_active(false)
	layout.generate_map(seed_value)
	floor_view.configure(layout.world_bounds,seed_value,layout.get_obstacle_descriptors(),layout.get_causeways())
	tidal_field.configure(layout,seed_value)
	Backdrop.install(self,layout.world_bounds,3)
