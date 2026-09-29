// Material for tall world geometry (buildings, walls). Fragments that sit between the camera and
// the player, inside a screen-space circle around the player, are dithered away so the player is
// never hidden (DESIGN §4.3 CameraRig cut-away). Globals are written by CameraRig every frame.
// Only occluders use this shader: `discard` costs early-Z on tile GPUs, so ground/props don't.
shader_type spatial;

global uniform vec2 cutaway_center;
global uniform float cutaway_radius;
global uniform float cutaway_depth;

instance uniform vec4 tint : source_color = vec4(0.56, 0.54, 0.5, 1.0);

const float BAYER[16] = float[](
	0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec2 aspect = vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0);
	float d = length((SCREEN_UV - cutaway_center) * aspect);
	float view_depth = -VERTEX.z;
	if (cutaway_radius > 0.0 && view_depth < cutaway_depth - 0.6) {
		float fade = 1.0 - smoothstep(cutaway_radius * 0.7, cutaway_radius, d);
		ivec2 px = ivec2(FRAGCOORD.xy) % 4;
		float threshold = (BAYER[px.y * 4 + px.x] + 0.5) / 16.0;
		if (fade * 0.85 > threshold) {
			discard;
		}
	}
	ALBEDO = tint.rgb;
	ROUGHNESS = 0.9;
}
