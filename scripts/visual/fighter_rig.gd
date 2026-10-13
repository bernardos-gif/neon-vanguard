class_name FighterRig
extends Node3D
## Procedurally built, fully original stylised 3D fighter made from primitive
## meshes with PBR materials. Each style (kairo / vesper) has its own
## proportions, clothing, hair and accessories. The rig is posed every frame
## by FighterView using PoseLibrary poses.
##
## NOTE: these are original *placeholder* models. They are designed to read
## clearly in a side-on fighting camera, not to represent final-quality
## sculpted characters.

const THIGH := 0.46
const SHIN := 0.44
const FOOT_H := 0.07
const UPPER_ARM := 0.29
const FOREARM := 0.27

var joints := {}
var body_meshes: Array[MeshInstance3D] = []
var chains: Array[SpringChain] = []
var flash_material: StandardMaterial3D
var style: StringName = &"kairo"

var _primary: Color
var _secondary: Color
var _accent: Color
var _skin: Color
var _hair: Color
var _mats := {}


func build(data: FighterData, alt_palette := false) -> void:
	style = data.rig_style
	scale = Vector3.ONE * data.body_scale
	_primary = data.alt_primary_color if alt_palette else data.primary_color
	_secondary = data.alt_secondary_color if alt_palette else data.secondary_color
	_accent = data.alt_accent_color if alt_palette else data.accent_color
	_skin = data.skin_color
	_hair = data.hair_color
	_make_materials()
	var lean := style == &"vesper"
	_build_skeleton(lean)
	if style == &"vesper":
		_dress_vesper()
	else:
		_dress_kairo()
	flash_material = StandardMaterial3D.new()
	flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	flash_material.albedo_color = Color(1, 1, 1, 0)


# --------------------------------------------------------------------------
# Materials
# --------------------------------------------------------------------------

func _make_materials() -> void:
	_mats["primary"] = _fabric(_primary, 0.75)
	_mats["secondary"] = _fabric(_secondary, 0.85)
	_mats["white"] = _fabric(Color(0.88, 0.89, 0.92), 0.7)
	_mats["leather"] = _leather(_secondary.lightened(0.05))
	_mats["primary_leather"] = _leather(_primary)
	_mats["accent_glow"] = _glow(_accent, 3.0)
	_mats["skin"] = _skin_mat(_skin)
	_mats["hair"] = _fabric(_hair, 0.55)
	_mats["hair"].rim_enabled = true
	_mats["hair"].rim = 0.6
	_mats["eye"] = _leather(Color(0.05, 0.05, 0.06))
	_mats["metal"] = _metal(Color(0.7, 0.72, 0.76))


