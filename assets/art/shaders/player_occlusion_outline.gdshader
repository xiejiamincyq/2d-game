shader_type canvas_item;

uniform vec4 region;
uniform sampler2D outline_atlas : filter_linear;

float alpha_at(vec2 uv) {
	if (uv.x < region.x || uv.y < region.y || uv.x > region.z || uv.y > region.w) { return 0.0; }
	return texture(outline_atlas, uv).a;
}

void fragment() {
	// Inner outline stays within the cardinal atlas cell and does not fill the body.
	vec2 near_step = TEXTURE_PIXEL_SIZE * 2.5;
	vec2 far_step = TEXTURE_PIXEL_SIZE * 8.0;
	float narrow = min(min(alpha_at(UV + vec2(near_step.x, 0.0)), alpha_at(UV - vec2(near_step.x, 0.0))),
		min(alpha_at(UV + vec2(0.0, near_step.y)), alpha_at(UV - vec2(0.0, near_step.y))));
	float wide = min(min(alpha_at(UV + vec2(far_step.x, 0.0)), alpha_at(UV - vec2(far_step.x, 0.0))),
		min(alpha_at(UV + vec2(0.0, far_step.y)), alpha_at(UV - vec2(0.0, far_step.y))));
	vec3 ink = mix(vec3(0.071, 0.231, 0.231), vec3(0.953, 0.929, 0.863), narrow);
	COLOR = vec4(ink, alpha_at(UV) * (1.0 - wide));
}
