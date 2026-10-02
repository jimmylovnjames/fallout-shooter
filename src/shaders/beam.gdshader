// Hitscan tracers and projectiles. Opaque and discarded at the edge so the mobile renderer
// does not dither them into a cloud. Local X/Y are the ribbon width, local Z runs tail to tip.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled, ambient_light_disabled;

varying float across;
varying float along;

void vertex() {
	across = clamp(length(vec2(VERTEX.x, VERTEX.y)) * 2.0, 0.0, 1.0);
	along = clamp(VERTEX.z + 0.5, 0.0, 1.0);
}

void fragment() {
	float ends = smoothstep(0.0, 0.06, along) * smoothstep(1.0, 0.7, along);
	if (across > 0.72 || ends < 0.04) {
		discard;
	}
	float core = smoothstep(0.72, 0.0, across);
	vec3 hot = mix(COLOR.rgb, vec3(1.0), core * 0.35);
	ALBEDO = hot * mix(1.7, 2.8, core);
}
