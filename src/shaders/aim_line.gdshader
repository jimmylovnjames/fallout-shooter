// Gameplay aim guide: unshaded, fades out along its length so it reads as a direction
// and not a solid plank lying on the road.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled, ambient_light_disabled;

uniform vec3 line_color : source_color = vec3(1.0, 0.62, 0.28);

varying float along;

void vertex() {
	// Box is 6.4 m on local Z, centered. Negative Z is the far tip (actor forward).
	along = clamp((-VERTEX.z / 3.2) * 0.5 + 0.5, 0.0, 1.0);
}

void fragment() {
	float fade = (1.0 - along);
	fade *= fade;
	ALBEDO = line_color;
	ALPHA = 0.62 * fade;
}
