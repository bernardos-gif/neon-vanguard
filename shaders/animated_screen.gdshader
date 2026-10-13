// Animated holographic advertising screen.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 color_a : source_color = vec3(0.1, 0.8, 1.0);
uniform vec3 color_b : source_color = vec3(1.0, 0.2, 0.8);
uniform float speed = 1.0;
uniform float energy = 2.2;

void fragment() {
	vec2 uv = UV;
	float wave = sin((uv.x * 5.0 + TIME * speed * 0.7) + sin(uv.y * 4.0 + TIME * speed)) * 0.5 + 0.5;
	float bands = sin((uv.y * 9.0 - TIME * speed * 1.3) * 3.14159) * 0.5 + 0.5;
	float scan = 0.82 + 0.18 * sin(uv.y * 420.0);
	float border = step(0.02, uv.x) * step(uv.x, 0.98) * step(0.04, uv.y) * step(uv.y, 0.96);
	vec3 c = mix(color_a, color_b, smoothstep(0.2, 0.8, wave * bands));
	float glitch = step(0.985, fract(sin(floor(TIME * 8.0) * 12.9898) * 43758.5453));
	c *= 1.0 - glitch * 0.5 * step(0.5, fract(uv.y * 20.0));
	ALBEDO = c * energy * scan * mix(0.3, 1.0, border);
}
