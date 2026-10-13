extends SceneTree
## Regenerates the default fighter and CPU data files in res://data.
##
## Run from the project folder:
##   godot --headless --script res://tools/build_data.gd
##
## WARNING: this overwrites res://data/fighters/*.tres and res://data/ai/*.tres.
## After the first generation, tune values in the Godot Inspector instead.

const S := AttackData.Strength
const L := AttackData.HitLevel
const K := AttackData.Kind


func _initialize() -> void:
	var ok := true
	ok = _save(_kairo(), "res://data/fighters/kairo.tres") and ok
	ok = _save(_vesper(), "res://data/fighters/vesper.tres") and ok
	ok = _save(_ai("Easy", 26, 26, 0.15, 0.1, 0.06, 0.15, 0.45, 0.04, 0.15, 0.06, 18, 0.22), "res://data/ai/easy.tres") and ok
	ok = _save(_ai("Normal", 16, 16, 0.45, 0.4, 0.3, 0.5, 0.6, 0.1, 0.28, 0.1, 6, 0.08), "res://data/ai/normal.tres") and ok
	ok = _save(_ai("Hard", 10, 10, 0.78, 0.75, 0.6, 0.85, 0.7, 0.16, 0.38, 0.1, 0, 0.02), "res://data/ai/hard.tres") and ok
	print("build_data: ", "OK" if ok else "FAILED")
	quit(0 if ok else 1)


func _save(res: Resource, path: String) -> bool:
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("Could not save %s (error %d)" % [path, err])
		return false
	print("  wrote ", path)
	return true


func _ai(name: String, reaction: int, interval: int, block: float, punish: float, anti_air: float,
		combo: float, aggression: float, throw: float, special: float, jump: float,
		telegraph: int, mistake: float) -> AiProfile:
	var p := AiProfile.new()
	p.display_name = name
	p.reaction_frames = reaction
	p.decision_interval = interval
	p.block_chance = block
	p.punish_chance = punish
	p.anti_air_chance = anti_air
	p.combo_skill = combo
	p.aggression = aggression
	p.throw_chance = throw
	p.special_chance = special
	p.jump_chance = jump
	p.telegraph_frames = telegraph
	p.mistake_chance = mistake
	return p


func _move(id: String, name: String, strength: int, startup: int, active: int, recovery: int,
		damage: int, hitstun: int, blockstun: int, hitbox: Rect2, windup: String, strike: String) -> AttackData:
	var a := AttackData.new()
	a.id = StringName(id)
	a.display_name = name
	a.strength = strength
	a.startup = startup
	a.active = active
	a.recovery = recovery
	a.damage = damage
	a.hitstun = hitstun
	a.blockstun = blockstun
	a.hitbox = hitbox
	a.pose_windup = StringName(windup)
	a.pose_strike = StringName(strike)
	match strength:
		S.LIGHT:
			a.hit_sound = &"hit_light"; a.whiff_sound = &"whiff_light"
			a.hit_pushback = 2.2; a.block_pushback = 2.6
		S.MEDIUM:
			a.hit_sound = &"hit_medium"; a.whiff_sound = &"whiff_light"
			a.hit_pushback = 2.6; a.block_pushback = 3.0
		S.HEAVY:
			a.hit_sound = &"hit_heavy"; a.whiff_sound = &"whiff_heavy"
			a.hit_pushback = 3.4; a.block_pushback = 3.6
		S.SPECIAL:
			a.hit_sound = &"hit_special"; a.whiff_sound = &"whiff_heavy"
			a.hit_pushback = 3.0; a.block_pushback = 3.4
			a.cancel_into_normals = false
			a.cancel_into_specials = false
	return a


func _air(a: AttackData) -> AttackData:
	a.hit_level = L.OVERHEAD
	a.cancel_into_normals = false
	a.cancel_into_specials = false
	return a


func _sweep(a: AttackData, launch: Vector2) -> AttackData:
	a.hit_level = L.LOW
	a.knockdown = true
	a.launch = launch
	a.cancel_into_normals = false
	a.cancel_into_specials = false
	return a


func _throw(name: String, damage: int) -> AttackData:
	var t := _move("throw", name, S.HEAVY, 3, 2, 24, damage, 0, 0, Rect2(), "throw_w", "throw_reach")
	t.kind = K.THROW
	t.hit_level = L.UNBLOCKABLE
	t.launch = Vector2(3.0, 6.0)
	t.throw_range = 0.55
	t.cancel_into_normals = false
	t.cancel_into_specials = false
	t.hit_sound = &"throw"
	t.whiff_sound = &"whiff_light"
	return t


func _add(f: FighterData, moves: Array) -> void:
	var d := {}
	for m in moves:
		d[m.id] = m
	f.moves = d


