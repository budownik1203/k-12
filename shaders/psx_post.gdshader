// Post-process: ograniczona głębia koloru z ditheringiem Bayera 4x4 (jak 15-bitowy kolor PS1).
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float color_levels = 32.0;
uniform float dither_strength : hint_range(0.0, 2.0) = 1.0;
uniform float vignette : hint_range(0.0, 2.0) = 0.9;
uniform float grain : hint_range(0.0, 0.2) = 0.035;

const float BAYER[16] = float[](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	vec2 q = SCREEN_UV - 0.5;
	c *= clamp(1.0 - dot(q, q) * vignette * 2.2, 0.0, 1.0);
	float n = fract(sin(dot(floor(FRAGCOORD.xy) + floor(TIME * 24.0) * 7.13, vec2(12.9898, 78.233))) * 43758.5453);
	c += (n - 0.5) * grain;
	ivec2 p = ivec2(mod(FRAGCOORD.xy, 4.0));
	float d = (BAYER[p.y * 4 + p.x] / 16.0 - 0.5) * dither_strength;
	c = floor(c * color_levels + d + 0.5) / color_levels;
	COLOR = vec4(c, 1.0);
}
