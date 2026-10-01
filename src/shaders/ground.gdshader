// Arena ground: rolled dust, pebble breakup, and a worn strip of road painted in-shader so the
// path is not a second mesh (and does not cast a paper-thin shadow).
shader_type spatial;
#include "res://src/shaders/noise.gdshaderinc"
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 sand_hi : source_color = vec3(0.96, 0.78, 0.32);
uniform vec3 sand_lo : source_color = vec3(0.55, 0.22, 0.1);
uniform vec3 asphalt : source_color = vec3(0.06, 0.07, 0.1);
uniform float road_half_width = 3.05;
uniform float road_half_length = 46.0;

varying vec3 world_pos;
varying float road_mask;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float roll = noise2(w.xz * 0.032) * 0.65 + noise2(w.xz * 0.09) * 0.35;
	float lift = (roll - 0.4) * 0.11;
	float across = smoothstep(road_half_width - 0.4, road_half_width + 0.9, abs(w.x));
	float along = smoothstep(road_half_length, road_half_length - 6.0, abs(w.z));
	float road = (1.0 - across) * along;
	VERTEX.y += lift * (1.0 - road) + road * 0.025;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	road_mask = road;
}

void fragment() {
	float macro = noise2(world_pos.xz * 0.055);
	float mid = noise2(world_pos.xz * 0.22);
	vec3 sand = mix(sand_lo, sand_hi, macro);
	sand = mix(sand, sand_hi * vec3(1.06, 0.98, 0.86), mid * 0.4);
	float pebble = smoothstep(0.74, 0.92, noise2(world_pos.xz * 5.5));
	sand = mix(sand, sand * vec3(0.7, 0.64, 0.56), pebble * 0.4);
	float grit = noise2(world_pos.xz * 1.8);
	sand *= mix(0.9, 1.06, grit);

	vec3 tar = asphalt * mix(0.85, 1.15, noise2(world_pos.xz * 0.7));
	float crack = smoothstep(0.78, 0.96, noise2(world_pos.xz * 1.15 + vec2(4.0, 1.0)));
	tar = mix(tar, tar * vec3(0.35, 0.32, 0.28), crack);
	float wear = smoothstep(road_half_width, 0.35, abs(world_pos.x));
	tar = mix(tar, tar * vec3(1.35, 1.28, 1.15), wear * 0.35);
	float edge = smoothstep(0.15, 0.85, noise2(world_pos.xz * 0.85));
	vec3 road = mix(tar, sand * vec3(0.7, 0.66, 0.58), edge * 0.35);

	vec3 col = mix(sand, road, road_mask);
	float rough = mix(0.96, mix(0.84, 0.62, wear), road_mask);
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 4.0);
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = 0.0;
	SPECULAR = 0.22;
	EMISSION = rim * vec3(0.95, 0.62, 0.35) * 0.045;
}
