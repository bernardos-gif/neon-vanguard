class_name NeonRooftop
extends Node3D
## STAGE 1: NEON DISTRICT ROOFTOP
## A rain-soaked rooftop in a dense futuristic city. The whole stage is built
## procedurally from original geometry, materials and shaders, so it needs no
## external art assets. Combat happens on the plane z = 0 between x = -7 and 7.
## Background animation is purely visual and never touches combat timing.

const FLOOR_Y := 0.0
const PARAPET_Z := -6.0

var environment: Environment
var world_env: WorldEnvironment
var _rain: GPUParticles3D
var _splashes: GPUParticles3D
var _flicker_mats: Array = []      # [material, base_energy, phase, speed]
var _blink_mat: StandardMaterial3D
var _fans: Array[Node3D] = []
var _traffic: Array = []           # [{node, speed, min_x, max_x}]
var _searchlights: Array[Node3D] = []
var _time := 0.0
var _rng := RandomNumberGenerator.new()
var _mat_cache := {}


func _ready() -> void:
	_rng.seed = 20260
	_build_environment()
	_build_lights()
	_build_floor()
	_build_parapet()
	_build_machinery()
	_build_water_tank(Vector3(-13.0, 0, -3.0))
	_build_antenna(Vector3(12.5, 0, -4.6))
	_build_stairwell(Vector3(-16.5, 0, -0.5))
	_build_rooftop_billboard()
	_build_skyline()
	_build_neon_signs()
	_build_searchlights()
	_build_traffic()
	_build_rain()
	_build_moon()
	apply_quality(Settings.quality())
	Settings.changed.connect(_on_settings_changed)


func _on_settings_changed() -> void:
	apply_quality(Settings.quality())


# --------------------------------------------------------------------------
# Environment and lighting
# --------------------------------------------------------------------------

func _build_environment() -> void:
	environment = Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.01, 0.012, 0.04)
	sky_mat.sky_horizon_color = Color(0.22, 0.07, 0.28)
	sky_mat.sky_curve = 0.12
	sky_mat.ground_bottom_color = Color(0.02, 0.01, 0.04)
	sky_mat.ground_horizon_color = Color(0.22, 0.07, 0.28)
	sky_mat.sun_angle_max = 0.0
	sky_mat.sun_curve = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.55
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.05
	environment.tonemap_white = 6.0
	environment.glow_enabled = true
	environment.glow_intensity = 0.85
	environment.glow_strength = 1.0
	environment.glow_bloom = 0.04
	environment.glow_hdr_threshold = 1.1
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	environment.set_glow_level(1, 0.0)
	environment.set_glow_level(2, 1.0)
	environment.set_glow_level(3, 1.0)
	environment.set_glow_level(4, 0.6)
	environment.set_glow_level(5, 0.4)
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.2, 0.1, 0.3)
	environment.fog_light_energy = 1.0
	environment.fog_density = 0.006
	environment.fog_sky_affect = 0.4
	environment.fog_height = -10.0
	environment.fog_height_density = 0.02
	environment.volumetric_fog_density = 0.018
	environment.volumetric_fog_albedo = Color(0.55, 0.6, 0.8)
	environment.volumetric_fog_emission = Color(0.02, 0.01, 0.04)
	environment.volumetric_fog_length = 48.0
	environment.volumetric_fog_ambient_inject = 0.3
	environment.ssr_max_steps = 48
	environment.ssr_fade_in = 0.1
	environment.ssr_fade_out = 2.0
	environment.ssr_depth_tolerance = 0.3
	environment.ssao_radius = 1.2
	environment.ssao_intensity = 1.6
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.06
	environment.adjustment_saturation = 1.12
	world_env = WorldEnvironment.new()
	world_env.environment = environment
	add_child(world_env)


