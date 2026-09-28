// Inverted-hull outline for actors/interactables (DECISIONS D019). Used as `next_pass` on the
// actor's base material. Cheap on tile-based GPUs: one extra draw per outlined surface, no
// full-screen pass.
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled, depth_draw_opaque;

uniform vec4 outline_color : source_color = vec4(0.06, 0.05, 0.04, 1.0);
// World-space thickness in metres; scaled by distance so outlines stay readable when zoomed out.
uniform float thickness : hint_range(0.0, 0.2) = 0.035;

void vertex() {
	VERTEX += NORMAL * thickness;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
