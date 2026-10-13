class_name CombatWorld
extends RefCounted
## Owns both fighters and every interaction between them: movement collision,
## stage bounds, hit/hurtbox resolution, blocking, throws, projectiles,
## counters and hitstop. step() advances exactly one 60 Hz combat frame and
## returns the gameplay events that happened during it (used for audio, VFX,
## HUD and tests). It never touches nodes, so it runs identically in a match,
## in training and in headless automated tests.

const DT := FighterSim.DT
const STAGE_HALF_WIDTH := 7.0
const MAX_SEPARATION := 7.2
const START_DISTANCE := 3.2
const HITSTOP := [6, 8, 11, 11]     # by AttackData.Strength
const BLOCKSTOP := [5, 6, 8, 8]
const KO_HITSTOP := 24
const COUNTER_HIT_BONUS := 1.2
const COUNTER_HIT_STUN := 8
const MIN_DAMAGE_SCALE := 0.35

var fighters: Array = []        # [FighterSim, FighterSim]
var projectiles: Array = []     # [ProjectileSim]
var hitstop := 0
var frame := 0
var round_over := false
var events: Array = []


func _init(data_a: FighterData, data_b: FighterData) -> void:
	fighters = [FighterSim.new(data_a, 0), FighterSim.new(data_b, 1)]
	for f in fighters:
		f.world = self
	reset_round()


func reset_round() -> void:
	fighters[0].reset_for_round(-START_DISTANCE * 0.5, 1)
	fighters[1].reset_for_round(START_DISTANCE * 0.5, -1)
	projectiles.clear()
	hitstop = 0
	round_over = false


func set_locked(value: bool) -> void:
	for f in fighters:
		f.locked = value
		if value:
			f.clear_input()


func emit_event(e: Dictionary) -> void:
	e["frame"] = frame
	events.append(e)


## Advances the simulation by one frame and returns this frame's events.
func step(input_a: InputState, input_b: InputState) -> Array:
	events = []
	frame += 1
	var a: FighterSim = fighters[0]
	var b: FighterSim = fighters[1]
	a.feed_input(input_a)
	b.feed_input(input_b)
	if hitstop > 0:
		hitstop -= 1
		return events
	a.age_buffer()
	b.age_buffer()
	a.update(b)
	b.update(a)
	_separate_fighters()
	_update_projectiles()
	if not round_over:
		_resolve_strikes()
		_resolve_projectile_hits()
	return events


# --------------------------------------------------------------------------
# Movement collision and bounds
# --------------------------------------------------------------------------

func _separate_fighters() -> void:
	var a: FighterSim = fighters[0]
	var b: FighterSim = fighters[1]
	var thrown := a.state == FighterSim.State.THROWN or b.state == FighterSim.State.THROWN
	if not thrown and absf(a.pos.y - b.pos.y) < 1.1:
		var min_dist := a.half_width() + b.half_width()
		var d := b.pos.x - a.pos.x
		if absf(d) < min_dist:
			var s := signf(d)
			if s == 0.0:
				s = float(a.facing)
			var overlap := min_dist - absf(d)
			a.pos.x -= s * overlap * 0.5
			b.pos.x += s * overlap * 0.5
	for f in fighters:
		var lim: float = STAGE_HALF_WIDTH - f.half_width()
		f.pos.x = clampf(f.pos.x, -lim, lim)
	# Re-separate if one fighter was pinned against a wall.
	if not thrown and absf(a.pos.y - b.pos.y) < 1.1:
		var min_dist2 := a.half_width() + b.half_width()
		var d2 := b.pos.x - a.pos.x
		if absf(d2) < min_dist2:
			var s2 := signf(d2) if d2 != 0.0 else float(a.facing)
			var lim_a: float = STAGE_HALF_WIDTH - a.half_width()
			if absf(a.pos.x) >= lim_a - 0.001:
				b.pos.x = a.pos.x + s2 * min_dist2
			else:
				a.pos.x = b.pos.x - s2 * min_dist2
	# Camera limit: fighters cannot walk further apart than MAX_SEPARATION.
	var sep := b.pos.x - a.pos.x
	if absf(sep) > MAX_SEPARATION:
		var dir := signf(sep)
		var excess := absf(sep) - MAX_SEPARATION
		var a_out := a.vel.x * -dir > 0.0
		var b_out := b.vel.x * dir > 0.0
		if b_out and not a_out:
			b.pos.x -= dir * excess
		elif a_out and not b_out:
			a.pos.x += dir * excess
		else:
			a.pos.x += dir * excess * 0.5
			b.pos.x -= dir * excess * 0.5
	for f in fighters:
		var lim2: float = STAGE_HALF_WIDTH - f.half_width()
		f.pos.x = clampf(f.pos.x, -lim2, lim2)


