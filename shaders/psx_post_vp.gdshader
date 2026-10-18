// Post-process widoku 3D: delikatna winieta i ziarno filmowe, efekty bólu (czerwień na brzegach, rozmycie).
// Bez ditheringu i redukcji kolorów – obraz w pełnej rozdzielczości jak w Iron Blight.
shader_type canvas_item;

uniform float color_levels = 256.0;
uniform float dither_strength : hint_range(0.0, 2.0) = 0.0;
uniform float vignette : hint_range(0.0, 2.0) = 0.55;
uniform float grain : hint_range(0.0, 0.2) = 0.018;
uniform float jasnosc = 1.0;
uniform vec4 kolor_bolu : source_color = vec4(0.6, 0.0, 0.0, 0.0);
uniform float rozmycie_bol = 0.0;

void fragment() {
	vec2 res = vec2(textureSize(TEXTURE, 0));
	vec3 c = texture(TEXTURE, UV).rgb;
	if (rozmycie_bol > 0.0) {
		vec2 o = vec2(rozmycie_bol * 1.5 / res.x, 0.0);
		vec2 o2 = vec2(0.0, rozmycie_bol * 1.5 / res.y);
		c = (c * 2.0 + texture(TEXTURE, UV + o).rgb + texture(TEXTURE, UV - o).rgb + texture(TEXTURE, UV + o2).rgb + texture(TEXTURE, UV - o2).rgb) / 6.0;
	}
	c *= jasnosc;
	vec2 q = UV - 0.5;
	float v = dot(q, q);
	c *= clamp(1.0 - v * vignette * 2.2, 0.0, 1.0);
	c = mix(c, kolor_bolu.rgb, kolor_bolu.a * smoothstep(0.08, 0.32, v));
	vec2 px = floor(UV * res * 0.5);
	float n = fract(sin(dot(px + floor(TIME * 24.0) * 7.13, vec2(12.9898, 78.233))) * 43758.5453);
	c += (n - 0.5) * grain;
	COLOR = vec4(c, 1.0);
}
