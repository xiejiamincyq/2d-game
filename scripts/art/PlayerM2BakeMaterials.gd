extends RefCounted
class_name PlayerM2BakeMaterials

const BODY_ACCENT := Color("3da7ff")
const WEAPON_ACCENT := Color("c66a32")

const BODY_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color;
uniform vec4 secondary_color : source_color;
uniform vec4 accent_color : source_color;
uniform vec4 micro_color : source_color;
uniform float metallic_level = 0.1;
uniform float roughness_level = 0.55;
uniform float wear_strength = 0.1;
uniform float pattern_scale = 90.0;
uniform float emission_strength = 1.0;

varying vec3 object_position;

float line_mask(float value, float center, float half_width) {
	return 1.0 - smoothstep(half_width, half_width + 0.012, abs(value - center));
}

float hash31(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453123);
}

void vertex() {
	object_position = VERTEX;
}

void fragment() {
	float vertical_panel = smoothstep(0.15, 0.55, abs(object_position.x));
	float torso_panel = smoothstep(0.78, 1.12, object_position.y) * (1.0 - smoothstep(1.40, 1.72, object_position.y));
	float lower_panel = 1.0 - smoothstep(0.58, 0.90, object_position.y);
	float panel_mix = clamp(0.28 * vertical_panel + 0.38 * torso_panel + 0.22 * lower_panel, 0.0, 0.72);
	float visor = line_mask(object_position.y, 1.68, 0.018) * (1.0 - smoothstep(0.12, 0.48, abs(object_position.x)));
	float chest = line_mask(object_position.y, 1.17, 0.016) * (1.0 - smoothstep(0.18, 0.52, abs(object_position.x)));
	float calf = line_mask(object_position.y, 0.38, 0.012) * smoothstep(0.10, 0.24, abs(object_position.x));
	float energy_mask = clamp(max(visor, max(chest * 0.82, calf * 0.52)), 0.0, 1.0);
	float weave = 0.5 + 0.5 * sin((object_position.x + object_position.z) * pattern_scale) * sin((object_position.x - object_position.z) * pattern_scale * 0.73);
	float wear = hash31(floor(object_position * 42.0));
	vec3 color = mix(base_color.rgb, secondary_color.rgb, panel_mix);
	color = mix(color, micro_color.rgb, weave * 0.075);
	color = mix(color, vec3(0.58), step(0.965 - wear_strength * 0.18, wear) * wear_strength * 0.22);
	color = mix(color, accent_color.rgb, energy_mask);
	ALBEDO = color;
	METALLIC = clamp(metallic_level + panel_mix * 0.16, 0.0, 1.0);
	ROUGHNESS = clamp(roughness_level + weave * 0.08 - energy_mask * 0.30, 0.18, 0.92);
	EMISSION = accent_color.rgb * energy_mask * emission_strength;
}
"""

static func body_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = BODY_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("base_color", Color("aeb8bc"))
	material.set_shader_parameter("secondary_color", Color("252d33"))
	material.set_shader_parameter("accent_color", BODY_ACCENT)
	material.set_shader_parameter("micro_color", Color("6e6a61"))
	material.set_shader_parameter("metallic_level", 0.48)
	material.set_shader_parameter("roughness_level", 0.55)
	material.set_shader_parameter("wear_strength", 0.34)
	material.set_shader_parameter("pattern_scale", 74.0)
	material.set_shader_parameter("emission_strength", 0.92)
	return material

static func weapon_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = WEAPON_ACCENT
	material.metallic = 0.52
	material.roughness = 0.42
	return material
