class_name FighterView
extends Node3D
## Visual representation of a FighterSim. Reads simulation state only; it
## never changes gameplay. Positions are interpolated between 60 Hz combat
## frames so motion stays smooth on high-refresh displays.

const S := FighterSim.State

var sim: FighterSim
var data: FighterData
var rig: FighterRig
var showcase := false            # menus: idle animation without a simulation
var showcase_pose: StringName = &""

var _prev_pos := Vector2.ZERO
var _cur_pos := Vector2.ZERO
var _pose: Dictionary = {}
var _time := 0.0
var _walk_phase := 0.0
var _flash := 0.0
var _flash_color := Color.WHITE
var _yaw := 0.0
var _accent_light: OmniLight3D
var _opp_x := 0.0


func setup(p_data: FighterData, p_sim: FighterSim = null, alt_palette := false) -> void:
	data = p_data
	sim = p_sim
	rig = FighterRig.new()
	rig.name = "Rig"
	add_child(rig)
	rig.build(data, alt_palette)
	_pose = PoseLibrary.stance(data.rig_style)
	rig.apply_pose(_pose)
	_accent_light = OmniLight3D.new()
	_accent_light.light_color = data.alt_accent_color if alt_palette else data.accent_color
	_accent_light.light_energy = 0.6
	_accent_light.omni_range = 2.2
	_accent_light.position = Vector3(-0.2, 1.3, -0.7)
	_accent_light.shadow_enabled = false
	add_child(_accent_light)
	if sim:
		_cur_pos = sim.pos
		_prev_pos = sim.pos
		position = Vector3(sim.pos.x, sim.pos.y, 0)
		_yaw = 0.0 if sim.facing > 0 else PI
		rotation.y = _yaw
	rig.reset_secondary()


## Call once after every combat frame.
func sim_ticked(opp_x: float) -> void:
	if sim == null:
		return
	_prev_pos = _cur_pos
	_cur_pos = sim.pos
	_opp_x = opp_x


## Call after a round reset so the fighter does not slide across the stage.
func snap() -> void:
	if sim:
		_prev_pos = sim.pos
		_cur_pos = sim.pos
		_yaw = 0.0 if sim.facing > 0 else PI
		rotation.y = _yaw
	rig.reset_secondary()


func flash(color: Color, amount := 0.75) -> void:
	_flash = amount
	_flash_color = color


func _process(delta: float) -> void:
	_time += delta
	if sim:
		var t := Engine.get_physics_interpolation_fraction()
		var p := _prev_pos.lerp(_cur_pos, t)
		position = Vector3(p.x, p.y, 0.0)
		var target_yaw := 0.0 if sim.facing > 0 else PI
		_yaw = lerp_angle(_yaw, target_yaw, 1.0 - exp(-22.0 * delta))
		rotation.y = _yaw
	var target := _target_pose(delta)
	var rate := _blend_rate()
	var k := 1.0 - exp(-rate * delta)
	for key in PoseLibrary.KEYS:
		_pose[key] = lerpf(_pose.get(key, 0.0), target[key], k)
	rig.apply_pose(_pose)
	rig.update_secondary(delta)
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 5.0, 0.0)
		rig.set_flash(_flash, _flash_color)


func _blend_rate() -> float:
	if sim == null:
		return 10.0
	match sim.state:
		S.ATTACK, S.HITSTUN, S.BLOCKSTUN, S.THROWING, S.THROWN:
			return 40.0
		S.KNOCKDOWN, S.KO:
			return 14.0
		S.WAKEUP:
			return 9.0
	return 16.0


func _style() -> StringName:
	return data.rig_style


func _stance() -> Dictionary:
	var p := PoseLibrary.stance(_style())
	# Breathing and (for Vesper) a light boxer's bounce.
	var bounce := 0.025 if _style() == &"vesper" else 0.01
	var speed := 5.5 if _style() == &"vesper" else 2.2
	p["lift"] += sin(_time * speed) * bounce
	p["chest"] += sin(_time * 2.2) * 1.5
	p["sh_n"] += sin(_time * 2.2 + 0.5) * 2.0
	return p


