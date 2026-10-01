// Material for tall world geometry (buildings, walls). Fragments that sit between the camera and
// the player, inside a screen-space circle around the player, are dithered away so the player is
// never hidden (DESIGN §4.3 CameraRig cut-away). Facade detail (courses, windows, base dirt) is
// procedural so a scaled box reads as a ruined shell. Globals are written by CameraRig.
shader_type spatial;
#include "res://src/shaders/noise.gdshaderinc"
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

global uniform vec2 cutaway_center;
global uniform float cutaway_radius;
global uniform float cutaway_depth;
global uniform float wetness;

instance uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

const float BAYER[16] = float[](
		0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

varying vec3 local_pos;
varying vec3 local_normal;
varying vec3 world_pos;

void vertex() {
	local_pos = VERTEX;
	local_normal = NORMAL;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
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

	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	vec3 n = normalize(local_normal);
	vec3 col = tint.rgb * srgb_approx(COLOR.rgb);
	float rough = 0.9;
	float metal = 0.0;
	vec3 emission = vec3(0.0);
	float stain = noise2(world_pos.xz * 0.31 + world_pos.y * 0.17);
	col *= mix(0.8, 1.08, stain);

	if (n.y > 0.65) {
		col *= vec3(0.72, 0.66, 0.58);
		float grit = noise2(world_pos.xz * 1.6);
		col = mix(col, col * vec3(0.72, 0.64, 0.55), grit * 0.65);
		rough = 0.96;
	} else {
		vec2 face_uv;
		vec2 face_m;
		bool street = (world_pos.x > 0.0 && n.x < -0.5) || (world_pos.x < 0.0 && n.x > 0.5);
		if (abs(n.x) > 0.5) {
			face_uv = vec2(-sign(n.x) * local_pos.z, local_pos.y) + 0.5;
			face_m = vec2(scale.z, scale.y);
		} else {
			face_uv = vec2(sign(n.z) * local_pos.x, local_pos.y) + 0.5;
			face_m = vec2(scale.x, scale.y);
		}
		float dirt = smoothstep(0.32, 0.02, face_uv.y);
		col = mix(col, col * vec3(0.48, 0.36, 0.26), dirt * 0.8);
		float cornice = smoothstep(0.88, 0.97, face_uv.y);
		col *= mix(1.0, 0.68, cornice);
		float course = smoothstep(0.47, 0.5, abs(fract(face_uv.y * max(face_m.y, 1.0) * 0.85) - 0.5));
		col *= 1.0 - course * 0.12;

		vec2 meters = face_uv * face_m;
		vec2 cell = fract(meters * vec2(0.58, 0.52));
		vec2 cell_id = floor(meters * vec2(0.58, 0.52));
		float in_margin = step(0.12, face_uv.x) * step(face_uv.x, 0.88) * step(0.18, face_uv.y) * step(face_uv.y, 0.86);
		float frame = step(0.14, cell.x) * step(cell.x, 0.86) * step(0.18, cell.y) * step(cell.y, 0.82);
		float pane = step(0.26, cell.x) * step(cell.x, 0.74) * step(0.32, cell.y) * step(cell.y, 0.7);
		if (in_margin * frame > 0.5 && pane < 0.5) {
			col *= vec3(0.42, 0.38, 0.34);
			rough = 0.7;
		}
		if (in_margin * pane > 0.5) {
			float boarded = step(0.68, hash12(cell_id));
			if (boarded > 0.5) {
				col *= vec3(0.42, 0.32, 0.22);
				rough = 0.82;
			} else {
				vec3 glass = vec3(0.045, 0.055, 0.07);
				float occupied = step(0.62, hash12(cell_id + vec2(3.1, 1.7)));
				vec3 interior = vec3(0.42, 0.2, 0.08) * occupied;
				float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.2);
				col = mix(glass + interior * 0.35, vec3(0.72, 0.58, 0.44), fres * 0.5);
				metal = 0.25;
				rough = 0.16;
				emission = interior * 0.45;
			}
		}
		if (street) {
			float door = step(abs(face_uv.x - 0.5), 0.09) * step(face_uv.y, 0.2);
			col = mix(col, col * vec3(0.18, 0.14, 0.12), door);
		}
		float warmth = clamp((col.r - col.b) * 3.0, 0.0, 1.0);
		float streak = smoothstep(0.7, 0.92, noise2(vec2(world_pos.x * 1.8 + world_pos.z, world_pos.y * 0.28)));
		col = mix(col, col * vec3(0.65, 0.32, 0.16), streak * warmth * 0.55);
	}

	col = mix(col, col * vec3(0.6, 0.55, 0.5), wetness * 0.35);
	rough = mix(rough, 0.25, wetness);
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.2);
	float contact = smoothstep(1.6, 0.0, world_pos.y);
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = 0.3;
	EMISSION = emission + rim * vec3(1.0, 0.78, 0.55) * 0.03;
	AO = mix(1.0, 0.55, contact * 0.85);
}
