// Inverted-hull outline for actors/interactables (DECISIONS D019). Used as `next_pass` on the
// actor material. One extra draw per outlined surface; no full-screen pass. Shares the actor's
// `dissolve` instance uniform so the outline disappears with the body.
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled, depth_draw_opaque;

uniform vec4 outline_color : source_color = vec4(0.02, 0.02, 0.03, 1.0);
uniform float thickness : hint_range(0.0, 0.2) = 0.032;
instance uniform float dissolve : hint_range(0.0, 1.0), instance_index(2) = 0.0;

void vertex() {
	VERTEX += NORMAL * thickness;
}

void fragment() {
	if (dissolve > 0.05) {
		discard;
	}
	ALBEDO = outline_color.rgb;
}
