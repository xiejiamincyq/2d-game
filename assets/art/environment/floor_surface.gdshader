shader_type canvas_item;

varying vec2 surface_position;

float patch_value(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	surface_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 grid = surface_position / 380.0;
	vec2 cell = floor(grid);
	vec2 weight = smoothstep(vec2(0.0), vec2(1.0), fract(grid));
	float variation = mix(
		mix(patch_value(cell), patch_value(cell + vec2(1.0, 0.0)), weight.x),
		mix(patch_value(cell + vec2(0.0, 1.0)), patch_value(cell + vec2(1.0)), weight.x),
		weight.y
	);
	vec3 ground = texture(TEXTURE, UV).rgb;
	// Keep the original slab identity, soften seams and vary broad patches.
	ground = mix(vec3(0.65, 0.70, 0.62), ground, 0.52);
	COLOR = vec4(ground * (0.97 + variation * 0.06), 1.0);
}
