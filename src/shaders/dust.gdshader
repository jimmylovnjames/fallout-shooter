// Broad unshaded sheets of ground haze. One MultiMesh, no shadows. Alpha stays low so actors
// remain readable through it (DESIGN §7: height fog plus cards, not a depth-fog veil).
shader_type spatial;
#include "res://src/shaders/noise.gdshaderinc"
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled, ambient_light_disabled;

uniform vec3 dust_color : source_color = vec3(0.72, 0.64, 0.52);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz * 0.04 + vec2(TIME * 0.012, TIME * 0.007);
	float n = noise2(p) * 0.7 + noise2(p * 2.4 + 3.0) * 0.3;
	float puff = smoothstep(0.32, 0.78, n);
	vec2 e = abs(UV * 2.0 - 1.0);
	float edge = smoothstep(1.0, 0.35, max(e.x, e.y));
	ALBEDO = dust_color;
	ALPHA = puff * edge * 0.07 * COLOR.a;
}
