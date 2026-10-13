// Wet rooftop concrete with procedural puddles and animated rain ripples.
shader_type spatial;
render_mode blend_mix, cull_back;

uniform sampler2D puddle_noise : filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_noise : filter_linear_mipmap, repeat_enable;
uniform vec3 concrete_color : source_color = vec3(0.26, 0.27, 0.3);
uniform float puddle_threshold = 0.52;
uniform float ripple_strength = 1.0;

varying vec3 v_world;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453);
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 w = v_world.xz;
	float n = texture(puddle_noise, w * 0.06).r;
	float d = texture(detail_noise, w * 0.45).r;
	float d2 = texture(detail_noise, w * 2.3).r;
	float puddle = smoothstep(puddle_threshold, puddle_threshold + 0.06, n);
	float damp = smoothstep(puddle_threshold - 0.18, puddle_threshold, n);
	vec3 col = concrete_color * (0.65 + 0.45 * d) * (0.9 + 0.2 * d2);
	// Expansion joints between slabs.
	vec2 slab = abs(fract(w / vec2(3.0, 3.0)) - 0.5);
	float joint = 1.0 - smoothstep(0.485, 0.495, max(slab.x, slab.y));
	col *= mix(0.55, 1.0, joint);
	// Rain ripples: expanding rings in a jittered grid.
	vec2 g = w * 1.6;
	vec2 cell_id = floor(g);
	vec2 fr = fract(g) - 0.5;
	float rnd = hash(cell_id);
	float t = fract(TIME * 0.9 + rnd);
	vec2 off = vec2(hash(cell_id + 3.1), hash(cell_id + 7.7)) - 0.5;
	float r = length(fr - off * 0.6);
	float ring = smoothstep(0.04, 0.0, abs(r - t * 0.45)) * (1.0 - t);
	ALBEDO = mix(col, col * 0.25, max(puddle, damp * 0.45));
	ROUGHNESS = mix(mix(0.78, 0.4, damp), 0.04, puddle) + ring * 0.25 * puddle * ripple_strength;
	SPECULAR = 0.5;
	METALLIC = 0.0;
	NORMAL_MAP = normalize(vec3(0.5 + (d2 - 0.5) * 0.25 * (1.0 - puddle), 0.5 + (d - 0.5) * 0.2 * (1.0 - puddle), 1.0));
}
