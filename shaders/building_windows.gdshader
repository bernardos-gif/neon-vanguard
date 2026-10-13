// Procedural skyscraper facade: a grid of windows, randomly lit per building.
// Used on a MultiMesh of unit boxes; INSTANCE_CUSTOM.x is a per-building seed.
shader_type spatial;
render_mode blend_mix, cull_back;

uniform vec3 base_color : source_color = vec3(0.035, 0.04, 0.06);
uniform vec3 window_warm : source_color = vec3(1.0, 0.72, 0.42);
uniform vec3 window_cool : source_color = vec3(0.45, 0.8, 1.0);
uniform vec3 window_neon : source_color = vec3(1.0, 0.3, 0.85);
uniform float density = 0.38;
uniform float emission_strength = 2.2;
uniform vec2 cell = vec2(1.8, 2.6);

varying vec3 v_local;
varying vec3 v_normal;
varying float v_seed;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	vec3 s = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	v_local = VERTEX * s;
	v_normal = NORMAL;
	v_seed = INSTANCE_CUSTOM.x;
}

void fragment() {
	vec2 uv;
	if (abs(v_normal.x) > 0.5) {
		uv = v_local.zy;
	} else if (abs(v_normal.z) > 0.5) {
		uv = v_local.xy;
	} else {
		uv = v_local.xz;
	}
	vec2 c = floor(uv / cell);
	vec2 f = fract(uv / cell);
	float win = step(0.16, f.x) * step(f.x, 0.84) * step(0.22, f.y) * step(f.y, 0.78);
	float side = abs(v_normal.y) > 0.5 ? 0.0 : 1.0;
	float h = hash(c + vec2(v_seed * 31.7, v_seed * 7.3) + v_normal.xz * 13.1);
	float lit = step(1.0 - density * (0.6 + 0.8 * fract(v_seed * 3.7)), h);
	float pick = hash(c * 1.7 + v_seed);
	vec3 wc = pick < 0.6 ? window_warm : (pick < 0.92 ? window_cool : window_neon);
	float flicker = 0.75 + 0.25 * hash(c + floor(TIME * 0.5 + h * 10.0));
	// Thin horizontal floor bands for scale.
	float band = smoothstep(0.0, 0.04, f.y) * (1.0 - smoothstep(0.96, 1.0, f.y));
	ALBEDO = base_color * (0.8 + 0.2 * band);
	METALLIC = 0.6;
	ROUGHNESS = 0.3 + 0.4 * (1.0 - win);
	EMISSION = wc * win * lit * side * emission_strength * flicker;
}