func _at_wall(f: FighterSim) -> bool:
	return absf(f.pos.x) >= STAGE_HALF_WIDTH - f.half_width() - 0.05


# --------------------------------------------------------------------------
# Strikes
# --------------------------------------------------------------------------

func _resolve_strikes() -> void:
	var a: FighterSim = fighters[0]
	var b: FighterSim = fighters[1]
	var a_hits := _strike_connects(a, b)
	var b_hits := _strike_connects(b, a)
	if not a_hits and not b_hits:
		return
	# Capture counter-hit status before any state changes so trades are fair.
	var a_counter := _is_counter_hit(b)
	var b_counter := _is_counter_hit(a)
	var a_atk: AttackData = a.attack
	var b_atk: AttackData = b.attack
	if a_hits:
		if not _try_counter_stance(a, b, a_atk):
			_apply_strike(a, b, a_atk, a.pos.x, a_counter, false)
	if b_hits:
		if not _try_counter_stance(b, a, b_atk):
			_apply_strike(b, a, b_atk, b.pos.x, b_counter, false)


func _strike_connects(att: FighterSim, def: FighterSim) -> bool:
	if not att.can_strike_now():
		return false
	if def.is_invulnerable():
		return false
	return att.hitbox_for(att.attack).intersects(def.hurtbox())


func _is_counter_hit(def: FighterSim) -> bool:
	return def.is_attacking() and def.attack_phase() != "recovery" and def.attack.kind == AttackData.Kind.STRIKE


func _is_punish(def: FighterSim) -> bool:
	return def.is_attacking() and def.attack_phase() == "recovery"


## Counter stance: if the defender is in the active window of a COUNTER move,
## the strike is absorbed and the defender performs its counter attack.
func _try_counter_stance(att: FighterSim, def: FighterSim, atk: AttackData) -> bool:
	if not (def.is_attacking() and def.attack.kind == AttackData.Kind.COUNTER):
		return false
	if not def.attack.is_active_frame(def.state_frame):
		return false
	att.hits_landed = atk.hits
	att.attack_connected = true
	att.enter_hitstun(24, 0.0)
	var follow: StringName = def.attack.counter_attack
	def.start_attack(follow)
	def.facing = 1 if att.pos.x > def.pos.x else -1
	hitstop = maxi(hitstop, 14)
	emit_event({"type": "counter", "fighter": def.index, "pos": _mid_point(att, def)})
	return true