func _build_lights() -> void:
	var moon := DirectionalLight3D.new()
	moon.name = "Moonlight"
	moon.rotation_degrees = Vector3(-38, -28, 0)
	moon.light_color = Color(0.55, 0.65, 1.0)
	moon.light_energy = 0.35
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 40.0
	add_child(moon)
	# Key light over the fighting area: gives clean readable silhouettes and
	# light shafts through the rain.
	var key := SpotLight3D.new()
	key.name = "ArenaKey"
	key.position = Vector3(0, 9.5, 5.5)
	key.light_color = Color(1.0, 0.93, 0.86)
	key.light_energy = 9.0
	key.spot_range = 22.0
	key.spot_angle = 42.0
	key.spot_attenuation = 0.8
	key.shadow_enabled = true
	key.light_volumetric_fog_energy = 1.2
	add_child(key)
	key.look_at(Vector3(0, 0.6, 0), Vector3.UP)
	# Coloured rim lights from behind to separate fighters from the city.
	_rim(Vector3(-9, 5.5, -4.5), Color(0.1, 0.85, 1.0), 14.0)
	_rim(Vector3(9, 5.5, -4.5), Color(1.0, 0.18, 0.75), 14.0)
	# Warm practical from the stairwell door.
	var warm := OmniLight3D.new()
	warm.position = Vector3(-14.6, 2.6, 0.6)
	warm.light_color = Color(1.0, 0.65, 0.3)
	warm.light_energy = 3.0
	warm.omni_range = 7.0
	add_child(warm)


func _rim(pos: Vector3, color: Color, energy: float) -> void:
	var l := SpotLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.spot_range = 20.0
	l.spot_angle = 35.0
	l.shadow_enabled = false
	l.light_volumetric_fog_energy = 2.0
	add_child(l)
	l.look_at(Vector3(pos.x * 0.15, 1.2, 0), Vector3.UP)


# --------------------------------------------------------------------------
# Materials
# --------------------------------------------------------------------------

func _mat(key: String, color: Color, rough := 0.7, metal := 0.0) -> StandardMaterial3D:
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	_mat_cache[key] = m
	return m


func _glow_mat(color: Color, energy: float, flicker := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	if flicker:
		_flicker_mats.append([m, energy, _rng.randf() * 10.0, _rng.randf_range(0.6, 1.6)])
	return m


func _concrete() -> StandardMaterial3D:
	if _mat_cache.has("concrete"):
		return _mat_cache["concrete"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.3, 0.31, 0.34)
	m.roughness = 0.82
	var n := FastNoiseLite.new()
	n.frequency = 0.08
	var tex := NoiseTexture2D.new()
	tex.noise = n
	tex.seamless = true
	tex.width = 256
	tex.height = 256
	tex.as_normal_map = true
	tex.bump_strength = 2.0
	m.normal_enabled = true
	m.normal_texture = tex
	m.normal_scale = 0.4
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.6, 0.6, 0.6)
	_mat_cache["concrete"] = m
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO, shadows := true) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _cyl(parent: Node3D, r_top: float, r_bot: float, h: float, pos: Vector3, mat: Material, rot := Vector3.ZERO, segments := 16) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = r_top
	mesh.bottom_radius = r_bot
	mesh.height = h
	mesh.radial_segments = segments
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


func _label(text: String, pos: Vector3, color: Color, size: int, pixel := 0.02, rot := Vector3.ZERO, flicker := true) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = load("res://assets/fonts/Orbitron-ExtraBold.ttf")
	l.font_size = size
	l.pixel_size = pixel
	l.position = pos
	l.rotation_degrees = rot
	l.shaded = false
	l.double_sided = false
	l.modulate = Color(color.r * 2.2, color.g * 2.2, color.b * 2.2)
	l.outline_size = 10
	l.outline_modulate = Color(color.r, color.g, color.b, 0.35)
	l.line_spacing = -6
	add_child(l)
	if flicker:
		_flicker_mats.append([l, 2.2, _rng.randf() * 10.0, _rng.randf_range(0.5, 1.5)])
	return l


# --------------------------------------------------------------------------
# Rooftop
# --------------------------------------------------------------------------

