shader_type canvas_item;

void fragment() {
	vec4 sample_color = texture(TEXTURE, UV);
	// Normalize near-opaque interiors and suppress faint generated residue.
	sample_color.a = smoothstep(0.20, 0.98, sample_color.a);
	COLOR = sample_color;
}
