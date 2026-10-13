// Soft volumetric-looking searchlight cone (cheap additive fake).
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec3 color : source_color = vec3(0.6, 0.8, 1.0);
uniform float intensity = 0.25;

void fragment() {
	float along = 1.0 - UV.y;
	float fres = pow(clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.0);
	ALBEDO = color * intensity * fres * along;
	ALPHA = 1.0;
}
