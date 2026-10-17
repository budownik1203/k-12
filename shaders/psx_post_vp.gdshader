// Post-process widoku 3D (na SubViewportContainer): winieta, ziarno, 15-bitowy kolor z ditheringiem Bayera.
shader_type canvas_item;

uniform float color_levels = 32.0;
uniform float dither_strength : hint_range(0.0, 2.0) = 1.0;
uniform float vignette : hint_range(0.0, 2.0) = 0.9;
uniform float grain : hint_range(0.0, 0.2) = 0.035;
uniform float jasnosc = 1.0;
uniform vec4 kolor_bolu : source_color = vec4(0.6, 0.0, 0.0, 0.0);
uniform float rozmycie_bol = 0.0;

const float BAYER[16] = float[](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec2 res = vec2(textureSize(TEXTURE, 0));
	vec3 c = texture(TEXTURE, UV).rgb;
	if (rozmycie_bol > 0.0) {
		vec2 o = vec2(rozmycie_bol / res.x, 0.0);
		c = (c + texture(TEXTURE, UV + o).rgb + texture(TEXTURE, UV - o).rgb) / 3.0;
	}
	c *= jasnosc;
	vec2 q = UV - 0.5;
	float v = dot(q, q);
	c *= clamp(1.0 - v * vignette * 2.2, 0.0, 1.0);
	c = mix(c, kolor_bolu.rgb, kolor_bolu.a * smoothstep(0.08, 0.32, v));
	vec2 px = floor(UV * res);
	float n = fract(sin(dot(px + floor(TIME * 24.0) * 7.13, vec2(12.9898, 78.233))) * 43758.5453);
	c += (n - 0.5) * grain;
	ivec2 p = ivec2(mod(px, 4.0));
	float d = (BAYER[p.y * 4 + p.x] / 16.0 - 0.5) * dither_strength;
	c = floor(c * color_levels + d + 0.5) / color_levels;
	COLOR = vec4(c, 1.0);
}
