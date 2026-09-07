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
	var alpha_material := ShaderMaterial.new()
	alpha_material.shader = ALPHA_SHADER
	art.material = alpha_material
	add_child(art)
	queue_redraw()

func _draw() -> void:
	var footprint := Rect2(Vector2(-obstacle_size.x * 0.5, -obstacle_size.y), obstacle_size)
	draw_rect(Rect2(footprint.position + Vector2(3, 5), footprint.size), Color(0.09, 0.17, 0.15, 0.22))
	# The plinth explicitly marks all solid area, including behind short props.
	draw_rect(footprint, Color("c5cebb"))
	draw_rect(footprint, Color("66867b"), false, 2.0)
