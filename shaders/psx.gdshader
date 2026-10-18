// Shader świata w stylu Iron Blight: pełna rozdzielczość i normalne oświetlenie per piksel (cienie, lampy),
// a "retro" bierze się z tekstur w niskiej rozdzielczości bez wygładzania (ostre piksele, mipmapy nearest).
// Nazwa pliku zostaje dla zgodności (psx.gdshader), parametry snap/affine są ignorowane.
shader_type spatial;
render_mode diffuse_lambert_wrap, specular_schlick_ggx, cull_back;

uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float snap_resolution = 360.0;
uniform float affine_strength : hint_range(0.0, 1.0) = 0.0;
uniform bool use_vertex_color = false;
uniform bool use_emission = false;
uniform float emission_energy = 1.0;
uniform float chropowatosc : hint_range(0.0, 1.0) = 0.82;
uniform float polysk : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	vec3 c = t.rgb * tint.rgb;
	if (use_vertex_color) {
		c *= COLOR.rgb;
	}
	ALBEDO = c;
	ROUGHNESS = chropowatosc;
	SPECULAR = polysk;
	if (use_emission) {
		EMISSION = c * emission_energy;
	}
}
