class_name Widok3D
extends RefCounted
## Buduje widok 3D w niskiej rozdzielczości (SubViewport skalowany bez wygładzania) z post-processem PS1.
## Interfejs (HUD, ekwipunek) rysuje się poza nim w pełnej rozdzielczości.

const POMNIEJSZENIE := 1   # pełna rozdzielczość (styl Iron Blight: pikselowe są tekstury, nie obraz)


static func zbuduj(rodzic: Node, mgla := 0.06, ambient := 0.085) -> Dictionary:
	var kont := SubViewportContainer.new()
	kont.name = "Widok3D"
	kont.stretch = true
	kont.stretch_shrink = POMNIEJSZENIE
	kont.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	kont.set_anchors_preset(Control.PRESET_FULL_RECT)
	kont.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/psx_post_vp.gdshader")
	kont.material = mat
	rodzic.add_child(kont)
	var vp := SubViewport.new()
	vp.name = "Viewport"
	vp.msaa_3d = Viewport.MSAA_2X
	vp.audio_listener_enable_3d = true
	vp.handle_input_locally = false
	vp.physics_object_picking = false
	vp.positional_shadow_atlas_size = 2048
	kont.add_child(vp)
	var swiat := Node3D.new()
	swiat.name = "Swiat"
	vp.add_child(swiat)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.005, 0.005, 0.008)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# zimny, granatowy ambient nocy kontra ciepłe żółte lampy
	env.ambient_light_color = Color(0.36, 0.42, 0.62)
	env.ambient_light_energy = ambient * 1.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.15
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 0.9
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 0.92
	env.fog_enabled = true
	env.fog_light_color = Color(0.03, 0.035, 0.06)
	env.fog_density = mgla * 0.7
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	swiat.add_child(we)
	return {"kontener": kont, "viewport": vp, "swiat": swiat, "material": mat, "env": env}


## Wypieka siatkę nawigacji z kolizji statycznych świata (warstwa 1).
static func wypiecz_nawigacje(swiat: Node3D) -> NavigationRegion3D:
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = Balistyka.WARSTWA_SWIAT
	nm.agent_radius = 0.35
	nm.agent_height = 1.7
	nm.agent_max_climb = 0.3
	nm.agent_max_slope = 40.0
	nm.cell_size = 0.1
	nm.cell_height = 0.1
	var mapa := swiat.get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(mapa, 0.1)
	NavigationServer3D.map_set_cell_height(mapa, 0.1)
	var region := NavigationRegion3D.new()
	region.name = "Nawigacja"
	swiat.add_child(region)
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, swiat)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	region.navigation_mesh = nm
	return region
