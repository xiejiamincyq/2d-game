extends Sprite2D

const OUTLINE_SHADER = preload("res://assets/art/shaders/player_native_outline.gdshader")
const MASK_ACTOR = preload("res://scenes/actors/native/player_paper_v1.tscn")
const OUTLINE_Z_INDEX := 21

var player: Node2D
var enemies: Node2D
var obstacles: Node2D
var mask_viewport: SubViewport
var mask_actor: Node2D

func setup(target: Node2D, enemy_container: Node2D, obstacle_container: Node2D) -> void:
	name = "PlayerOcclusionOutline"
	player = target
	enemies = enemy_container
	obstacles = obstacle_container
	# A small on-demand native silhouette, not an old atlas or a CPU readback.
	mask_viewport = SubViewport.new()
	mask_viewport.name = "NativeSilhouette"
	mask_viewport.size = Vector2i(128, 128)
	mask_viewport.transparent_bg = true
	mask_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(mask_viewport)
	mask_actor = MASK_ACTOR.instantiate()
	mask_actor.position = Vector2(64, 76)
	mask_actor.scale = player.native_visual.scale
	mask_viewport.add_child(mask_actor)
	for direction in mask_actor.DIRECTIONS:
		mask_actor.get_node(direction + "/Skeleton2D/Torso/ArmR/ForearmR/HandR/Weapon").hide()
	texture = mask_viewport.get_texture()
	offset = Vector2(0, -12)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	material = ShaderMaterial.new()
	material.shader = OUTLINE_SHADER
	material.set_shader_parameter("mask_texture", texture)
	# Game-over may pause processing in the same frame as the death signal.
	player.health.died.connect(hide)
	# Only the contour crosses actors; the body keeps normal world y-sorting.
	z_index = OUTLINE_Z_INDEX
	visible = false
	_process(0.0)

func _process(_delta: float) -> void:
	visible = false
	mask_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if not is_instance_valid(player) or not is_instance_valid(enemies) or texture == null:
		return
	if not player.is_visible_in_tree() or player.is_queued_for_deletion() or player.entrance_active or player.is_stealthed():
		return
	if player.health == null or player.health.current_health <= 0.0:
		return
	position = player.get_body_visual_center()
	var body: Rect2 = player.global_transform * player.get_visual_rect()
	# Terrain occlusion retains its own existing fade policy; never draw through it.
	if is_instance_valid(obstacles):
		for obstacle in obstacles.get_children():
			if not obstacle.is_queued_for_deletion() and obstacle.is_visible_in_tree() and obstacle.global_position.y > player.global_position.y:
				if (obstacle.global_transform * obstacle.occlusion_rect).intersects(body):
					return
	for enemy in enemies.get_children():
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or not enemy.is_visible_in_tree():
			continue
		# Bosses use a separate renderer; ordinary native actors share this
		# bounded visual interface without restoring a fake Sprite2D dependency.
		if not enemy.has_method("get_visual_node"):
			continue
		if enemy.global_position.y <= player.global_position.y:
			continue
		var art: Node2D = enemy.get_visual_node()
		if art != null and art.is_visible_in_tree() and (art.global_transform * enemy.get_visual_rect()).intersects(body):
			visible = true
			_sync_native_pose()
			return

func _sync_native_pose() -> void:
	var source: Node2D = player.native_visual
	for direction in mask_actor.DIRECTIONS:
		mask_actor.get_node(direction).visible = source.get_node(direction).visible
	var from: Skeleton2D = source.get_node(source.facing + "/Skeleton2D")
	var to: Skeleton2D = mask_actor.get_node(source.facing + "/Skeleton2D")
	for index in from.get_bone_count():
		to.get_bone(index).transform = from.get_bone(index).transform
	mask_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
