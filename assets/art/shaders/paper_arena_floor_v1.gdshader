shader_type canvas_item;
render_mode unshaded;
// Original quiet matte-paper slabs: world anchored, no raster/noise inputs.
varying vec2 paper_position;
void vertex() {
	paper_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	vec2 cell = floor(paper_position / 256.0);
	vec2 local = mod(paper_position, 256.0);
	vec2 distance_to_edge = min(local, 256.0-local);
	float seam = 1.0-smoothstep(0.0, 1.5, min(distance_to_edge.x, distance_to_edge.y));
	float alternate = mod(cell.x+cell.y, 2.0);
	vec3 paper = vec3(0.45, 0.52, 0.44) + alternate*0.012;
	COLOR = vec4(paper-seam*0.035, 1.0);
}
