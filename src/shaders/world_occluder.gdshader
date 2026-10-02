// Material for tall world geometry (buildings, walls). Fragments that sit between the camera and
// the player, inside a screen-space circle around the player, are dithered away so the player is
// never hidden (DESIGN §4.3 CameraRig cut-away). The shell mesh tags glass and interior floor
// in UV.x; walls take the instance tint plus a plaster tile. Globals are written by CameraRig.
shader_type spatial;
#include "res://src/shaders/noise.gdshaderinc"
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

global uniform vec2 cutaway_center;
global uniform float cutaway_radius;
global uniform float cutaway_depth;
global uniform float wetness;

instance uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D plaster_tex : source_color, repeat_enable, filter_linear_mipmap;

varying vec3 local_normal;
varying vec3 world_pos;
varying float part_tag;

const float BAYER[16] = float[](
		0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void vertex() {
	local_normal = NORMAL;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// UV.x tags the shell part: 0 glass, 1 wall, 2 interior floor.
	part_tag = UV.x;
}

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

	vec3 n = normalize(local_normal);
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.2);
	// Glass panes are tagged in UV so they stay dark even when the instance tint is vivid.
	if (part_tag < 0.25) {
		vec3 glass_col = mix(vec3(0.012, 0.016, 0.024), vec3(0.42, 0.26, 0.12), fres * 0.16);
		ALBEDO = glass_col;
		ROUGHNESS = 0.08;
		METALLIC = 0.35;
		SPECULAR = 0.45;
		EMISSION = vec3(0.12, 0.06, 0.02) * fres;
		AO = 1.0;
	} else if (part_tag > 1.5) {
		ALBEDO = vec3(0.045, 0.04, 0.035);
		ROUGHNESS = 0.95;
		METALLIC = 0.0;
		SPECULAR = 0.1;
		EMISSION = vec3(0.0);
		AO = 0.7;
	} else {
		vec3 col = tint.rgb * srgb_approx(COLOR.rgb);
		float rough = 0.9;
		float metal = 0.0;
		vec3 emission = vec3(0.0);
		vec2 plaster_uv = abs(n.y) > 0.6 ? world_pos.xz : (abs(n.x) > 0.5 ? world_pos.zy : world_pos.xy);
		col = detail_modulate(col, texture(plaster_tex, plaster_uv * 0.42).rgb, 0.82);
		float stain = noise2(world_pos.xz * 0.31 + world_pos.y * 0.17);
		col *= mix(0.84, 1.06, stain);

		if (n.y > 0.65) {
			col *= vec3(0.78, 0.72, 0.64);
			float grit = noise2(world_pos.xz * 1.6);
			col = mix(col, col * vec3(0.72, 0.64, 0.55), grit * 0.55);
			rough = 0.96;
		} else {
			float dirt = smoothstep(1.4, 0.05, world_pos.y);
			col = mix(col, col * vec3(0.48, 0.36, 0.26), dirt * 0.75);
			float warmth = clamp((col.r - col.b) * 3.0, 0.0, 1.0);
			float streak = smoothstep(0.7, 0.92, noise2(vec2(world_pos.x * 1.8 + world_pos.z, world_pos.y * 0.28)));
			col = mix(col, col * vec3(0.65, 0.32, 0.16), streak * warmth * 0.55);
		}

		col = mix(col, col * vec3(0.6, 0.55, 0.5), wetness * 0.35);
		rough = mix(rough, 0.25, wetness);
		float rim = pow(1.0 - clamp(dot(n, normalize(VIEW)), 0.0, 1.0), 3.2);
		float contact = smoothstep(1.6, 0.0, world_pos.y);
		ALBEDO = col;
		ROUGHNESS = rough;
		METALLIC = metal;
		SPECULAR = 0.3;
		EMISSION = emission + rim * vec3(1.0, 0.78, 0.55) * 0.03;
		AO = mix(1.0, 0.55, contact * 0.85);
	}
}
