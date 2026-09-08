extends StaticBody2D
class_name ArenaObstacle

const PROP_ATLAS = preload("res://assets/art/environment/mint_farm_props_b_packed_v1.png")
const PROP_REGIONS := {
	&"planter": Rect2(8, 8, 511, 277),
	&"greenhouse": Rect2(552, 8, 487, 426),
	&"tank": Rect2(8, 552, 431, 463),
	&"pipe": Rect2(552, 552, 523, 305),
}
const ALPHA_SHADER = preload("res://assets/art/environment/prop_alpha.gdshader")

var obstacle_size := Vector2(160.0, 100.0)
var obstacle_kind: StringName = &"planter"
var occlusion_rect := Rect2()
var plinth_style: StyleBoxFlat

func update_player_occlusion(player_position: Vector2, active: bool, delta: float) -> void:
	# Only fade a foreground obstacle overlapping the player's 84px visual,
	# never the player itself. Retain enough opacity to read the solid footprint.
	var local_player := to_local(player_position)
	var player_rect := Rect2(local_player - Vector2(42, 42), Vector2(84, 84))
	var in_front := local_player.y < 0.0
	var covers_player := active and in_front and occlusion_rect.intersects(player_rect)
	modulate.a = move_toward(modulate.a, 0.32 if covers_player else 1.0, maxf(delta, 0.0) * 5.0)

func setup(rect: Rect2, kind: StringName) -> void:
	name = "ArenaObstacle_%s" % kind
	# Sort at the front contact edge; keep the original world-space collider.
	position = Vector2(rect.get_center().x, rect.end.y)
	obstacle_size = rect.size
	obstacle_kind = kind
	collision_layer = 1
	collision_mask = 0
	add_to_group(&"arena_obstacles")
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = obstacle_size
	collision.shape = shape
	collision.position.y = -obstacle_size.y * 0.5
	add_child(collision)

	var atlas := AtlasTexture.new()
	atlas.atlas = PROP_ATLAS
	atlas.region = PROP_REGIONS.get(kind, PROP_REGIONS[&"planter"])
	atlas.filter_clip = true
	var art := Sprite2D.new()
	art.name = "Art"
	art.texture = atlas
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	art.scale = Vector2.ONE * (obstacle_size.x / atlas.region.size.x)
	art.position.y = -atlas.region.size.y * art.scale.y * 0.5
	var art_size := atlas.region.size * art.scale
	var height := maxf(obstacle_size.y, art_size.y)
	occlusion_rect = Rect2(Vector2(-obstacle_size.x * 0.5, -height), Vector2(obstacle_size.x, height))
	var alpha_material := ShaderMaterial.new()
	alpha_material.shader = ALPHA_SHADER
	art.material = alpha_material
	add_child(art)
	plinth_style = StyleBoxFlat.new()
	plinth_style.bg_color = Color("756c50") if kind == &"planter" else Color("c5cebb")
	plinth_style.border_color = Color("d8d7bc")
	plinth_style.set_border_width_all(5)
	plinth_style.set_corner_radius_all(5)
	plinth_style.anti_aliasing = true
	queue_redraw()

func _draw() -> void:
	var footprint := Rect2(Vector2(-obstacle_size.x * 0.5, -obstacle_size.y), obstacle_size)
	draw_rect(Rect2(footprint.position + Vector2(3, 5), footprint.size), Color(0.09, 0.17, 0.15, 0.22))
	# The full solid footprint stays visible; the planter's exposed strip is soil,
	# not an empty slab. Small rounded corners do not change its collider.
	if plinth_style != null:
		draw_style_box(plinth_style, footprint)
	if obstacle_kind == &"planter":
		for x in [-0.28, 0.0, 0.28]:
			var center := Vector2(obstacle_size.x * x, -obstacle_size.y + 15.0)
			draw_line(center - Vector2(9, 0), center + Vector2(9, 0), Color("5d624b"), 2.0, true)