func _build_floor() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(46, 22)
	plane.subdivide_width = 1
	plane.subdivide_depth = 1
	var sh := ShaderMaterial.new()
	sh.shader = load("res://shaders/wet_floor.gdshader")
	var pn := FastNoiseLite.new()
	pn.frequency = 0.012
	pn.fractal_octaves = 3
	var ptex := NoiseTexture2D.new()
	ptex.noise = pn
	ptex.seamless = true
	ptex.width = 512
	ptex.height = 512
	var dn := FastNoiseLite.new()
	dn.frequency = 0.05
	dn.fractal_octaves = 5
	var dtex := NoiseTexture2D.new()
	dtex.noise = dn
	dtex.seamless = true
	dtex.width = 512
	dtex.height = 512
	sh.set_shader_parameter("puddle_noise", ptex)
	sh.set_shader_parameter("detail_noise", dtex)
	var floor_mi := MeshInstance3D.new()
	floor_mi.name = "WetFloor"
	floor_mi.mesh = plane
	floor_mi.material_override = sh
	floor_mi.position = Vector3(0, FLOOR_Y, 0.5)
	add_child(floor_mi)
	# Slab edge seen at the front of the roof.
	_box(self, Vector3(46, 1.2, 0.3), Vector3(0, -0.6, 11.5), _concrete())
	# Arena markings: boundary strips and a painted centre emblem.
	var line := _glow_mat(Color(0.1, 0.8, 1.0), 1.6)
	for sx in [-7.15, 7.15]:
		_box(self, Vector3(0.08, 0.01, 4.0), Vector3(sx, 0.006, 0), line, Vector3.ZERO, false)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.85, 0.3, 0.7, 0.35)
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.roughness = 0.5
	var ring := TorusMesh.new()
	ring.inner_radius = 2.2
	ring.outer_radius = 2.35
	ring.rings = 64
	var ring_mi := MeshInstance3D.new()
	ring_mi.mesh = ring
	ring_mi.material_override = paint
	ring_mi.scale = Vector3(1, 0.02, 0.45)
	ring_mi.position = Vector3(0, 0.004, -0.3)
	ring_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring_mi)
	# Drainage grates and scattered rooftop clutter (front of stage).
	var grate := _mat("grate", Color(0.08, 0.08, 0.09), 0.4, 0.8)
	for gx in [-5.0, 3.5, 9.0]:
		_box(self, Vector3(0.9, 0.02, 0.5), Vector3(gx, 0.01, 3.2), grate, Vector3.ZERO, false)


func _build_parapet() -> void:
	var c := _concrete()
	_box(self, Vector3(46, 1.05, 0.4), Vector3(0, 0.525, PARAPET_Z), c)
	var cap := _mat("cap", Color(0.42, 0.44, 0.48), 0.35, 0.7)
	_box(self, Vector3(46, 0.06, 0.5), Vector3(0, 1.08, PARAPET_Z), cap)
	# Railing: instanced posts + two rails.
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.025
	post_mesh.bottom_radius = 0.025
	post_mesh.height = 1.0
	post_mesh.radial_segments = 8
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = post_mesh
	var count := 38
	mm.instance_count = count
	for i in count:
		var x := -22.5 + i * 1.2
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(x, 1.6, PARAPET_Z)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _mat("rail", Color(0.55, 0.57, 0.6), 0.3, 0.9)
	add_child(mmi)
	for y in [1.55, 2.1]:
		_cyl(self, 0.035, 0.035, 46.0, Vector3(0, y, PARAPET_Z), _mat("rail", Color(0.55, 0.57, 0.6), 0.3, 0.9), Vector3(0, 0, 90))
	# Pipes along the base of the parapet.
	var pipe := _mat("pipe", Color(0.25, 0.27, 0.3), 0.45, 0.6)
	_cyl(self, 0.12, 0.12, 46.0, Vector3(0, 0.2, PARAPET_Z + 0.45), pipe, Vector3(0, 0, 90))
	_cyl(self, 0.07, 0.07, 46.0, Vector3(0, 0.45, PARAPET_Z + 0.4), _mat("pipe_y", Color(0.6, 0.45, 0.1), 0.5, 0.4), Vector3(0, 0, 90))
	for px in [-18.0, -6.0, 6.0, 18.0]:
		_box(self, Vector3(0.18, 0.5, 0.35), Vector3(px, 0.25, PARAPET_Z + 0.45), pipe)


