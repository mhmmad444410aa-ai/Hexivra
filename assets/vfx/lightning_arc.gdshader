// Adapted from Lightning arc by LordNull (CC0).
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform sampler2D displacement_noise : repeat_enable;
uniform vec4 tint : source_color = vec4(0.36, 0.87, 1.0, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	float z = 1.0 - abs(UV.y * 2.0 - 1.0);
	float time = TIME * 3.0;
	float a = floor(time);
	float mix_weight = smoothstep(0.0, 1.0, fract(time));
	float p = UV.y * 0.72;
	float n0 = texture(displacement_noise, vec2(mod(a, 10.0) * 0.1, p)).r;
	float n1 = texture(displacement_noise, vec2(mod(a + 1.0, 10.0) * 0.1, p)).r;
	VERTEX.x += (mix(n0, n1, mix_weight) * 2.0 - 1.0) * z * 0.18;
}

void fragment() {
	float core = 1.0 - smoothstep(0.06, 0.49, abs(UV.x - 0.5));
	ALBEDO = tint.rgb;
	ALPHA = strength * core * smoothstep(0.0, 0.12, min(UV.y, 1.0 - UV.y));
}
