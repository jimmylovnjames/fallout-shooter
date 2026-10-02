// Unshaded lamp heads. One material, no shadow, so a street of bulbs stays a single draw.
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

uniform vec3 color : source_color = vec3(1.0, 0.45, 0.08);

void fragment() {
	ALBEDO = color * 1.6;
}