func _build_machinery() -> void:
	var metal := _mat("ac", Color(0.48, 0.5, 0.53), 0.45, 0.65)
	var dark := _mat("ac_dark", Color(0.08, 0.085, 0.09), 0.5, 0.5)
	for spec in [[Vector3(-9.6, 0, -4.0), 0.0], [Vector3(-11.6, 0, -4.2), 6.0], [Vector3(9.4, 0, -4.1), -4.0]]:
		var root := Node3D.new()
		root.position = spec[0]
		root.rotation_degrees.y = spec[1]
		add_child(root)
		_box(root, Vector3(1.7, 1.1, 1.3), Vector3(0, 0.55, 0), metal)
		_box(root, Vector3(1.5, 0.7, 0.02), Vector3(0, 0.55, 0.66), dark)
		for i in 7:
			_box(root, Vector3(1.4, 0.03, 0.04), Vector3(0, 0.27 + i * 0.09, 0.67), metal, Vector3.ZERO, false)
		_cyl(root, 0.5, 0.5, 0.08, Vector3(0, 1.14, 0), dark, Vector3.ZERO, 24)
		var fan := Node3D.new()
		fan.position = Vector3(0, 1.17, 0)
		root.add_child(fan)
		for b in 4:
			_box(fan, Vector3(0.85, 0.02, 0.14), Vector3.ZERO, metal, Vector3(0, b * 45.0, 12.0), false)
		_fans.append(fan)
	# Vents and junction boxes
	for vx in [-7.8, 7.9, 11.2]:
		_box(self, Vector3(0.5, 0.6, 0.5), Vector3(vx, 0.3, -4.9), metal)
		_cyl(self, 0.22, 0.22, 0.12, Vector3(vx, 0.66, -4.9), dark)
	_box(self, Vector3(0.6, 0.9, 0.3), Vector3(13.6, 0.45, -5.6), _mat("box_y", Color(0.65, 0.5, 0.08), 0.6, 0.2))
	_steam(Vector3(11.2, 0.75, -4.9))
	_steam(Vector3(-7.8, 0.75, -4.9))


func _steam(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.amount = 24
	p.lifetime = 3.0
	p.direction = Vector3(0.3, 1, 0)
	p.spread = 12.0
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 0.8
	p.gravity = Vector3(0.25, 0.2, 0)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.3))
	curve.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(0.7, 0.75, 0.85, 0.18))
	grad.set_color(1, Color(0.7, 0.75, 0.85, 0.0))
	p.color_ramp = grad
	var q := QuadMesh.new()
	q.size = Vector2(0.6, 0.6)
	p.mesh = q
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	tex.gradient = g
	m.albedo_texture = tex
	p.material_override = m
	p.position = pos
	add_child(p)


