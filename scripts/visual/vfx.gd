class_name Vfx
extends Node3D
## Impact effects: spark bursts, flash cards, shock rings, dust and brief
## point lights that illuminate nearby surfaces. Spawned from combat events.

var _spark_mesh: QuadMesh
var _flash_mesh: QuadMesh
var _ring_mesh: TorusMesh
var _dust_mesh: QuadMesh
var _glow_tex: GradientTexture2D
var _quality := 2


func _ready() -> void:
	_glow_tex = GradientTexture2D.new()
	_glow_tex.fill = GradientTexture2D.FILL_RADIAL
	_glow_tex.fill_from = Vector2(0.5, 0.5)
	_glow_tex.fill_to = Vector2(1.0, 0.5)
	_glow_tex.width = 64
	_glow_tex.height = 64
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	_glow_tex.gradient = g
	_spark_mesh = QuadMesh.new()
	_spark_mesh.size = Vector2(0.03, 0.16)
	_flash_mesh = QuadMesh.new()
	_flash_mesh.size = Vector2(1, 1)
	_ring_mesh = TorusMesh.new()
	_ring_mesh.inner_radius = 0.46
	_ring_mesh.outer_radius = 0.5
	_ring_mesh.rings = 32
	_ring_mesh.ring_segments = 4
	_dust_mesh = QuadMesh.new()
	_dust_mesh.size = Vector2(0.35, 0.35)
	_quality = Settings.quality()
	Settings.changed.connect(_on_settings_changed)


func _on_settings_changed() -> void:
	_quality = Settings.quality()


func _additive(color: Color, tex: Texture2D = null, billboard := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = color
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if tex:
		m.albedo_texture = tex
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.no_depth_test = false
	return m


## strength: 0 light .. 3 special.
func hit(pos: Vector3, color: Color, strength: int, blocked := false) -> void:
	var s := float(strength + 1)
	var spark_color := color.lightened(0.3) * (2.5 if not blocked else 1.6)
	_sparks(pos, spark_color, int((10 + 8 * s) * (0.6 if _quality == 0 else 1.0)), 3.0 + s * 1.6, 0.22 + s * 0.04)
	_flash(pos, Color(spark_color.r, spark_color.g, spark_color.b, 0.9), 0.35 + s * 0.22, 0.12 + s * 0.02)
	if strength >= 2 or blocked:
		_ring(pos, color * 2.0, 0.6 + s * 0.35, 0.22)
	_light(pos, color, 2.0 + s * 1.5, 2.5 + s * 0.8, 0.12 + s * 0.03)


func clash(pos: Vector3, color: Color) -> void:
	_sparks(pos, color * 3.0, 30, 6.0, 0.35)
	_flash(pos, color, 1.2, 0.2)
	_ring(pos, color * 2.0, 1.6, 0.3)
	_light(pos, color, 5.0, 4.0, 0.2)


func dust(pos: Vector3, amount := 14) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = 0.8
	p.explosiveness = 0.95
	p.direction = Vector3(0, 1, 0)
	p.spread = 80.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.8
	p.gravity = Vector3(0, -0.8, 0)
	p.damping_min = 1.5
	p.damping_max = 2.5
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1, 1.4))
	p.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(0.55, 0.58, 0.65, 0.5))
	grad.set_color(1, Color(0.55, 0.58, 0.65, 0.0))
	p.color_ramp = grad
	p.mesh = _dust_mesh
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = _glow_tex
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p.material_override = m
	p.position = pos
	add_child(p)
	p.emitting = true
	_free_later(p, 1.2)


func _sparks(pos: Vector3, color: Color, amount: int, speed: float, life: float) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = maxi(amount, 4)
	p.lifetime = life
	p.explosiveness = 1.0
	p.direction = Vector3(0, 0.3, 0)
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -6.0, 0)
	p.particle_flag_align_y = true
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = grad
	p.mesh = _spark_mesh
	var m := _additive(color, null, false)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	p.material_override = m
	p.position = pos
	add_child(p)
	p.emitting = true
	_free_later(p, life + 0.3)


func _flash(pos: Vector3, color: Color, size: float, life: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _flash_mesh
	var m := _additive(color, _glow_tex)
	mi.material_override = m
	mi.position = pos + Vector3(0, 0, 0.3)
	mi.scale = Vector3.ONE * size * 0.4
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * size, life).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, life)
	_free_later(mi, life + 0.05)


func _ring(pos: Vector3, color: Color, size: float, life: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _ring_mesh
	var m := _additive(color, null, false)
	mi.material_override = m
	mi.position = pos + Vector3(0, 0, 0.2)
	mi.rotation_degrees = Vector3(90, 0, 0)
	mi.scale = Vector3.ONE * 0.2
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(size, 0.2, size), life).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, life)
	_free_later(mi, life + 0.05)


func _light(pos: Vector3, color: Color, energy: float, radius: float, life: float) -> void:
	if _quality == 0:
		return
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = radius
	l.shadow_enabled = false
	l.position = pos + Vector3(0, 0, 0.4)
	add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, life)
	_free_later(l, life + 0.05)


func _free_later(n: Node, seconds: float) -> void:
	# The tween belongs to the effect node itself, so it can never outlive it.
	var tw := n.create_tween()
	tw.tween_interval(seconds)
	tw.tween_callback(n.queue_free)