func _kairo() -> FighterData:
	var f := FighterData.new()
	f.id = &"kairo"
	f.display_name = "KAIRO"
	f.title = "The Counter Specialist"
	f.bio = "A disciplined martial artist from the Cobalt Ward training halls. Kairo studies every opponent like a puzzle and strikes the instant they make a mistake."
	f.style_summary = "Balanced, precise and patient. Zone with Pulse Shot, punish with Comet Drive and read attacks with the Still Water counter."
	f.max_health = 1000
	f.walk_forward_speed = 2.6
	f.walk_back_speed = 2.0
	f.dash_forward_speed = 7.5
	f.dash_forward_frames = 16
	f.dash_back_speed = 6.5
	f.dash_back_frames = 18
	f.jump_velocity = 9.6
	f.pushbox_width = 0.6
	f.rig_style = &"kairo"
	f.body_scale = 1.0
	f.primary_color = Color(0.07, 0.2, 0.75)
	f.secondary_color = Color(0.06, 0.07, 0.12)
	f.accent_color = Color(0.15, 0.9, 1.0)
	f.skin_color = Color(0.72, 0.52, 0.4)
	f.hair_color = Color(0.04, 0.04, 0.05)
	f.alt_primary_color = Color(0.85, 0.85, 0.88)
	f.alt_secondary_color = Color(0.18, 0.12, 0.08)
	f.alt_accent_color = Color(1.0, 0.65, 0.15)
	f.ui_color = Color(0.2, 0.85, 1.0)

	var pulse := _move("sp_neutral", "Pulse Shot", S.SPECIAL, 13, 1, 26, 60, 20, 14, Rect2(), "pulse_w", "pulse")
	pulse.kind = K.PROJECTILE
	pulse.chip_damage = 8
	pulse.projectile_speed = 7.5
	pulse.hit_sound = &"proj_hit"
	pulse.whiff_sound = &"projectile"

	var comet := _move("sp_forward", "Comet Drive", S.SPECIAL, 14, 5, 22, 110, 24, 16, Rect2(0.15, 0.8, 0.9, 0.7), "comet_w", "comet")
	comet.knockdown = true
	comet.launch = Vector2(3.2, 5.5)
	comet.chip_damage = 10
	comet.move_velocity = Vector2(8.0, 0.0)
	comet.move_start = 6
	comet.move_end = 19

	var still := _move("sp_back", "Still Water", S.SPECIAL, 3, 20, 20, 0, 0, 0, Rect2(), "counter_w", "counter")
	still.kind = K.COUNTER
	still.counter_attack = &"still_water_strike"
	still.whiff_sound = &"counter_ready"

	var still_hit := _move("still_water_strike", "Still Water: Riposte", S.SPECIAL, 2, 4, 18, 120, 24, 16, Rect2(0.1, 0.7, 1.15, 0.9), "riposte_w", "riposte")
	still_hit.knockdown = true
	still_hit.launch = Vector2(4.0, 6.0)
	still_hit.move_velocity = Vector2(4.0, 0.0)
	still_hit.move_start = 0
	still_hit.move_end = 6

	_add(f, [
		_move("st_light", "Jab", S.LIGHT, 4, 2, 7, 30, 14, 10, Rect2(0.2, 1.05, 0.65, 0.3), "jab_w", "jab"),
		_move("st_medium", "Cobalt Straight", S.MEDIUM, 7, 3, 13, 55, 18, 13, Rect2(0.2, 1.0, 0.85, 0.35), "straight_w", "straight"),
		_move("st_heavy", "Turning Heel", S.HEAVY, 11, 4, 20, 90, 22, 16, Rect2(0.25, 1.15, 1.0, 0.5), "hikick_w", "hikick"),
		_move("cr_light", "Low Jab", S.LIGHT, 4, 2, 8, 25, 13, 9, Rect2(0.2, 0.55, 0.6, 0.3), "crjab_w", "crjab"),
		_sweep_low(_move("cr_medium", "Shin Cutter", S.MEDIUM, 7, 3, 14, 45, 17, 12, Rect2(0.25, 0.0, 0.85, 0.3), "lowkick_w", "lowkick")),
		_sweep(_move("cr_heavy", "Tide Sweep", S.HEAVY, 10, 4, 24, 80, 20, 14, Rect2(0.25, 0.0, 1.05, 0.3), "sweep_w", "sweep"), Vector2(1.2, 3.5)),
		_air(_move("j_light", "Drop Fist", S.LIGHT, 4, 6, 4, 35, 14, 9, Rect2(0.05, 0.0, 0.6, 0.55), "air_w", "jlight")),
		_air(_move("j_medium", "Cross Knee", S.MEDIUM, 6, 5, 5, 55, 17, 11, Rect2(0.1, -0.1, 0.7, 0.6), "air_w", "jmedium")),
		_air(_move("j_heavy", "Falling Star", S.HEAVY, 8, 5, 6, 80, 20, 13, Rect2(0.1, -0.25, 0.9, 0.7), "air_w", "jheavy")),
		pulse, comet, still, still_hit,
		_throw("Ridge Fall", 100),
	])
	return f


func _sweep_low(a: AttackData) -> AttackData:
	a.hit_level = L.LOW
	return a


