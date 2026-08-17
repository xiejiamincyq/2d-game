extends RefCounted
class_name PlayerTurnaroundModel

const MODEL_PATH := "res://assets/art/source/player/player_turnaround_model_v1.glb"
const PROJECTION_ATLAS_PATH := "res://assets/art/source/player/player_turnaround_projection_atlas_v1.png"
const TARGET_HEIGHT := 4.65
const ARMOR := Color("8f8478")
const PROJECTION_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_prepass_alpha;

uniform sampler2D view_atlas : source_color, filter_linear;
uniform int view_a = 0;
uniform int view_b = 1;
uniform float view_blend : hint_range(0.0, 1.0) = 0.0;

vec2 view_uv(vec2 screen_uv, int view_index) {
	vec2 cell = vec2(float(view_index % 4), float(view_index / 4));
	return (cell + clamp(screen_uv, vec2(0.002), vec2(0.998))) / vec2(4.0, 2.0);
}

float foreground_alpha(vec3 color) {
	float value = max(color.r, max(color.g, color.b));
	return smoothstep(0.008, 0.035, value);
}

void fragment() {
	vec3 color_a = texture(view_atlas, view_uv(SCREEN_UV, view_a)).rgb;
	vec3 color_b = texture(view_atlas, view_uv(SCREEN_UV, view_b)).rgb;
	float alpha_a = foreground_alpha(color_a);
	float alpha_b = foreground_alpha(color_b);
	float weight_a = (1.0 - view_blend) * alpha_a;
	float weight_b = view_blend * alpha_b;
	float alpha = weight_a + weight_b;
	if (alpha < 0.04) {
		discard;
	}
	ALBEDO = (color_a * weight_a + color_b * weight_b) / max(alpha, 0.001);
	ALPHA = alpha;
}
"""

static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "PlayerTurnaroundModel"
	var resource := ResourceLoader.load(MODEL_PATH)
	if not resource is PackedScene:
		push_error("Player turnaround GLB could not be loaded: " + MODEL_PATH)
		return root
	var imported := (resource as PackedScene).instantiate() as Node3D
	if imported == null:
		push_error("Player turnaround GLB did not instantiate as Node3D")
		return root
	root.add_child(imported)

	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(imported, meshes)
	if meshes.is_empty():
		push_error("Player turnaround GLB contains no mesh instances")
		return root
	var bounds := _combined_bounds(root, meshes)
	if bounds.size.y <= 0.0:
		push_error("Player turnaround GLB has invalid bounds")
		return root
	var model_scale := TARGET_HEIGHT / bounds.size.y
	imported.scale *= Vector3.ONE * model_scale
	var center := bounds.get_center()
	imported.position += Vector3(-center.x, -bounds.position.y, -center.z) * model_scale

	var material := _projection_material()
	for mesh_instance in meshes:
		mesh_instance.material_override = material
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return root

static func set_projection_angle(model: Node3D, angle_degrees: float) -> void:
	var view_position := fposmod((90.0 - angle_degrees) / 45.0, 8.0)
	var first_view := floori(view_position)
	var second_view := (first_view + 1) % 8
	var blend := view_position - floorf(view_position)
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(model, meshes)
	for mesh_instance in meshes:
		var material := mesh_instance.material_override as ShaderMaterial
		if material != null:
			material.set_shader_parameter("view_a", first_view)
			material.set_shader_parameter("view_b", second_view)
			material.set_shader_parameter("view_blend", blend)

static func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		output.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, output)

static func _combined_bounds(root: Node3D, meshes: Array[MeshInstance3D]) -> AABB:
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	for mesh_instance in meshes:
		var local_bounds := mesh_instance.get_aabb()
		var relative := _transform_relative_to(mesh_instance, root)
		for x in [0.0, 1.0]:
			for y in [0.0, 1.0]:
				for z in [0.0, 1.0]:
					var corner := local_bounds.position + local_bounds.size * Vector3(x, y, z)
					var point := relative * corner
					minimum = minimum.min(point)
					maximum = maximum.max(point)
	return AABB(minimum, maximum - minimum)

static func _transform_relative_to(node: Node3D, ancestor: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != ancestor:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result

static func _projection_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = PROJECTION_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("view_atlas", ResourceLoader.load(PROJECTION_ATLAS_PATH))
	return material
