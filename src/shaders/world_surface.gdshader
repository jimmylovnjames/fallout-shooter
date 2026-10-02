// Stylized prop surface (DESIGN §7): albedo breakup, contact darkening and a material id.
// `style` and `deform_amt` are uniforms (one material per kind) so headless and mobile compile
// the same shader. Per-instance shape comes from the instance origin. Wetness is a global.
// Instance uniforms match the outline next_pass slot layout (D019 / actor shader).
shader_type spatial;
#include "res://src/shaders/noise.gdshaderinc"
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

global uniform float wetness;

instance uniform vec4 tint : source_color, instance_index(0) = vec4(1.0);
instance uniform float hit_flash : hint_range(0.0, 1.0), instance_index(1) = 0.0;
instance uniform float dissolve : hint_range(0.0, 1.0), instance_index(2) = 0.0;

uniform vec3 albedo : source_color = vec3(0.7);
uniform float roughness_amt : hint_range(0.0, 1.0) = 0.85;
uniform float metallic_amt : hint_range(0.0, 1.0) = 0.0;
// 0 concrete, 1 rust, 2 sand, 3 wood, 4 paint, 5 dark metal, 7 rock, 8 bark.
uniform int style = 0;
uniform float deform_amt : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D rust_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D wood_tex : source_color, repeat_enable, filter_linear_mipmap;

varying vec3 local_pos;
varying vec3 world_pos;
varying float inst_seed;

void vertex() {
	vec3 lp = VERTEX;
	vec3 origin = MODEL_MATRIX[3].xyz;
	inst_seed = fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453);
	if (deform_amt > 0.001) {
		float n = hash13(VERTEX * 2.7 + inst_seed * 19.0);
		VERTEX += NORMAL * (n - 0.5) * deform_amt * 2.0;
	}
	local_pos = lp;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = hash13(floor(local_pos * 14.0));
	if (dissolve > 0.0 && n < dissolve) {
		discard;
	}
	int style_id = style;
	float seed = inst_seed;
	vec3 col = albedo * srgb_approx(COLOR.rgb) * tint.rgb;
	float rough = roughness_amt;
	float metal = metallic_amt;

	float macro = noise3(world_pos * 0.45 + seed);
	col *= mix(0.84, 1.08, macro);

	if (style_id == 1) {
		vec3 rust_sample = texture(rust_tex, world_pos.xz * 0.85 + vec2(world_pos.y, 0.0)).rgb;
		col = detail_modulate(col, rust_sample, 0.72);
		rough = 0.58;
		metal = 0.42;
		float bands = abs(fract(local_pos.y * 3.2) - 0.5);
		float hoop = smoothstep(0.14, 0.045, bands);
		col = mix(col, col * vec3(0.22, 0.2, 0.18), hoop);
		metal = mix(metal, 0.82, hoop);
		rough = mix(rough, 0.32, hoop);
		float streak = noise2(vec2(atan(local_pos.x, local_pos.z) * 1.4, world_pos.y * 1.6));
		col = mix(col, col * vec3(0.62, 0.32, 0.14), smoothstep(0.62, 0.9, streak) * 0.65);
	} else if (style_id == 3) {
		vec3 wood_sample = texture(wood_tex, local_pos.xz * 0.9 + vec2(0.0, local_pos.y * 1.4)).rgb;
		col = detail_modulate(col, wood_sample, 0.66);
		rough = 0.78;
		metal = 0.0;
		float seam = abs(fract(local_pos.y * 4.0) - 0.5);
		col = mix(col, col * vec3(0.32, 0.24, 0.16), smoothstep(0.42, 0.49, seam));
		float grain = noise2(local_pos.xz * 7.0 + local_pos.y * 2.0);
		col *= mix(0.88, 1.06, grain);
	} else if (style_id == 4) {
		rough = 0.48;
		metal = 0.12;
		float chip = smoothstep(0.78, 0.95, noise3(local_pos * 9.0));
		col = mix(col, vec3(0.28, 0.24, 0.2), chip * 0.7);
	} else if (style_id == 5) {
		rough = 0.62;
		metal = 0.38;
		float edge = smoothstep(0.55, 0.95, noise3(local_pos * 5.0));
		col = mix(col, col * vec3(1.25, 1.15, 1.0), edge * 0.35);
	} else if (style_id == 7) {
		rough = 0.94;
		metal = 0.02;
		float grit = noise3(local_pos * 5.5 + seed * 8.0);
		col *= mix(0.86, 1.08, grit);
		col = mix(col, col * vec3(0.78, 0.72, 0.64), smoothstep(0.62, 0.92, noise3(local_pos * 2.2)) * 0.4);
	} else if (style_id == 8) {
		rough = 0.88;
		metal = 0.0;
		float bark = noise2(vec2(atan(local_pos.x, local_pos.z) * 2.2, local_pos.y * 2.4));
		col *= mix(0.62, 1.08, bark);
		col = mix(col, col * vec3(0.45, 0.38, 0.3), smoothstep(0.7, 0.95, noise2(local_pos.yz * 6.0)));
	} else {
		float pore = noise3(local_pos * 8.0);
		col *= mix(0.92, 1.04, pore);
		float seam_x = smoothstep(0.46, 0.5, abs(fract(local_pos.x * 1.6) - 0.5));
		float seam_y = smoothstep(0.46, 0.5, abs(fract(local_pos.y * 1.6) - 0.5));
		col *= 1.0 - max(seam_x, seam_y) * 0.18;
	}

	float contact = smoothstep(0.5, 0.0, world_pos.y);
	if (style_id == 7) {
		contact *= 0.4;
	}
	AO = mix(1.0, 0.48, contact);
	col = mix(col, col * vec3(0.55, 0.48, 0.4), wetness * 0.45);
	rough = mix(rough, 0.18, wetness);
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.5);
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = mix(0.35, 0.55, metal);
	EMISSION = rim * vec3(1.0, 0.78, 0.55) * 0.035;
}
