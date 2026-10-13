extends StaticBody2D
## Opaque physical base; only the original elevated art layer can fade.
const TerrainSweep = preload("res://scripts/world/TerrainSweep.gd")
const PropArt = preload("res://scripts/world/RiftPropArt.gd")
var kind := &"scope_bench"
var footprint := Vector2(160,112)
var occlusion_rect := Rect2()
var prop_art: Node2D
func setup(rect: Rect2,value: StringName) -> void:
	kind = value; footprint = rect.size
	position = Vector2(rect.get_center().x,rect.end.y)
	collision_layer = 1|TerrainSweep.QUERY_LAYER; collision_mask = 0
	add_to_group(&"arena_obstacles")
	var collider := CollisionShape2D.new(); collider.name = "CollisionShape2D"
	var shape := RectangleShape2D.new(); shape.size = footprint
	collider.shape = shape; collider.position = Vector2(0,-footprint.y/2)
	add_child(collider); queue_redraw()
	prop_art = PropArt.new(); prop_art.name = "PropArt"
	prop_art.configure(footprint,kind); occlusion_rect = prop_art.get_visual_bounds()
	add_child(prop_art)
func _draw() -> void:
	var rect := Rect2(Vector2(-footprint.x/2,-footprint.y),footprint)
	draw_rect(rect,Color("292d39"),true)
	draw_rect(rect.grow(-3),Color("454856"),false,2)
func update_player_occlusion(point: Vector2,active: bool,delta: float) -> void:
	var local := to_local(point)
	var overlap := active and local.y<0 and occlusion_rect.intersects(Rect2(local-Vector2(42,42),Vector2(84,84)))
	prop_art.modulate.a = move_toward(prop_art.modulate.a,0.32 if overlap else 1.0,maxf(0,delta)*9)
