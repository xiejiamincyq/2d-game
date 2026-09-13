extends Sprite2D

const OUTLINE_SHADER = preload("res://assets/art/shaders/player_occlusion_outline.gdshader")
const OUTLINE_Z_INDEX := 21

var player: Node2D
var enemies: Node2D
var obstacles: Node2D
var cardinal := -1

func setup(target: Node2D, enemy_container: Node2D, obstacle_container: Node2D) -> void:
	name = "PlayerOcclusionOutline"
	player = target
	enemies = enemy_container
	obstacles = obstacle_container
	texture = AtlasTexture.new()
	texture.atlas = player.player_body_texture
	texture.filter_clip = true
	scale = player.CHIBI_BODY_DRAW_SIZE / player.CHIBI_CARDINAL_CELL_SIZE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	material = ShaderMaterial.new()
	material.shader = OUTLINE_SHADER
	material.set_shader_parameter("outline_atlas", player.player_body_texture)
	# Game-over may pause processing in the same frame as the death signal.
	player.health.died.connect(hide)
	# Only the contour crosses actors; the body keeps normal world y-sorting.
	z_index = OUTLINE_Z_INDEX
	visible = false
	_process(0.0)

func _process(_delta: float) -> void:
	visible = false
	if not is_instance_valid(player) or not is_instance_valid(enemies) or texture == null:
		return
	if not player.is_visible_in_tree() or player.is_queued_for_deletion() or player.entrance_active or player.is_stealthed():
		return
	if player.health == null or player.health.current_health <= 0.0:
		return
	position = player.get_body_visual_center()
	var facing: int = player.chibi_cardinal_index(player.gun_angle)
	if facing != cardinal:
		cardinal = facing
		texture.region = player.chibi_cardinal_rect(cardinal)
		var size: Vector2 = texture.atlas.get_size()
		var rect: Rect2 = texture.region
		material.set_shader_parameter("region", Vector4(rect.position.x / size.x, rect.position.y / size.y, rect.end.x / size.x, rect.end.y / size.y))
	var body := Rect2(global_position - player.CHIBI_BODY_DRAW_SIZE * 0.5, player.CHIBI_BODY_DRAW_SIZE)
	# Terrain occlusion retains its own existing fade policy; never draw through it.
	if is_instance_valid(obstacles):
		for obstacle in obstacles.get_children():
			if not obstacle.is_queued_for_deletion() and obstacle.is_visible_in_tree() and obstacle.global_position.y > player.global_position.y:
				if (obstacle.global_transform * obstacle.occlusion_rect).intersects(body):
					return
	for enemy in enemies.get_children():
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or not enemy.is_visible_in_tree():
			continue
		# Bosses use a separate renderer and are not static-art occluders.
		if not "static_visual" in enemy or enemy.static_visual == null:
			continue
		if enemy.global_position.y <= player.global_position.y:
			continue
		var art: Sprite2D = enemy.static_visual
		if art.is_visible_in_tree() and (art.global_transform * art.get_rect()).intersects(body):
			visible = true
			return
