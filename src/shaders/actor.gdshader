// Greybox actor material (DESIGN §7): vertex-colour albedo with a per-instance tint, hit flash and
// dissolve — all `instance uniform`, so every actor shares ONE material and batching state.
// COLOR.a marks tintable parts (1 = body, 0 = gear keeps its vertex colour). Gear with a warm
// vertex colour (the visor) emits so characters read at a glance from the top-down camera.
shader_type spatial;
#include "res://src/shaders/noise.gdshaderinc"
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Explicit indices: the outline next_pass reads `dissolve` too, and passes of one instance must
// agree on each instance uniform's slot (engine warns otherwise).
instance uniform vec4 tint : source_color, instance_index(0) = vec4(1.0);
instance uniform float hit_flash : hint_range(0.0, 1.0), instance_index(1) = 0.0;
instance uniform float dissolve : hint_range(0.0, 1.0), instance_index(2) = 0.0;
uniform vec3 dissolve_edge : source_color = vec3(1.0, 0.45, 0.1);

varying vec3 obj_pos;

void vertex() {
	obj_pos = VERTEX;
}

void fragment() {
	float n = hash13(floor(obj_pos * 14.0));
	if (dissolve > 0.0 && n < dissolve) {
		discard;
	}
	float cloth = COLOR.a;
	float gear = 1.0 - cloth;
	vec3 base = COLOR.rgb * mix(vec3(1.0), tint.rgb, cloth);
	float grain = hash13(floor(obj_pos * 9.0));
	base *= mix(0.9, 1.06, grain * cloth + (1.0 - cloth));
	float grime = smoothstep(1.15, 0.12, obj_pos.y);
	base = mix(base, base * vec3(0.7, 0.6, 0.48), grime * 0.4 * cloth);
	float warmth = base.r - base.b;
	float visor = gear * smoothstep(0.2, 0.45, warmth);
	ALBEDO = mix(base, vec3(1.0), hit_flash * 0.85);
	ROUGHNESS = mix(mix(0.72, 0.4, gear), 0.25, visor);
	METALLIC = mix(0.04, 0.62, gear) * (1.0 - visor);
	SPECULAR = mix(0.3, 0.55, gear);
	float edge = dissolve > 0.0 ? step(n, dissolve + 0.08) : 0.0;
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.6);
	vec3 rim_col = vec3(1.0, 0.72, 0.48);
	EMISSION = hit_flash * vec3(1.0, 0.85, 0.7) * 1.5 + edge * dissolve_edge * 3.0;
	EMISSION += rim * rim_col * 0.08 + visor * vec3(1.0, 0.46, 0.1) * 0.55;
}
