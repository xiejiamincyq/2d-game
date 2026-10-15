extends "res://scripts/world/DestructibleObstacle.gd"
## The complete reservoir/lock footprint is opaque and genuinely impassable.
const Terrain = preload("res://scripts/world/TerrainSweep.gd")
const Art = preload("res://scripts/world/SaltPropArt.gd")
var obstacle_size := Vector2.ZERO
var obstacle_kind: StringName
var art: Node2D
var occlusion_rect := Rect2()
func setup(rect: Rect2,kind: StringName) -> void:
	set_layout_footprint(rect)
	name = "Salt_%s"%kind
	position = Vector2(rect.get_center().x,rect.end.y)
	obstacle_size = rect.size
	obstacle_kind = kind
	z_index = -90 if kind==&"reservoir" else 0 # Low water never sorts above actors.
	collision_layer = 1|Terrain.QUERY_LAYER
	collision_mask = 0
	add_to_group(&"arena_obstacles")
	var collider := CollisionShape2D.new()
	collider.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collider.shape = shape
	collider.position.y = -rect.size.y/2
	add_child(collider)
	art = Art.new()
	art.name = "Art"
	art.configure(rect.size,kind)
	add_child(art)
	occlusion_rect = Rect2(Vector2(-rect.size.x/2,-rect.size.y-26),rect.size+Vector2(0,26))
	queue_redraw()
func update_player_occlusion(player_position: Vector2,active: bool,delta: float) -> void:
	if obstacle_kind!=&"sluice_wall": return
	var local := to_local(player_position)
	var covered := active and local.y<0 and occlusion_rect.intersects(Rect2(local-Vector2(42,42),Vector2(84,84)))
	art.modulate.a = move_toward(art.modulate.a,0.32 if covered else 1,maxf(0,delta)*5)
func _draw() -> void:
	var base := Rect2(Vector2(-obstacle_size.x/2,-obstacle_size.y),obstacle_size)
	draw_rect(base,Color("394f56") if obstacle_kind==&"reservoir" else Color("697674"))
	draw_rect(base,Color("171f25"),false,4)
	if obstacle_kind==&"reservoir":
		draw_rect(base.grow(-7),Color("728780"),false,3)
		draw_line(base.position+Vector2(8,7),Vector2(base.end.x-8,base.position.y+7),Color("a1aa96"),3)