func _apply_strike(att: FighterSim, def: FighterSim, atk: AttackData, source_x: float, counter: bool, from_projectile: bool) -> void:
	if not from_projectile:
		att.hits_landed += 1
		att.last_hit_frame = att.state_frame
		att.attack_connected = true
	var dir := 1.0 if def.pos.x >= source_x else -1.0
	if is_equal_approx(def.pos.x, source_x):
		dir = float(att.facing)
	var contact := _contact_point(att, def, atk, from_projectile)

	if def.can_block(atk.hit_level, source_x):
		var chip := mini(atk.chip_damage, maxi(def.health - 1, 0))
		def.health -= chip
		def.enter_blockstun(atk.blockstun, dir * atk.block_pushback, def.input.y < 0)
		if not from_projectile and _at_wall(def) and not att.airborne:
			att.vel.x = -dir * atk.block_pushback * 0.8
		def.stat_blocks += 1
		hitstop = maxi(hitstop, BLOCKSTOP[atk.strength])
		emit_event({"type": "block", "attacker": att.index, "defender": def.index, "strength": atk.strength, "pos": contact, "chip": chip})
		return

	var punish := _is_punish(def)
	var in_combo := def.state == FighterSim.State.HITSTUN
	if not in_combo:
		def.end_combo()
	if not from_projectile:
		att.attack_hit = true
	var scale := maxf(MIN_DAMAGE_SCALE, 1.0 - 0.1 * maxf(0.0, def.combo_hits - 1))
	var dmg := int(round(atk.damage * scale * (COUNTER_HIT_BONUS if counter else 1.0)))
	dmg = clampi(dmg, 1, def.health)
	def.health -= dmg
	def.combo_hits += 1
	def.combo_damage += dmg
	att.stat_damage_dealt += dmg
	att.stat_hits += 1
	att.stat_max_combo = maxi(att.stat_max_combo, def.combo_hits)

	var stun := atk.hitstun + (COUNTER_HIT_STUN if counter else 0) - maxi(0, def.combo_hits - 5)
	stun = maxi(stun, 8)
	var was_airborne := def.airborne
	if def.health <= 0:
		def.enter_ko(Vector2(dir * 3.2, 6.5))
		hitstop = maxi(hitstop, KO_HITSTOP)
		round_over = true
	elif atk.knockdown or was_airborne:
		if was_airborne:
			def.juggle_count += 1
		var lv := Vector2(dir * atk.launch.x, atk.launch.y) if atk.knockdown else Vector2(dir * 1.6, 4.2)
		def.launch(lv)
		hitstop = maxi(hitstop, HITSTOP[atk.strength] + (3 if counter else 0))
	else:
		def.enter_hitstun(stun, dir * atk.hit_pushback)
		if not from_projectile and _at_wall(def) and not att.airborne:
			att.vel.x = -dir * atk.hit_pushback * 0.8
		hitstop = maxi(hitstop, HITSTOP[atk.strength] + (3 if counter else 0))
	emit_event({
		"type": "hit", "attacker": att.index, "defender": def.index, "damage": dmg,
		"strength": atk.strength, "counter": counter, "punish": punish and not counter,
		"combo": def.combo_hits, "combo_damage": def.combo_damage, "pos": contact,
		"sound": atk.hit_sound, "ko": def.health <= 0, "knockdown": atk.knockdown,
		"move": atk.id,
	})


func _contact_point(att: FighterSim, def: FighterSim, atk: AttackData, from_projectile: bool) -> Vector2:
	var hb: Rect2
	if from_projectile:
		hb = Rect2(def.pos.x - 0.3, def.pos.y + 1.0, 0.6, 0.5)
	else:
		hb = att.hitbox_for(atk)
	var hu := def.hurtbox()
	var inter := hb.intersection(hu)
	if inter.has_area():
		return inter.get_center()
	return (hb.get_center() + hu.get_center()) * 0.5


func _mid_point(a: FighterSim, b: FighterSim) -> Vector2:
	return Vector2((a.pos.x + b.pos.x) * 0.5, 1.2)


# --------------------------------------------------------------------------
# Throws
# --------------------------------------------------------------------------

## Called by the thrower on each active frame of its throw move.
func try_throw(att: FighterSim, def: FighterSim) -> bool:
	if round_over or not def.is_throwable():
		return false
	var gap := absf(def.pos.x - att.pos.x) - att.half_width() - def.half_width()
	if gap > att.attack.throw_range:
		return false
	# Both fighters throwing at once: automatic throw break.
	if def.is_attacking() and def.attack.kind == AttackData.Kind.THROW and def.attack_phase() != "recovery":
		_throw_break(att, def)
		return true
	att.facing = 1 if def.pos.x > att.pos.x else -1
	att.throw_partner = def
	att.attack_connected = true
	att._set_state(FighterSim.State.THROWING, true)
	def.attack = null
	def.crouching = false
	def.throw_partner = att
	def._set_state(FighterSim.State.THROWN, true)
	emit_event({"type": "throw_start", "attacker": att.index, "defender": def.index})
	return true


func resolve_throw_tech(att: FighterSim, def: FighterSim) -> void:
	_throw_break(att, def)


func _throw_break(a: FighterSim, b: FighterSim) -> void:
	var dir := 1.0 if b.pos.x >= a.pos.x else -1.0
	for f in [a, b]:
		f.throw_partner = null
		f.attack = null
		f.invuln = 6
	a.enter_blockstun(14, -dir * 4.0, false)
	b.enter_blockstun(14, dir * 4.0, false)
	emit_event({"type": "throw_tech", "pos": _mid_point(a, b)})


