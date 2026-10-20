// Naklejka na ścianie / podłodze (pęknięcia, graffiti, zacieki): oświetlenie jak shader świata,
// przezroczystość jako dithering 4x4 (bez sortowania – rysowana w przebiegu nieprzezroczystym).
shader_type spatial;
render_mode diffuse_lambert_wrap, specular_schlick_ggx, cull_back, depth_draw_opaque;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_disable;
uniform float chropowatosc : hint_range(0.0, 1.0) = 0.9;

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	// dithering w siatce tekseli atlasu (64 px/m) – stały na ścianie, jak piksele tekstury
	ivec2 p = ivec2(floor(UV * 1024.0)) % 4;
	float prog = (BAYER[p.y * 4 + p.x] + 0.5) / 16.0;
	if (t.a < prog) {
		discard;
	}
	ALBEDO = t.rgb;
	ROUGHNESS = chropowatosc;
	SPECULAR = 0.2;
}
