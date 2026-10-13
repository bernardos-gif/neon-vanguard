// Wind-driven cloth banner (vertex animation).
shader_type spatial;
render_mode cull_disabled;

uniform vec3 color : source_color = vec3(0.9, 0.1, 0.5);
uniform float strength = 0.18;

void vertex() {
	float k = UV.x;
	VERTEX.z += sin(TIME * 4.0 + UV.x * 6.0) * strength * k + sin(TIME * 7.3 + UV.y * 4.0) * 0.04 * k;
	VERTEX.y += sin(TIME * 3.0 + UV.x * 5.0) * 0.03 * k;
}

void fragment() {
	float stripe = step(0.45, UV.y) * step(UV.y, 0.55);
	ALBEDO = mix(color, vec3(0.95), stripe);
	ROUGHNESS = 0.8;
	EMISSION = color * 0.15;
}