func _build_water_tank(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var steel := _mat("tank_leg", Color(0.2, 0.21, 0.23), 0.5, 0.8)
	for lx in [-0.9, 0.9]:
		for lz in [-0.9, 0.9]:
			_box(root, Vector3(0.12, 2.0, 0.12), Vector3(lx, 1.0, lz), steel)
	var wood := _mat("tank", Color(0.36, 0.25, 0.18), 0.85, 0.0)
	_cyl(root, 1.3, 1.3, 2.6, Vector3(0, 3.3, 0), wood, Vector3.ZERO, 28)
	for by in [2.4, 3.3, 4.2]:
		_cyl(root, 1.32, 1.32, 0.06, Vector3(0, by, 0), steel, Vector3.ZERO, 28)
	_cyl(root, 0.1, 1.4, 0.8, Vector3(0, 5.0, 0), _mat("tank_roof", Color(0.15, 0.15, 0.17), 0.6, 0.3), Vector3.ZERO, 28)


func _build_antenna(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var steel := _mat("mast", Color(0.4, 0.42, 0.45), 0.4, 0.8)
	_cyl(root, 0.06, 0.14, 11.0, Vector3(0, 5.5, 0), steel)
	for i in 4:
		_box(root, Vector3(1.6 - i * 0.3, 0.04, 0.04), Vector3(0, 3.5 + i * 2.0, 0), steel)
	_blink_mat = _glow_mat(Color(1.0, 0.08, 0.05), 6.0)
	var bulb := SphereMesh.new()
	bulb.radius = 0.12
	bulb.height = 0.24
	var b := MeshInstance3D.new()
	b.mesh = bulb
	b.material_override = _blink_mat
	b.position = Vector3(0, 11.1, 0)
	root.add_child(b)
	# Wind-blown banner
	var q := QuadMesh.new()
	q.size = Vector2(1.8, 0.9)
	q.subdivide_width = 16
	q.subdivide_depth = 4
	var flag := MeshInstance3D.new()
	flag.mesh = q
	var fm := ShaderMaterial.new()
	fm.shader = load("res://shaders/flag.gdshader")
	fm.set_shader_parameter("color", Color(0.85, 0.08, 0.5))
	flag.material_override = fm
	flag.position = Vector3(-0.95, 8.6, 0)
	root.add_child(flag)
	# Sagging cable to the water tank
	var cable_mat := _mat("cable", Color(0.03, 0.03, 0.03), 0.6)
	var a := pos + Vector3(0, 9.0, 0)
	var z := Vector3(-13.0, 4.8, -3.0)
	var segs := 16
	for i in segs:
		var t0 := float(i) / segs
		var t1 := float(i + 1) / segs
		var p0 := a.lerp(z, t0) + Vector3(0, -sin(PI * t0) * 2.2, 0)
		var p1 := a.lerp(z, t1) + Vector3(0, -sin(PI * t1) * 2.2, 0)
		var seg := _cyl(self, 0.02, 0.02, p0.distance_to(p1), (p0 + p1) * 0.5, cable_mat)
		seg.look_at_from_position((p0 + p1) * 0.5, p1, Vector3.UP)
		seg.rotate_object_local(Vector3.RIGHT, PI * 0.5)


func _build_stairwell(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	_box(root, Vector3(3.2, 3.4, 3.6), Vector3(0, 1.7, 0), _concrete())
	_box(root, Vector3(3.4, 0.15, 3.8), Vector3(0, 3.45, 0), _mat("cap", Color(0.42, 0.44, 0.48), 0.35, 0.7))
	_box(root, Vector3(0.05, 2.2, 1.1), Vector3(1.62, 1.1, 0.4), _mat("door", Color(0.12, 0.2, 0.24), 0.4, 0.6))
	_box(root, Vector3(0.12, 0.08, 0.6), Vector3(1.7, 2.55, 0.4), _glow_mat(Color(1.0, 0.7, 0.4), 4.0))
	_label("EXIT", pos + Vector3(1.68, 2.85, 0.4), Color(0.2, 1.0, 0.45), 64, 0.006, Vector3(0, 90, 0))


func _build_rooftop_billboard() -> void:
	var root := Node3D.new()
	root.position = Vector3(4.5, 0, -8.5)
	add_child(root)
	var steel := _mat("scaffold", Color(0.18, 0.19, 0.21), 0.5, 0.8)
	for x in [-3.2, 0.0, 3.2]:
		_box(root, Vector3(0.14, 5.2, 0.14), Vector3(x, 2.6, 0), steel)
	_box(root, Vector3(7.2, 3.4, 0.3), Vector3(0, 6.9, -0.12), steel)
	var q := QuadMesh.new()
	q.size = Vector2(6.8, 3.0)
	var screen := MeshInstance3D.new()
	screen.mesh = q
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/animated_screen.gdshader")
	sm.set_shader_parameter("color_a", Color(0.05, 0.6, 1.0))
	sm.set_shader_parameter("color_b", Color(0.9, 0.1, 0.7))
	sm.set_shader_parameter("energy", 1.4)
	screen.material_override = sm
	screen.position = Vector3(0, 6.9, 0.04)
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(screen)
	_label("VANGUARD\nCHAMPIONSHIP", root.position + Vector3(0, 6.95, 0.1), Color(1, 1, 1), 96, 0.0075, Vector3.ZERO, false)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.5, 0.4, 1.0)
	glow.light_energy = 2.5
	glow.omni_range = 9.0
	glow.position = Vector3(0, 6.0, 1.5)
	root.add_child(glow)


# --------------------------------------------------------------------------
# City
# --------------------------------------------------------------------------

func _build_skyline() -> void:
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = box
	var specs: Array = []
	# Near ring of buildings just beyond the roof edge.
	for i in 26:
		var x := -48.0 + i * 3.8 + _rng.randf_range(-1.0, 1.0)
		var z := _rng.randf_range(-15.0, -26.0)
		specs.append([x, z, _rng.randf_range(5.0, 9.0), _rng.randf_range(5.0, 8.0), _rng.randf_range(-12.0, 26.0)])
	# Mid distance.
	for i in 60:
		var z2 := _rng.randf_range(-35.0, -90.0)
		var spread := 40.0 + absf(z2) * 0.9
		specs.append([_rng.randf_range(-spread, spread), z2, _rng.randf_range(7.0, 14.0), _rng.randf_range(7.0, 12.0), _rng.randf_range(0.0, 70.0)])
	# Far skyline with towers.
	for i in 90:
		var z3 := _rng.randf_range(-110.0, -280.0)
		var spread3 := 60.0 + absf(z3) * 0.9
		var top := _rng.randf_range(10.0, 110.0)
		if _rng.randf() < 0.15:
			top += 60.0
		specs.append([_rng.randf_range(-spread3, spread3), z3, _rng.randf_range(10.0, 24.0), _rng.randf_range(10.0, 20.0), top])
	# Side blocks so the city wraps around the roof.
	for side in [-1.0, 1.0]:
		for i in 10:
			specs.append([side * _rng.randf_range(30.0, 60.0), _rng.randf_range(-12.0, 25.0), _rng.randf_range(6.0, 12.0), _rng.randf_range(6.0, 12.0), _rng.randf_range(-5.0, 35.0)])
	mm.instance_count = specs.size()
	var bottom := -120.0
	var tall_tops: Array = []
	for i in specs.size():
		var s: Array = specs[i]
		var top: float = s[4]
		var h := top - bottom
		var basis := Basis.IDENTITY.scaled(Vector3(s[2], h, s[3]))
		mm.set_instance_transform(i, Transform3D(basis, Vector3(s[0], bottom + h * 0.5, s[1])))
		mm.set_instance_custom_data(i, Color(_rng.randf(), 0, 0, 0))
		if top > 50.0 and tall_tops.size() < 24:
			tall_tops.append(Vector3(s[0], top + 0.6, s[1]))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Skyline"
	mmi.multimesh = mm
	var sh := ShaderMaterial.new()
	sh.shader = load("res://shaders/building_windows.gdshader")
	mmi.material_override = sh
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	# Aircraft warning lights on tall towers (blink in sync).
	var bulb := SphereMesh.new()
	bulb.radius = 0.6
	bulb.height = 1.2
	var bm := MultiMesh.new()
	bm.transform_format = MultiMesh.TRANSFORM_3D
	bm.mesh = bulb
	bm.instance_count = tall_tops.size()
	for i in tall_tops.size():
		bm.set_instance_transform(i, Transform3D(Basis.IDENTITY, tall_tops[i]))
	var bmi := MultiMeshInstance3D.new()
	bmi.multimesh = bm
	if _blink_mat == null:
		_blink_mat = _glow_mat(Color(1.0, 0.08, 0.05), 6.0)
	bmi.material_override = _blink_mat
	bmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bmi)


func _build_neon_signs() -> void:
	# Original fictional brands only.
	var signs := [
		["V\nO\nL\nT\nE\nX", Vector3(-17.0, 9.0, -14.6), Color(1.0, 0.15, 0.7), 150, Vector2(2.2, 11.0)],
		["NOODLE 24H", Vector3(-6.5, 5.2, -14.6), Color(0.15, 0.9, 1.0), 120, Vector2(8.5, 2.0)],
		["HOTEL ORBITA", Vector3(19.0, 13.0, -20.6), Color(1.0, 0.65, 0.2), 140, Vector2(10.5, 2.2)],
		["KAIZEN LABS", Vector3(-30.0, 16.0, -24.6), Color(0.4, 1.0, 0.6), 130, Vector2(9.5, 2.0)],
		["2 0 7 7", Vector3(30.0, 6.0, -15.6), Color(0.6, 0.4, 1.0), 120, Vector2(6.0, 2.0)],
	]
	var frame := _mat("sign_frame", Color(0.04, 0.04, 0.05), 0.4, 0.7)
	for s in signs:
		var pos: Vector3 = s[1]
		var color: Color = s[2]
		var size: Vector2 = s[4]
		_box(self, Vector3(size.x, size.y, 0.25), pos + Vector3(0, 0, -0.2), frame)
		# Neon tube border
		var tube := _glow_mat(color, 4.0, true)
		_box(self, Vector3(size.x, 0.06, 0.06), pos + Vector3(0, size.y * 0.5 - 0.1, 0), tube, Vector3.ZERO, false)
		_box(self, Vector3(size.x, 0.06, 0.06), pos + Vector3(0, -size.y * 0.5 + 0.1, 0), tube, Vector3.ZERO, false)
		_label(s[0], pos + Vector3(0, 0, 0.05), color, s[3], 0.012)
		var l := OmniLight3D.new()
		l.light_color = color
		l.light_energy = 2.5
		l.omni_range = 10.0
		l.position = pos + Vector3(0, 0, 2.0)
		add_child(l)
	# Animated screen on a nearby tower
	var q := QuadMesh.new()
	q.size = Vector2(9.0, 5.0)
	var screen := MeshInstance3D.new()
	screen.mesh = q
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/animated_screen.gdshader")
	sm.set_shader_parameter("color_a", Color(1.0, 0.5, 0.1))
	sm.set_shader_parameter("color_b", Color(0.2, 0.3, 1.0))
	sm.set_shader_parameter("speed", 0.6)
	screen.material_override = sm
	screen.position = Vector3(10.0, 16.0, -24.5)
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(screen)
	_label("SYNTH\nCOLA", Vector3(10.0, 16.0, -24.4), Color(1, 1, 1), 160, 0.012, Vector3.ZERO, false)


func _build_searchlights() -> void:
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.3
	cyl.bottom_radius = 7.0
	cyl.height = 120.0
	cyl.radial_segments = 20
	cyl.cap_top = false
	cyl.cap_bottom = false
	for spec in [[Vector3(-60, -20, -140), Color(0.5, 0.7, 1.0)], [Vector3(70, -20, -170), Color(1.0, 0.5, 0.9)]]:
		var pivot := Node3D.new()
		pivot.position = spec[0]
		add_child(pivot)
		var beam := MeshInstance3D.new()
		beam.mesh = cyl
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/light_beam.gdshader")
		m.set_shader_parameter("color", spec[1])
		m.set_shader_parameter("intensity", 0.18)
		beam.material_override = m
		beam.position = Vector3(0, 60, 0)
		beam.rotation_degrees = Vector3(180, 0, 0)
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(beam)
		_searchlights.append(pivot)


func _build_traffic() -> void:
	var body := BoxMesh.new()
	body.size = Vector3(2.2, 0.5, 1.0)
	var light := BoxMesh.new()
	light.size = Vector3(0.1, 0.12, 0.8)
	var body_mat := _mat("car", Color(0.1, 0.1, 0.12), 0.3, 0.8)
	var tail := _glow_mat(Color(1.0, 0.1, 0.1), 6.0)
	var head := _glow_mat(Color(0.9, 0.95, 1.0), 8.0)
	var under := _glow_mat(Color(0.2, 0.8, 1.0), 4.0)
	for i in 34:
		var lane_z := _rng.randf_range(-22.0, -140.0)
		var y := _rng.randf_range(6.0, 40.0)
		var dir := 1.0 if _rng.randf() < 0.5 else -1.0
		var car := Node3D.new()
		car.position = Vector3(_rng.randf_range(-120.0, 120.0), y, lane_z)
		car.rotation_degrees.y = 0.0 if dir > 0 else 180.0
		add_child(car)
		var b := MeshInstance3D.new()
		b.mesh = body
		b.material_override = body_mat
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		car.add_child(b)
		var t := MeshInstance3D.new()
		t.mesh = light
		t.material_override = tail
		t.position = Vector3(-1.12, 0, 0)
		car.add_child(t)
		var h := MeshInstance3D.new()
		h.mesh = light
		h.material_override = head
		h.position = Vector3(1.12, 0, 0)
		car.add_child(h)
		var u := MeshInstance3D.new()
		u.mesh = light
		u.material_override = under
		u.position = Vector3(0, -0.28, 0)
		u.scale = Vector3(14, 0.3, 1.0)
		car.add_child(u)
		_traffic.append({"node": car, "speed": dir * _rng.randf_range(10.0, 28.0)})


func _build_rain() -> void:
	_rain = GPUParticles3D.new()
	_rain.name = "Rain"
	_rain.amount = 4000
	_rain.lifetime = 0.95
	_rain.preprocess = 1.0
	_rain.visibility_aabb = AABB(Vector3(-22, -16, -12), Vector3(44, 20, 24))
	_rain.position = Vector3(0, 14.0, 0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(20, 0.5, 9)
	pm.direction = Vector3(0.12, -1, 0)
	pm.spread = 2.0
	pm.initial_velocity_min = 13.0
	pm.initial_velocity_max = 16.0
	pm.gravity = Vector3(0, -9.8, 0)
	pm.particle_flag_align_y = true
	_rain.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.012, 0.5)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.75, 0.82, 1.0, 0.28)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	_rain.draw_pass_1 = q
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_rain)
	_splashes = GPUParticles3D.new()
	_splashes.name = "Splashes"
	_splashes.amount = 500
	_splashes.lifetime = 0.25
	_splashes.visibility_aabb = AABB(Vector3(-22, -1, -10), Vector3(44, 3, 20))
	_splashes.position = Vector3(0, 0.02, 1.0)
	var sp := ParticleProcessMaterial.new()
	sp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	sp.emission_box_extents = Vector3(20, 0.0, 8)
	sp.direction = Vector3(0, 1, 0)
	sp.spread = 40.0
	sp.initial_velocity_min = 0.6
	sp.initial_velocity_max = 1.4
	sp.gravity = Vector3(0, -9.8, 0)
	sp.scale_min = 0.5
	sp.scale_max = 1.0
	_splashes.process_material = sp
	var sq := QuadMesh.new()
	sq.size = Vector2(0.03, 0.03)
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.albedo_color = Color(0.8, 0.88, 1.0, 0.45)
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sq.material = smat
	_splashes.draw_pass_1 = sq
	_splashes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_splashes)


