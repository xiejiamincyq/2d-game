extends SceneTree

const PlayerScript = preload("res://scripts/actors/Player.gd")
const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const FloorScript = preload("res://scripts/world/FloorGrid.gd")
const OUTPUT := "res://docs/art/previews/environment/player-occlusion-options-v1.png"

# Preview-only shaders: neither is loaded by the game.
const CUTAWAY := """
shader_type canvas_item;
uniform vec2 player_center;
varying vec2 world_point;
void vertex() { world_point = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }
void fragment() {
    vec4 base = texture(TEXTURE, UV) * COLOR;
    float distance = length((world_point - player_center) / vec2(31.0, 40.0));
    base.a *= smoothstep(0.75, 1.15, distance);
    COLOR = base;
}
"""
const OUTLINE := """
shader_type canvas_item;
uniform vec4 region;
float alpha_at(sampler2D tex, vec2 uv) {
    if (uv.x < region.x || uv.y < region.y || uv.x > region.z || uv.y > region.w) { return 0.0; }
    return texture(tex, uv).a;
}
void fragment() {
    vec2 step_uv = TEXTURE_PIXEL_SIZE * 3.0;
    float inside = min(min(alpha_at(TEXTURE, UV + vec2(step_uv.x, 0.0)), alpha_at(TEXTURE, UV - vec2(step_uv.x, 0.0))),
                       min(alpha_at(TEXTURE, UV + vec2(0.0, step_uv.y)), alpha_at(TEXTURE, UV - vec2(0.0, step_uv.y))));
    COLOR = vec4(vec3(0.953, 0.929, 0.863), alpha_at(TEXTURE, UV) * (1.0 - inside));
}
"""

func _initialize() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(FloorScript.new())
	for option in range(4):
		var origin := Vector2((option % 2) * 480, (option / 2) * 360)
		var center := origin + Vector2(240, 193)
		var world := Node2D.new()
		world.y_sort_enabled = true
		viewport.add_child(world)
		var player := PlayerScript.new()
		player.position = center
		player.process_mode = Node.PROCESS_MODE_DISABLED
		world.add_child(player)
		await process_frame
		player.advance_entrance(player.get_entrance_duration() + 0.01)
		player.gun_angle = 0.0
		player.queue_redraw()
		for index in range(8):
			var enemy := EnemyScript.new()
			enemy.process_mode = Node.PROCESS_MODE_DISABLED
			enemy.setup(EnemyScript.EnemyKind.OVERSEER if index % 2 == 0 else EnemyScript.EnemyKind.BRUISER, 1, world, player)
			world.add_child(enemy)
			await process_frame
			var angle := TAU * float(index) / 8.0
			enemy.position = center + Vector2(cos(angle) * 48.0, sin(angle) * 28.0 + 12.0)
			enemy._update_enemy_facing(center)
			if option == 2 and enemy.position.y >= center.y:
				var material := _material(CUTAWAY)
				material.set_shader_parameter("player_center", center)
				enemy.static_visual.material = material
		if option == 1:
			for inner in [false, true]:
				var marker := Polygon2D.new()
				marker.polygon = PackedVector2Array([Vector2(-12, -8), Vector2(12, -8), Vector2(0, 8)])
				marker.position = center + Vector2(0, -110)
				marker.scale = Vector2.ONE * (0.68 if inner else 1.0)
				marker.color = Color("f3eddc") if inner else Color("123b3b")
				marker.z_index = 20
				world.add_child(marker)
		if option == 3:
			var atlas := AtlasTexture.new()
			atlas.atlas = player.player_body_texture
			atlas.region = player.chibi_cardinal_rect(PlayerScript.CHIBI_RIGHT)
			atlas.filter_clip = true
			var outline := Sprite2D.new()
			outline.texture = atlas
			outline.position = center
			outline.scale = PlayerScript.CHIBI_BODY_DRAW_SIZE / PlayerScript.CHIBI_CARDINAL_CELL_SIZE
			outline.z_index = 20
			var material := _material(OUTLINE)
			var size := atlas.atlas.get_size()
			material.set_shader_parameter("region", Vector4(atlas.region.position.x / size.x, atlas.region.position.y / size.y, atlas.region.end.x / size.x, atlas.region.end.y / size.y))
			outline.material = material
			world.add_child(outline)
		var warning := Line2D.new()
		warning.points = PackedVector2Array([center + Vector2(-155, 43), center + Vector2(150, -12)])
		warning.width = 2.0
		warning.default_color = Color("f27a4b")
		warning.z_index = 30
		world.add_child(warning)
		_label(viewport, ["Current: occluded", "A: position marker", "B: local cutaway", "C: body outline"][option], origin + Vector2(28, 26), 25)
		_label(viewport, "Fixed pose / original runtime scale", origin + Vector2(28, 318), 17)
	await process_frame
	await RenderingServer.frame_post_draw
	var capture := viewport.get_texture().get_image()
	if capture == null or capture.is_empty() or capture.save_png(ProjectSettings.globalize_path(OUTPUT)) != OK:
		push_error("Occlusion options capture failed")
		quit(1)
		return
	viewport.queue_free()
	await process_frame
	print("OCCLUSION OPTIONS PASS: ", OUTPUT)
	quit(0)

func _material(code: String) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = code
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

func _label(parent: Node, value: String, at: Vector2, size: int) -> void:
	var label := Label.new()
	label.text = value
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("123b3b"))
	parent.add_child(label)
