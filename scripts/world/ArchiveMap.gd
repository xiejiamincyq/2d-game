extends Node2D
const Backdrop = preload("res://scripts/world/ChapterMapBackdrop.gd")
## Fourth-region map and dormant field. Encounters/readiness remain separate.
@export var map_seed: int = 0
@onready var layout = $Layout
@onready var floor_view = $Floor
@onready var spore_field = $SporeField
func _ready() -> void: generate_map(map_seed)
func generate_map(seed_value: int) -> void:
	spore_field.clear()
	map_seed = seed_value; layout.generate_map(seed_value)
	floor_view.configure(layout.world_bounds,seed_value,layout.get_chambers(),layout.get_doorways())
	spore_field.configure(layout,seed_value)
	Backdrop.install(self,layout.world_bounds,4)