func _build_moon() -> void:
	var s := SphereMesh.new()
	s.radius = 14.0
	s.height = 28.0
	var mi := MeshInstance3D.new()
	mi.mesh = s
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.75, 0.82, 1.0) * 1.6
	mi.material_override = m
	mi.position = Vector3(-140, 150, -420)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# --------------------------------------------------------------------------
# Quality and animation
# --------------------------------------------------------------------------

func apply_quality(q: int) -> void:
	environment.ssr_enabled = q >= 1
	environment.ssao_enabled = q >= 1
	environment.ssil_enabled = q >= 3
	environment.volumetric_fog_enabled = q >= 2
	environment.glow_enabled = true
	environment.ssr_max_steps = 32 if q <= 2 else 64
	_rain.amount = [1200, 2500, 4000, 6000][q]
	_splashes.emitting = q >= 1
	_splashes.visible = q >= 1


func _process(delta: float) -> void:
	_time += delta
	for f in _fans:
		f.rotate_y(delta * 9.0)
	for entry in _flicker_mats:
		var obj = entry[0]
		var base: float = entry[1]
		var phase: float = entry[2]
		var speed: float = entry[3]
		var v := 0.92 + 0.08 * sin(_time * 3.0 * speed + phase)
		# Occasional brief neon stutter.
		if fmod(_time * speed + phase, 7.0) < 0.12:
			v = 0.35
		if obj is StandardMaterial3D:
			obj.emission_energy_multiplier = base * v
		elif obj is Label3D:
			var c: Color = obj.modulate
			var n := Color(c.r, c.g, c.b).v
			if n > 0.0:
				var target := base * v
				obj.modulate = Color(c.r / maxf(n, 0.001) * target, c.g / maxf(n, 0.001) * target, c.b / maxf(n, 0.001) * target)
	if _blink_mat:
		_blink_mat.emission_energy_multiplier = 7.0 if fmod(_time, 1.6) < 0.25 else 0.4
	for car in _traffic:
		var n: Node3D = car["node"]
		n.position.x += car["speed"] * delta
		if n.position.x > 140.0:
			n.position.x = -140.0
		elif n.position.x < -140.0:
			n.position.x = 140.0
	for i in _searchlights.size():
		var s := _searchlights[i]
		s.rotation_degrees = Vector3(sin(_time * 0.21 + i * 2.0) * 28.0, 0, sin(_time * 0.17 + i) * 30.0)
