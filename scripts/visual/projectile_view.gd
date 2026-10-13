class_name ProjectileView
extends Node3D
## Glowing energy orb with a particle trail for projectile attacks.

var sim: ProjectileSim
var _core: MeshInstance3D
var _ring: MeshInstance3D
var _prev := Vector2.ZERO
var _cur := Vector2.ZERO


func setup(p_sim: ProjectileSim, color: Color) -> void:
	sim = p_sim
	_prev = sim.pos
	_cur = sim.pos
	position = Vector3(sim.pos.x, sim.pos.y, 0)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = color * 3.0
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.16
	core_mesh.height = 0.32
	_core = MeshInstance3D.new()
	_core.mesh = core_mesh
	_core.material_override = glow
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_core)
	var shell := StandardMaterial3D.new()
	shell.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shell.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shell.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	shell.albedo_color = Color(color.r, color.g, color.b, 0.35)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.2
	torus.outer_radius = 0.26
	_ring = MeshInstance3D.new()
	_ring.mesh = torus
	_ring.material_override = shell
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 3.0
	light.omni_range = 3.0
	add_child(light)
	var trail := CPUParticles3D.new()
	trail.amount = 40
	trail.lifetime = 0.35
	trail.local_coords = false
	trail.direction = Vector3(-sim.dir, 0, 0)
	trail.spread = 25.0
	trail.initial_velocity_min = 0.3
	trail.initial_velocity_max = 1.2
	trail.gravity = Vector3.ZERO
	var tq := QuadMesh.new()
	tq.size = Vector2(0.14, 0.14)
	trail.mesh = tq
	var tm := shell.duplicate()
	tm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	tm.vertex_color_use_as_albedo = true
	tm.albedo_color = Color(color.r * 2.0, color.g * 2.0, color.b * 2.0, 0.8)
	trail.material_override = tm
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	trail.color_ramp = grad
	add_child(trail)


func sim_ticked() -> void:
	_prev = _cur
	_cur = sim.pos


func _process(delta: float) -> void:
	var p := _prev.lerp(_cur, Engine.get_physics_interpolation_fraction())
	position = Vector3(p.x, p.y, 0.0)
	_ring.rotation.x += delta * 9.0
	_ring.rotation.y += delta * 5.0
	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.03) * 0.12
	_core.scale = Vector3.ONE * pulse