func _vesper() -> FighterData:
	var f := FighterData.new()
	f.id = &"vesper"
	f.display_name = "VESPER"
	f.title = "The Agile Pressure Fighter"
	f.bio = "A street-circuit legend from the Magenta Line who never fights the same way twice. Vesper smothers opponents with speed, feints and relentless combinations."
	f.style_summary = "Fast and aggressive. Close the gap with Ghost Step, slip out with Mirage Flip and finish strings with the multi-hit Razor Flurry."
	f.max_health = 950
	f.walk_forward_speed = 3.2
	f.walk_back_speed = 2.4
	f.dash_forward_speed = 9.0
	f.dash_forward_frames = 14
	f.dash_back_speed = 7.5
	f.dash_back_frames = 16
	f.jump_velocity = 9.9
	f.jump_forward_speed = 3.4
	f.pushbox_width = 0.55
	f.rig_style = &"vesper"
	f.body_scale = 0.96
	f.primary_color = Color(0.95, 0.08, 0.6)
	f.secondary_color = Color(0.03, 0.03, 0.04)
	f.accent_color = Color(1.0, 0.25, 0.85)
	f.skin_color = Color(0.86, 0.68, 0.58)
	f.hair_color = Color(0.32, 0.1, 0.42)
	f.alt_primary_color = Color(0.2, 0.95, 0.5)
	f.alt_secondary_color = Color(0.9, 0.9, 0.92)
	f.alt_accent_color = Color(0.3, 1.0, 0.6)
	f.ui_color = Color(1.0, 0.3, 0.8)

	var flurry := _move("sp_neutral", "Razor Flurry", S.SPECIAL, 9, 16, 18, 22, 14, 8, Rect2(0.2, 0.95, 0.85, 0.45), "flurry_a", "flurry_b")
	flurry.hits = 4
	flurry.hit_interval = 4
	flurry.chip_damage = 4
	flurry.hit_pushback = 1.0
	flurry.block_pushback = 1.4
	flurry.move_velocity = Vector2(1.5, 0.0)
	flurry.move_start = 9
	flurry.move_end = 25
	flurry.hit_sound = &"hit_medium"

	var ghost := _move("sp_forward", "Ghost Step", S.SPECIAL, 8, 4, 18, 70, 20, 12, Rect2(0.15, 0.2, 0.85, 0.5), "ghost_w", "ghost")
	ghost.low_profile = true
	ghost.move_velocity = Vector2(9.0, 0.0)
	ghost.move_start = 2
	ghost.move_end = 14
	ghost.chip_damage = 6

	var flip := _move("sp_back", "Mirage Flip", S.SPECIAL, 1, 14, 12, 0, 0, 0, Rect2(), "flip_w", "flip")
	flip.kind = K.EVADE
	flip.invuln_start = 1
	flip.invuln_end = 16
	flip.move_velocity = Vector2(-5.0, 0.0)
	flip.move_start = 1
	flip.move_end = 15
	flip.whiff_sound = &"whiff_heavy"

	_add(f, [
		_move("st_light", "Snap Jab", S.LIGHT, 3, 2, 6, 25, 13, 9, Rect2(0.2, 1.05, 0.6, 0.3), "snap_w", "snap"),
		_move("st_medium", "Hook Kick", S.MEDIUM, 6, 3, 11, 48, 17, 12, Rect2(0.2, 0.95, 0.85, 0.4), "hook_w", "hook"),
		_move("st_heavy", "Spin Heel", S.HEAVY, 10, 3, 18, 80, 21, 15, Rect2(0.2, 1.1, 1.0, 0.5), "spin_w", "spin"),
		_sweep_low(_move("cr_light", "Shin Flick", S.LIGHT, 4, 2, 7, 22, 12, 8, Rect2(0.2, 0.0, 0.7, 0.3), "crflick_w", "crflick")),
		_move("cr_medium", "Slide Jab", S.MEDIUM, 6, 3, 12, 40, 16, 11, Rect2(0.2, 0.5, 0.8, 0.3), "crjab_w", "crjab"),
		_sweep(_move("cr_heavy", "Scissor Sweep", S.HEAVY, 9, 4, 22, 72, 20, 14, Rect2(0.25, 0.0, 1.0, 0.3), "sweep_w", "sweep"), Vector2(1.2, 3.5)),
		_air(_move("j_light", "Needle Knee", S.LIGHT, 3, 6, 4, 30, 14, 9, Rect2(0.05, 0.0, 0.6, 0.55), "air_w", "jmedium")),
		_air(_move("j_medium", "Arc Fist", S.MEDIUM, 5, 5, 5, 50, 17, 11, Rect2(0.1, -0.1, 0.7, 0.6), "air_w", "jlight")),
		_air(_move("j_heavy", "Stiletto Dive", S.HEAVY, 7, 5, 6, 72, 20, 13, Rect2(0.1, -0.25, 0.9, 0.7), "air_w", "jheavy")),
		flurry, ghost, flip,
		_throw("Cross Spin", 90),
	])
	return f