func _fabric(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.rim_enabled = true
	m.rim = 0.35
	m.rim_tint = 0.4
	return m


func _leather(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.38
	m.clearcoat_enabled = true
	m.clearcoat = 0.4
	m.clearcoat_roughness = 0.3
	m.rim_enabled = true
	m.rim = 0.25
	return m


func _metal(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = 0.9
	m.roughness = 0.25
	return m


func _glow(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.roughness = 0.3
	return m


func _skin_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.55
	m.subsurf_scatter_enabled = true
	m.subsurf_scatter_strength = 0.35
	m.rim_enabled = true
	m.rim = 0.3
	m.rim_tint = 0.6
	return m


# --------------------------------------------------------------------------
# Mesh helpers
# --------------------------------------------------------------------------

func _joint(name: String, parent: Node3D, pos: Vector3) -> Node3D:
	var j := Node3D.new()
	j.name = name
	j.position = pos
	parent.add_child(j)
	joints[name] = j
	return j


func _mesh(parent: Node3D, mesh: Mesh, mat_key: String, pos := Vector3.ZERO, rot_deg := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mats[mat_key]
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	parent.add_child(mi)
	body_meshes.append(mi)
	return mi


func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 24
	s.rings = 12
	return s


func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0)
	c.radial_segments = 20
	c.rings = 6
	return c


func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 18
	c.rings = 1
	return c


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _torus(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 24
	t.ring_segments = 10
	return t


## Tapered limb hanging down (-Y) from a joint.
func _limb(parent: Node3D, length: float, r_top: float, r_bottom: float, mat_key: String) -> void:
	_mesh(parent, _cyl(r_top, r_bottom, length), mat_key, Vector3(0, -length * 0.5, 0))
	_mesh(parent, _sphere(r_top * 1.02), mat_key)


# --------------------------------------------------------------------------
# Skeleton (shared) — clothing added per style
# --------------------------------------------------------------------------

func _build_skeleton(lean: bool) -> void:
	var k := 0.88 if lean else 1.0          # girth factor
	var hips := _joint("hips", self, Vector3(0, 0.98, 0))
	var spine := _joint("spine", hips, Vector3(0, 0.04, 0))
	var chest := _joint("chest", spine, Vector3(0, 0.24, 0))
	var neck := _joint("neck", chest, Vector3(0, 0.25, 0))
	_joint("head", neck, Vector3(0, 0.13, 0))
	var sw := 0.19 * k + 0.01
	for side in ["n", "f"]:
		var z := sw if side == "n" else -sw
		var sh := _joint("sh_" + side, chest, Vector3(0, 0.2, z))
		var el := _joint("el_" + side, sh, Vector3(0, -UPPER_ARM, 0))
		_joint("hand_" + side, el, Vector3(0, -FOREARM, 0))
		var hz := 0.1 * k if side == "n" else -0.1 * k
		var hp := _joint("hip_" + side, hips, Vector3(0, -0.04, hz))
		var kn := _joint("knee_" + side, hp, Vector3(0, -THIGH, 0))
		_joint("ankle_" + side, kn, Vector3(0, -SHIN, 0))
	# Body masses (skin / base layer)
	_mesh(hips, _sphere(0.15), "secondary", Vector3(0, 0, 0), Vector3.ZERO, Vector3(1.0 * k, 0.75, 0.85 * k))
	_mesh(spine, _capsule(0.135 * k, 0.32), "secondary", Vector3(0, 0.1, 0), Vector3.ZERO, Vector3(1, 1, 0.8))
	_mesh(neck, _cyl(0.05, 0.058, 0.12), "skin", Vector3(0, 0.03, 0))
	var head: Node3D = joints["head"]
	_mesh(head, _sphere(0.112), "skin", Vector3(0.01, 0.0, 0), Vector3.ZERO, Vector3(0.92, 1.05, 0.88))
	_mesh(head, _sphere(0.045), "skin", Vector3(0.07, -0.06, 0), Vector3.ZERO, Vector3(0.9, 0.8, 1.3))   # jaw / chin
	_mesh(head, _sphere(0.018), "skin", Vector3(0.105, -0.005, 0))                                        # nose
	for ez in [0.04, -0.04]:
		_mesh(head, _sphere(0.013), "eye", Vector3(0.093, 0.02, ez))
		_mesh(head, _box(Vector3(0.035, 0.008, 0.03)), "hair", Vector3(0.095, 0.045, ez), Vector3(0, 0, -8))  # brows
	for ez2 in [0.098, -0.098]:
		_mesh(head, _sphere(0.022), "skin", Vector3(-0.005, 0.0, ez2), Vector3.ZERO, Vector3(0.6, 1.0, 0.4))  # ears


func _arms(upper_mat: String, fore_mat: String, glove_mat: String, k: float) -> void:
	for side in ["n", "f"]:
		_limb(joints["sh_" + side], UPPER_ARM, 0.062 * k, 0.052 * k, upper_mat)
		_limb(joints["el_" + side], FOREARM, 0.05 * k, 0.042 * k, fore_mat)
		var hand: Node3D = joints["hand_" + side]
		_mesh(hand, _sphere(0.055 * k), glove_mat, Vector3(0.0, -0.035, 0), Vector3.ZERO, Vector3(1.0, 1.15, 0.85))


func _legs(thigh_mat: String, shin_mat: String, shoe_mat: String, k: float) -> void:
	for side in ["n", "f"]:
		_limb(joints["hip_" + side], THIGH, 0.085 * k, 0.065 * k, thigh_mat)
		_limb(joints["knee_" + side], SHIN, 0.062 * k, 0.045 * k, shin_mat)
		var ankle: Node3D = joints["ankle_" + side]
		_mesh(ankle, _box(Vector3(0.24, FOOT_H, 0.1 * k)), shoe_mat, Vector3(0.05, -FOOT_H * 0.5 + 0.01, 0))


# --------------------------------------------------------------------------
# KAIRO — cobalt technical jacket, white wraps, cyan accents, headband
# --------------------------------------------------------------------------

func _dress_kairo() -> void:
	var chest: Node3D = joints["chest"]
	var hips: Node3D = joints["hips"]
	var head: Node3D = joints["head"]
	# Jacket torso, collar, zip line and hem
	_mesh(chest, _capsule(0.175, 0.5), "primary", Vector3(0, 0.06, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.78))
	_mesh(chest, _sphere(0.1), "primary", Vector3(0, 0.2, 0.12), Vector3.ZERO, Vector3(1.2, 0.8, 1.0))
	_mesh(chest, _sphere(0.1), "primary", Vector3(0, 0.2, -0.12), Vector3.ZERO, Vector3(1.2, 0.8, 1.0))
	_mesh(chest, _torus(0.06, 0.1), "white", Vector3(0, 0.26, 0), Vector3(0, 0, 0), Vector3(1.0, 1.4, 1.0))
	_mesh(chest, _box(Vector3(0.012, 0.42, 0.012)), "accent_glow", Vector3(0.165, 0.04, 0.0))
	_mesh(chest, _box(Vector3(0.04, 0.012, 0.3)), "accent_glow", Vector3(0.0, 0.16, 0.0), Vector3(0, 0, 0), Vector3(4.6, 1, 0.9))
	_mesh(hips, _cyl(0.165, 0.2, 0.2), "primary", Vector3(0, 0.02, 0), Vector3.ZERO, Vector3(1, 1, 0.82))
	_mesh(hips, _torus(0.15, 0.175), "leather", Vector3(0, 0.1, 0), Vector3.ZERO, Vector3(1, 1.2, 0.8))  # belt
	_arms("primary", "white", "white", 1.0)
	for side in ["n", "f"]:
		_mesh(joints["el_" + side], _torus(0.045, 0.068), "white", Vector3(0, 0.0, 0))
		_mesh(joints["hand_" + side], _box(Vector3(0.03, 0.02, 0.09)), "accent_glow", Vector3(0.045, -0.06, 0))
	_legs("secondary", "secondary", "white", 1.0)
	for side in ["n", "f"]:
		var zs := 1.0 if side == "n" else -1.0
		_mesh(joints["hip_" + side], _box(Vector3(0.012, THIGH * 0.9, 0.012)), "accent_glow", Vector3(0, -THIGH * 0.5, zs * 0.078))
		_mesh(joints["knee_" + side], _box(Vector3(0.012, SHIN * 0.8, 0.012)), "accent_glow", Vector3(0, -SHIN * 0.5, zs * 0.058))
		_mesh(joints["ankle_" + side], _box(Vector3(0.25, 0.018, 0.105)), "accent_glow", Vector3(0.05, -FOOT_H + 0.012, 0))
	# Short swept-back hair with spikes
	_mesh(head, _sphere(0.118), "hair", Vector3(-0.012, 0.035, 0), Vector3.ZERO, Vector3(0.95, 0.85, 0.92))
	for i in 5:
		var a := -30.0 + i * 18.0
		_mesh(head, _cyl(0.0, 0.035, 0.12), "hair", Vector3(-0.04 - i * 0.012, 0.1 - i * 0.01, (i - 2) * 0.03), Vector3(0, 0, 70.0 + a * 0.3))
	# Headband with trailing ribbon (secondary motion)
	_mesh(head, _torus(0.112, 0.124), "accent_glow", Vector3(0.0, 0.045, 0), Vector3(0, 0, -6), Vector3(0.95, 0.5, 0.92))
	var knot := _joint("ribbon_anchor", head, Vector3(-0.115, 0.045, 0))
	chains.append(SpringChain.new(self, knot, 5, 0.07, [0.022, 0.02, 0.018, 0.015, 0.012], _mats["accent_glow"], Vector3(-1, -0.4, 0), 0.08))


# --------------------------------------------------------------------------
# VESPER — asymmetric streetwear, magenta sleeve, visor, long ponytail
# --------------------------------------------------------------------------

func _dress_vesper() -> void:
	var k := 0.88
	var chest: Node3D = joints["chest"]
	var hips: Node3D = joints["hips"]
	var head: Node3D = joints["head"]
	# Black bodysuit torso + cropped jacket with magenta trim
	_mesh(chest, _capsule(0.15, 0.46), "secondary", Vector3(0, 0.04, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.76))
	_mesh(chest, _capsule(0.162, 0.3), "leather", Vector3(0, 0.12, 0), Vector3.ZERO, Vector3(1.02, 1.0, 0.8))
	_mesh(chest, _torus(0.14, 0.158), "accent_glow", Vector3(0, 0.0, 0), Vector3.ZERO, Vector3(1.0, 0.6, 0.78))
	_mesh(chest, _box(Vector3(0.012, 0.3, 0.012)), "accent_glow", Vector3(0.15, 0.1, 0.05), Vector3(0, 0, 12))
	# Asymmetric shoulder pad on the near side
	_mesh(chest, _sphere(0.085), "primary_leather", Vector3(0, 0.22, 0.17), Vector3.ZERO, Vector3(1.2, 0.7, 1.0))
	_mesh(hips, _torus(0.12, 0.15), "accent_glow", Vector3(0, 0.08, 0), Vector3(0, 0, -6), Vector3(1, 1.1, 0.85))
	for i in 4:
		_mesh(hips, _box(Vector3(0.03, 0.03, 0.03)), "metal", Vector3(0.1 - i * 0.05, -0.02 - i * 0.012, 0.13))
	# Near arm: magenta sleeve. Far arm: bare skin with black glove.
	_limb(joints["sh_n"], UPPER_ARM, 0.06 * k, 0.05 * k, "primary")
	_limb(joints["el_n"], FOREARM, 0.05 * k, 0.04 * k, "primary")
	_limb(joints["sh_f"], UPPER_ARM, 0.055 * k, 0.046 * k, "skin")
	_limb(joints["el_f"], FOREARM, 0.046 * k, 0.04 * k, "secondary")
	for side in ["n", "f"]:
		_mesh(joints["hand_" + side], _sphere(0.05), "leather", Vector3(0, -0.035, 0), Vector3.ZERO, Vector3(1.0, 1.15, 0.85))
	_mesh(joints["el_f"], _torus(0.04, 0.056), "accent_glow", Vector3(0, -0.12, 0))
	# Legs: black leggings, magenta high boots with knee guards
	for side in ["n", "f"]:
		_limb(joints["hip_" + side], THIGH, 0.08 * k, 0.062 * k, "secondary")
		_limb(joints["knee_" + side], SHIN, 0.066 * k, 0.052 * k, "primary_leather")
		_mesh(joints["knee_" + side], _sphere(0.06), "primary_leather", Vector3(0.03, 0, 0), Vector3.ZERO, Vector3(1.0, 1.1, 0.9))
		var ankle: Node3D = joints["ankle_" + side]
		_mesh(ankle, _box(Vector3(0.23, FOOT_H, 0.09)), "primary_leather", Vector3(0.05, -FOOT_H * 0.5 + 0.01, 0))
		_mesh(ankle, _box(Vector3(0.24, 0.02, 0.095)), "accent_glow", Vector3(0.05, -FOOT_H + 0.012, 0))
	# Hair: violet cap, side-swept bangs, glowing visor, ponytail
	_mesh(head, _sphere(0.12), "hair", Vector3(-0.015, 0.03, 0), Vector3.ZERO, Vector3(0.98, 0.9, 0.95))
	_mesh(head, _box(Vector3(0.05, 0.1, 0.16)), "hair", Vector3(0.08, 0.06, 0.03), Vector3(10, 0, -25))
	_mesh(head, _box(Vector3(0.05, 0.04, 0.2)), "accent_glow", Vector3(0.085, 0.022, 0), Vector3(0, 0, -5))
	_mesh(head, _sphere(0.035), "metal", Vector3(-0.09, 0.1, 0))
	var tie := _joint("ponytail_anchor", head, Vector3(-0.1, 0.1, 0))
	chains.append(SpringChain.new(self, tie, 7, 0.075, [0.045, 0.048, 0.046, 0.042, 0.036, 0.03, 0.022], _mats["hair"], Vector3(-0.8, -0.6, 0), 0.06))


# --------------------------------------------------------------------------
# Posing
# --------------------------------------------------------------------------

static func leg_extent(body: float, hip: float, knee: float) -> float:
	var a1 := deg_to_rad(body + hip)
	var a2 := deg_to_rad(body + hip + knee)
	return THIGH * cos(a1) + SHIN * cos(a2)


## Height of the hip joint above the lowest foot for a pose.
static func root_height(p: Dictionary) -> float:
	var body: float = p["body"]
	var ext := maxf(leg_extent(body, p["hip_n"], p["knee_n"]), leg_extent(body, p["hip_f"], p["knee_f"]))
	return maxf(ext + FOOT_H + 0.04 * cos(deg_to_rad(body)), 0.16)


func apply_pose(p: Dictionary) -> void:
	var hips: Node3D = joints["hips"]
	hips.position = Vector3(p["shift"], root_height(p) + p["lift"], 0.0)
	hips.rotation = Vector3(0, 0, deg_to_rad(p["body"]))
	joints["spine"].rotation = Vector3(0, 0, deg_to_rad(p["spine"]))
	joints["chest"].rotation = Vector3(0, 0, deg_to_rad(p["chest"]))
	joints["neck"].rotation = Vector3(0, 0, deg_to_rad(p["neck"]))
	for side in ["n", "f"]:
		joints["sh_" + side].rotation = Vector3(0, 0, deg_to_rad(p["sh_" + side]))
		joints["el_" + side].rotation = Vector3(0, 0, deg_to_rad(p["el_" + side]))
		joints["hip_" + side].rotation = Vector3(0, 0, deg_to_rad(p["hip_" + side]))
		joints["knee_" + side].rotation = Vector3(0, 0, deg_to_rad(p["knee_" + side]))
		# Keep the foot roughly parallel to the floor.
		var foot: float = -(p["body"] + p["hip_" + side] + p["knee_" + side])
		joints["ankle_" + side].rotation = Vector3(0, 0, deg_to_rad(clampf(foot, -40.0, 40.0)))


func update_secondary(delta: float) -> void:
	for c in chains:
		c.update(delta)


func set_flash(amount: float, color: Color) -> void:
	if amount <= 0.01:
		for m in body_meshes:
			m.material_overlay = null
		return
	flash_material.albedo_color = Color(color.r, color.g, color.b, amount)
	for m in body_meshes:
		m.material_overlay = flash_material


func reset_secondary() -> void:
	for c in chains:
		c.reset()


func set_visible_chains(v: bool) -> void:
	for c in chains:
		c.set_visible(v)


# --------------------------------------------------------------------------
# Verlet chain for hair / ribbons (secondary motion)
# --------------------------------------------------------------------------

class SpringChain:
	var owner: Node3D
	var anchor: Node3D
	var seg_len: float
	var points: PackedVector3Array = PackedVector3Array()
	var prev: PackedVector3Array = PackedVector3Array()
	var meshes: Array[MeshInstance3D] = []
	var rest_dir: Vector3
	var stiffness: float
	var _initialised := false

	func _init(p_owner: Node3D, p_anchor: Node3D, count: int, length: float, radii: Array, mat: Material, p_rest_dir: Vector3, p_stiffness: float) -> void:
		owner = p_owner
		anchor = p_anchor
		seg_len = length
		rest_dir = p_rest_dir.normalized()
		stiffness = p_stiffness
		points.resize(count + 1)
		prev.resize(count + 1)
		for i in count:
			var mi := MeshInstance3D.new()
			var cap := CapsuleMesh.new()
			var r: float = radii[mini(i, radii.size() - 1)]
			cap.radius = r
			cap.height = maxf(length * 1.5, r * 2.0)
			cap.radial_segments = 12
			cap.rings = 4
			mi.mesh = cap
			mi.material_override = mat
			mi.top_level = true
			owner.add_child(mi)
			meshes.append(mi)

	func reset() -> void:
		_initialised = false

	func set_visible(v: bool) -> void:
		for m in meshes:
			m.visible = v

	func update(delta: float) -> void:
		if not anchor.is_inside_tree():
			return
		var base := anchor.global_position
		var basis := anchor.global_basis.orthonormalized()
		var rest := (basis * rest_dir).normalized()
		if not _initialised or points[0].distance_to(base) > 1.0:
			for i in points.size():
				points[i] = base + rest * seg_len * i
				prev[i] = points[i]
			_initialised = true
		var dt := clampf(delta, 0.0, 1.0 / 30.0)
		var gravity := Vector3(0, -9.8, 0) * dt * dt
		points[0] = base
		prev[0] = base
		for i in range(1, points.size()):
			var p := points[i]
			var v := (p - prev[i]) * 0.9
			prev[i] = p
			points[i] = p + v + gravity
		for _iter in 3:
			for i in range(1, points.size()):
				var target := points[i - 1] + rest * seg_len
				points[i] = points[i].lerp(target, stiffness)
				var d := points[i] - points[i - 1]
				var l := d.length()
				if l > 0.0001:
					points[i] = points[i - 1] + d / l * seg_len
		for i in meshes.size():
			var a := points[i]
			var b := points[i + 1]
			var y := (b - a)
			if y.length() < 0.0001:
				y = Vector3.DOWN
			y = y.normalized()
			var ref := Vector3.BACK if absf(y.dot(Vector3.BACK)) < 0.95 else Vector3.RIGHT
			var x := y.cross(ref).normalized()
			var z := x.cross(y).normalized()
			meshes[i].global_transform = Transform3D(Basis(x, y, z), (a + b) * 0.5)
