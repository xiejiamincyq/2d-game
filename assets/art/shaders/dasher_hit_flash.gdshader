shader_type canvas_item;

uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 base_color = texture(TEXTURE, UV) * COLOR;
	base_color.rgb = mix(base_color.rgb, vec3(1.0), flash_amount * base_color.a);
	COLOR = base_color;
}
