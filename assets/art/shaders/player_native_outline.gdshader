shader_type canvas_item;
uniform sampler2D mask_texture : filter_nearest;

float alpha_at(vec2 uv) {
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) { return 0.0; }
	return texture(mask_texture, uv).a;
}

void fragment() {
	// Body-only inner locator: actual animated silhouette, not a filled ghost.
	vec2 near_step = TEXTURE_PIXEL_SIZE * 1.5;
	vec2 far_step = TEXTURE_PIXEL_SIZE * 4.0;
	float narrow = min(min(alpha_at(UV + vec2(near_step.x, 0.0)), alpha_at(UV - vec2(near_step.x, 0.0))),
		min(alpha_at(UV + vec2(0.0, near_step.y)), alpha_at(UV - vec2(0.0, near_step.y))));
	float wide = min(min(alpha_at(UV + vec2(far_step.x, 0.0)), alpha_at(UV - vec2(far_step.x, 0.0))),
		min(alpha_at(UV + vec2(0.0, far_step.y)), alpha_at(UV - vec2(0.0, far_step.y))));
	COLOR = vec4(mix(vec3(0.11, 0.16, 0.15), vec3(0.93, 0.86, 0.70), narrow), alpha_at(UV) * (1.0 - wide));
}