func resolve_throw_damage(att: FighterSim) -> void:
	var def: FighterSim = att.throw_partner
	if def == null or def.state != FighterSim.State.THROWN:
		return
	var atk: AttackData = att.data.get_move(&"throw")
	var dmg := atk.damage if atk else FighterSim.THROW_DAMAGE_DEFAULT
	dmg = clampi(dmg, 1, def.health)
	def.end_combo()
	def.health -= dmg
	def.combo_hits = 1
	def.combo_damage = dmg
	att.stat_damage_dealt += dmg
	att.stat_hits += 1
	att.stat_max_combo = maxi(att.stat_max_combo, 1)
	def.throw_partner = null
	var dir := float(att.facing)
	var lv := Vector2(dir * (atk.launch.x if atk else 3.0), atk.launch.y if atk else 6.0)
	if def.health <= 0:
		def.enter_ko(lv)
		hitstop = maxi(hitstop, KO_HITSTOP)
		round_over = true
	else:
		def.launch(lv)
		def.juggle_count = FighterSim.MAX_JUGGLE  # no juggles after a throw
		hitstop = maxi(hitstop, HITSTOP[AttackData.Strength.HEAVY])
	emit_event({
		"type": "hit", "attacker": att.index, "defender": def.index, "damage": dmg,
		"strength": AttackData.Strength.HEAVY, "counter": false, "punish": false,
		"combo": 1, "combo_damage": dmg, "pos": def.pos + Vector2(0, 1.0),
		"sound": &"hit_heavy", "ko": def.health <= 0, "knockdown": true, "move": &"throw", "throw": true,
	})


# --------------------------------------------------------------------------
# Projectiles
# --------------------------------------------------------------------------

func spawn_projectile(owner: FighterSim, atk: AttackData) -> void:
	var p := ProjectileSim.new()
	p.owner = owner
	p.attack = atk
	p.dir = owner.facing
	p.pos = Vector2(owner.pos.x + owner.facing * 0.7, atk.projectile_height)
	p.id = frame * 10 + owner.index
	projectiles.append(p)
	owner.projectile_out = true
	emit_event({"type": "projectile_spawn", "fighter": owner.index, "id": p.id, "pos": p.pos})


func _update_projectiles() -> void:
	for p in projectiles:
		p.step()
		if p.age > p.attack.projectile_lifetime or absf(p.pos.x) > STAGE_HALF_WIDTH + 2.0:
			_kill_projectile(p, false)
	# Opposing projectiles cancel each other.
	for i in projectiles.size():
		for j in range(i + 1, projectiles.size()):
			var p: ProjectileSim = projectiles[i]
			var q: ProjectileSim = projectiles[j]
			if p.alive and q.alive and p.owner != q.owner and p.rect().intersects(q.rect()):
				_kill_projectile(p, true)
				_kill_projectile(q, true)
	projectiles = projectiles.filter(func(p): return p.alive)


func _resolve_projectile_hits() -> void:
	for p in projectiles:
		if not p.alive:
			continue
		var target: FighterSim = fighters[1 - p.owner.index]
		if target.is_invulnerable():
			continue
		if not p.rect().intersects(target.hurtbox()):
			continue
		if target.is_attacking() and target.attack.kind == AttackData.Kind.COUNTER and target.attack.is_active_frame(target.state_frame):
			emit_event({"type": "counter", "fighter": target.index, "pos": p.pos})
			hitstop = maxi(hitstop, 6)
			_kill_projectile(p, true)
			continue
		var counter := _is_counter_hit(target)
		_apply_strike(p.owner, target, p.attack, p.pos.x, counter, true)
		_kill_projectile(p, true)
	projectiles = projectiles.filter(func(p): return p.alive)


func _kill_projectile(p: ProjectileSim, impact: bool) -> void:
	if not p.alive:
		return
	p.alive = false
	p.owner.projectile_out = false
	for q in projectiles:
		if q.alive and q.owner == p.owner:
			p.owner.projectile_out = true
	emit_event({"type": "projectile_end", "id": p.id, "impact": impact, "pos": p.pos})


# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------

func distance() -> float:
	return absf(fighters[1].pos.x - fighters[0].pos.x)


func snapshot() -> Dictionary:
	## Compact state used by the determinism test.
	var out := {"frame": frame, "hitstop": hitstop}
	for f in fighters:
		out["f%d" % f.index] = [f.pos, f.vel, f.health, f.state, f.state_frame, f.facing, f.combo_hits]
	return out
