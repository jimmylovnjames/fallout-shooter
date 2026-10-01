// Dry grass cards: alpha-scissor blades, vertex wind, no shadows (one draw for the whole field).
shader_type spatial;
#include "res://src/shaders/noise.gdshaderinc"
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

global uniform vec2 wind_dir;
global uniform float wind_strength;

varying float blade_h;

void vertex() {
	// Cards are built with their base on y = 0 and a height of 2.15 m.
	blade_h = clamp(VERTEX.y / 2.15, 0.0, 1.0);
	vec3 origin = MODEL_MATRIX[3].xyz;
	float wave = sin(TIME * 1.55 + origin.x * 0.37 + origin.z * 0.31) * wind_strength;
	VERTEX.x += wind_dir.x * wave * blade_h * blade_h * 0.28;
	VERTEX.z += wind_dir.y * wave * blade_h * blade_h * 0.28;
}

void fragment() {
	float blade = abs(fract(UV.x * 2.0) - 0.5);
	float width = mix(0.42, 0.16, blade_h);
	float mask = 1.0 - smoothstep(width * 0.45, width, blade);
	mask *= 1.0 - smoothstep(0.78, 1.0, blade_h);
	ALPHA = mask;
	ALPHA_SCISSOR_THRESHOLD = 0.4;
	vec3 dry = srgb_approx(COLOR.rgb);
	dry = mix(dry * vec3(0.62, 0.58, 0.42), dry * vec3(1.15, 1.08, 0.85), blade_h);
	ALBEDO = dry;
	ROUGHNESS = 0.9;
}
