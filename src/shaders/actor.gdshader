// Greybox actor material (DESIGN §7): vertex-colour albedo with a per-instance tint, hit flash and
// dissolve — all `instance uniform`, so every actor shares ONE material and batching state.
// COLOR.a marks tintable parts (1 = body, 0 = gear keeps its vertex colour).
shader_type spatial;
render_mode cull_back;

// Explicit indices: the outline next_pass reads `dissolve` too, and passes of one instance must
// agree on each instance uniform's slot (engine warns otherwise).
instance uniform vec4 tint : source_color, instance_index(0) = vec4(1.0);
instance uniform float hit_flash : hint_range(0.0, 1.0), instance_index(1) = 0.0;
instance uniform float dissolve : hint_range(0.0, 1.0), instance_index(2) = 0.0;
uniform vec3 dissolve_edge : source_color = vec3(1.0, 0.45, 0.1);

varying vec3 obj_pos;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void vertex() {
	obj_pos = VERTEX;
}

void fragment() {
	float n = hash3(floor(obj_pos * 14.0));
	if (dissolve > 0.0 && n < dissolve) {
		discard;
	}
	vec3 base = COLOR.rgb * mix(vec3(1.0), tint.rgb, COLOR.a);
	ALBEDO = mix(base, vec3(1.0), hit_flash * 0.85);
	ROUGHNESS = 0.8;
	float edge = dissolve > 0.0 ? step(n, dissolve + 0.08) : 0.0;
	EMISSION = hit_flash * vec3(1.0, 0.85, 0.7) * 1.5 + edge * dissolve_edge * 3.0;
}