func _target_pose(delta: float) -> Dictionary:
	if sim == null:
		if showcase_pose != &"":
			return PoseLibrary.get_pose(_style(), showcase_pose)
		return _stance()
	var f := sim.state_frame
	match sim.state:
		S.IDLE:
			if sim.is_guarding(_opp_x):
				return PoseLibrary.get_pose(_style(), &"block")
			return _stance()
		S.WALK:
			return _walk(delta)
		S.CROUCH:
			if sim.is_guarding(_opp_x):
				return PoseLibrary.get_pose(_style(), &"crouch_block")
			return PoseLibrary.get_pose(_style(), &"crouch")
		S.PREJUMP, S.LANDING:
			return PoseLibrary.get_pose(_style(), &"prejump")
		S.JUMP:
			return PoseLibrary.get_pose(_style(), &"jump")
		S.DASH:
			return PoseLibrary.get_pose(_style(), &"dash_f" if sim.dash_dir > 0 else &"dash_b")
		S.ATTACK:
			return _attack_pose()
		S.HITSTUN:
			if sim.airborne:
				return PoseLibrary.get_pose(_style(), &"air_hit")
			return PoseLibrary.get_pose(_style(), &"hit_low" if sim.combo_hits % 3 == 2 else &"hit_high")
		S.BLOCKSTUN:
			return PoseLibrary.get_pose(_style(), &"crouch_block" if sim.block_low else &"block")
		S.KNOCKDOWN:
			return PoseLibrary.get_pose(_style(), &"lying")
		S.WAKEUP:
			var t := clampf(float(f) / FighterSim.WAKEUP_FRAMES, 0.0, 1.0)
			return PoseLibrary.blend(PoseLibrary.get_pose(_style(), &"lying"), PoseLibrary.get_pose(_style(), &"crouch"), smoothstep(0.0, 1.0, t))
		S.THROWING:
			if f < 12:
				return PoseLibrary.get_pose(_style(), &"throw_reach")
			if f < FighterSim.THROW_HIT_FRAME:
				return PoseLibrary.get_pose(_style(), &"throw_lift")
			return PoseLibrary.get_pose(_style(), &"throw_toss")
		S.THROWN:
			return PoseLibrary.get_pose(_style(), &"thrown")
		S.KO:
			if sim.airborne:
				return PoseLibrary.get_pose(_style(), &"air_hit")
			return PoseLibrary.get_pose(_style(), &"lying")
		S.VICTORY:
			var v := PoseLibrary.get_pose(_style(), &"victory")
			v["lift"] += sin(_time * 3.0) * 0.01
			return v
	return _stance()


func _walk(delta: float) -> Dictionary:
	var p := _stance()
	var forward := sim.vel.x * sim.facing >= 0.0
	_walk_phase += delta * (9.0 if forward else 7.5) * (1.0 if forward else -1.0)
	var s := sin(_walk_phase)
	p["hip_n"] += s * 16.0
	p["hip_f"] -= s * 16.0
	p["knee_n"] -= maxf(0.0, -s) * 28.0
	p["knee_f"] -= maxf(0.0, s) * 28.0
	p["body"] += -3.0 if forward else 3.0
	p["lift"] += absf(cos(_walk_phase)) * 0.015
	return p


func _attack_pose() -> Dictionary:
	var a := sim.attack
	if a == null:
		return _stance()
	var f := sim.state_frame
	var style := _style()
	var base: Dictionary
	var sid := String(a.id)
	if sim.airborne:
		base = PoseLibrary.get_pose(style, &"jump")
	elif sid.begins_with("cr_"):
		base = PoseLibrary.get_pose(style, &"crouch")
	else:
		base = _stance()
	var wind := PoseLibrary.get_pose(style, a.pose_windup) if a.pose_windup != &"" else base
	var strike := PoseLibrary.get_pose(style, a.pose_strike) if a.pose_strike != &"" else base
	# Special-case visual sequences.
	if a.pose_strike == &"flip":
		var total := float(a.total_frames())
		var t := clampf(float(f) / total, 0.0, 1.0)
		var p := PoseLibrary.blend(wind, strike, smoothstep(0.0, 0.15, t))
		p["body"] = 360.0 * smoothstep(0.05, 0.85, t)
		p["lift"] = sin(PI * clampf(t / 0.85, 0.0, 1.0)) * 0.7
		if t > 0.85:
			p = PoseLibrary.blend(p, base, (t - 0.85) / 0.15)
		return p
	if a.hits > 1 and a.is_active_frame(f):
		var idx := (f - a.startup) / maxi(1, a.hit_interval)
		return strike if idx % 2 == 0 else wind
	if a.kind == AttackData.Kind.COUNTER and a.is_active_frame(f):
		return strike
	if f < a.startup:
		var s := float(f + 1) / float(a.startup)
		if s < 0.65:
			return PoseLibrary.blend(base, wind, smoothstep(0.0, 1.0, s / 0.65))
		return PoseLibrary.blend(wind, strike, smoothstep(0.0, 1.0, (s - 0.65) / 0.35))
	if a.is_active_frame(f):
		return strike
	var r := float(f - a.startup - a.active) / maxf(1.0, float(a.recovery))
	return PoseLibrary.blend(strike, base, smoothstep(0.0, 1.0, clampf(r * 1.2, 0.0, 1.0)))
