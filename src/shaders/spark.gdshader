// Muzzle flash and impact. Opaque core with a discarded edge, so it stays a hard spark
// on the mobile renderer instead of a dithered blob.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled, ambient_light_disabled;

varying float radius;

void vertex() {
	radius = clamp(length(VERTEX) * 2.0, 0.0, 1.0);
}

void fragment() {
	if (radius > 0.62) {
		discard;
	}
	float hot = smoothstep(0.62, 0.0, radius);
	vec3 col = mix(COLOR.rgb, vec3(1.0), hot * 0.85);
	ALBEDO = col * mix(1.4, 3.2, hot);
}
