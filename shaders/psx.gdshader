// Shader w stylu PS1: drgające wierzchołki, częściowo afiniczne mapowanie tekstur,
// oświetlenie liczone per wierzchołek i piksele bez filtrowania.
shader_type spatial;
render_mode vertex_lighting, specular_disabled, diffuse_lambert, cull_back;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
// Rozdzielczość siatki, do której przyciągane są wierzchołki (pionowo). Mniej = mocniejsze drganie.
uniform float snap_resolution = 360.0;
// 0 = poprawne mapowanie perspektywiczne, 1 = pełne afiniczne jak na PS1.
uniform float affine_strength : hint_range(0.0, 1.0) = 0.45;
uniform bool use_vertex_color = false;
uniform bool use_emission = false;
uniform float emission_energy = 1.0;

varying vec3 affine_uv;
varying vec2 persp_uv;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (clip.w > 0.05) {
		vec2 grid = vec2(snap_resolution * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, snap_resolution) * 0.5;
		clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	}
	POSITION = clip;
	persp_uv = UV;
	float w = max(clip.w, 0.05);
	affine_uv = vec3(UV * w, w);
}

void fragment() {
	vec2 uv = mix(persp_uv, affine_uv.xy / affine_uv.z, affine_strength);
	vec3 c = texture(albedo_tex, uv).rgb * tint.rgb;
	if (use_vertex_color) {
		c *= COLOR.rgb;
	}
	ALBEDO = c;
	if (use_emission) {
		EMISSION = c * emission_energy;
	}
}
