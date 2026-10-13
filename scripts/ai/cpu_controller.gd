class_name CpuController
extends RefCounted
## CPU opponent. Produces an InputState each frame, exactly like a human
## player, so it obeys every movement, attack and recovery rule.
##
## Fairness: the CPU perceives the opponent through a delay of
## profile.reaction_frames frames and makes each defensive decision once per
## threat (it does not re-roll every frame), so it cannot react instantly or
## read hidden inputs.

var profile: AiProfile
var me_index := 1
var rng := RandomNumberGenerator.new()

var _history: Array = []           # delayed snapshots of the opponent
var _plan: Array = []              # [{x (relative), y, b, frames}]
var _cooldown := 0
var _passive_frames := 0
var _handled_threat := -1
var _handled_proj := -1
var _combo_attack_id := -1
var _last_buttons := 0
var _attack_serial := 0
var _last_attack_ref: AttackData
var _last_attack_frame := -1


func _init(p_profile: AiProfile, p_index := 1, p_seed := 0) -> void:
	profile = p_profile
	me_index = p_index
	if p_seed != 0:
		rng.seed = p_seed
	else:
		rng.randomize()
	_cooldown = 20


func get_input(world: CombatWorld) -> InputState:
	var me: FighterSim = world.fighters[me_index]
	var opp: FighterSim = world.fighters[1 - me_index]
	_record(opp, world)
	if me.locked:
		_plan.clear()
		return _emit(me, 0, 0, 0)
	var seen: Dictionary = _perceived()

	# 1. Keep holding guard while in blockstun.
	if me.state == FighterSim.State.BLOCKSTUN:
		_plan.clear()
		return _emit(me, -1, -1 if me.block_low else 0, 0)

	# 2. Combo continuation after a confirmed hit.
	if me.is_attacking() and me.attack_hit and me.attack != _last_attack_ref:
		_last_attack_ref = me.attack
		if rng.randf() < profile.combo_skill:
			var next := _next_combo_button(me)
			if next != 0:
				_plan = [{"x": 1 if next == InputState.SPECIAL else 0, "y": 0, "b": next, "frames": 2}]

	# 3. Defensive reaction to a perceived threat (decided once per threat).
	if _plan.is_empty() or _plan[0].get("interruptible", false):
		var threat := _threat(seen, me)
		if threat != -1 and threat != _handled_threat:
			_handled_threat = threat
			if me.is_actionable() and rng.randf() < profile.block_chance:
				var low: bool = seen.get("low", false)
				_plan = [{"x": -1, "y": -1 if low else 0, "b": 0, "frames": 14 + rng.randi_range(0, 10)}]

	if not _plan.is_empty():
		return _from_plan(me)

	if not me.is_actionable():
		return _emit(me, 0, 0, 0)

	_cooldown -= 1
	_passive_frames += 1
	if _cooldown > 0 and _passive_frames < 70:
		return _emit(me, 0, 0, 0)
	_decide(me, opp, seen)
	_cooldown = profile.decision_interval + rng.randi_range(0, 8)
	return _from_plan(me) if not _plan.is_empty() else _emit(me, 0, 0, 0)


# --------------------------------------------------------------------------
# Perception
# --------------------------------------------------------------------------

func _record(opp: FighterSim, world: CombatWorld) -> void:
	var proj_dist := 999.0
	var proj_id := -1
	var me: FighterSim = world.fighters[me_index]
	for p in world.projectiles:
		if p.owner == opp:
			var d := absf(p.pos.x - me.pos.x)
			if d < proj_dist and signf(me.pos.x - p.pos.x) == float(p.dir):
				proj_dist = d
				proj_id = p.id
	var snap := {
		"state": opp.state,
		"phase": opp.attack_phase(),
		"attack": opp.attack,
		"attack_start": world.frame - opp.state_frame if opp.is_attacking() else -1,
		"low": opp.attack != null and opp.attack.hit_level == AttackData.HitLevel.LOW,
		"airborne": opp.airborne,
		"x": opp.pos.x,
		"y": opp.pos.y,
		"vx": opp.vel.x,
		"proj_dist": proj_dist,
		"proj_id": proj_id,
		"dist": absf(opp.pos.x - me.pos.x),
	}
	_history.append(snap)
	var keep := profile.reaction_frames + 1
	while _history.size() > keep:
		_history.pop_front()


func _perceived() -> Dictionary:
	if _history.size() <= profile.reaction_frames:
		return {}
	return _history[0]


## Returns an id for a perceived threat, or -1.
func _threat(seen: Dictionary, me: FighterSim) -> int:
	if seen.is_empty():
		return -1
	if seen["proj_id"] != -1 and seen["proj_dist"] < 3.5 and seen["proj_id"] != _handled_proj:
		_handled_proj = seen["proj_id"]
		return 100000 + int(seen["proj_id"])
	if seen["phase"] in ["startup", "active"] and seen["attack"] != null:
		var atk: AttackData = seen["attack"]
		if atk.kind == AttackData.Kind.THROW or atk.kind == AttackData.Kind.COUNTER or atk.kind == AttackData.Kind.EVADE:
			return -1
		var reach := atk.hitbox.position.x + atk.hitbox.size.x + 0.6 + atk.move_velocity.x * 0.3
		if seen["dist"] <= reach + 0.5:
			return int(seen["attack_start"])
	return -1


# --------------------------------------------------------------------------
# Decisions
# --------------------------------------------------------------------------

func _decide(me: FighterSim, opp: FighterSim, seen: Dictionary) -> void:
	_passive_frames = 0
	var dist := absf(opp.pos.x - me.pos.x)
	var tele := profile.telegraph_frames

	if rng.randf() < profile.mistake_chance:
		_random_action()
		return

	if not seen.is_empty():
		# Punish a perceived whiff / unsafe recovery.
		if seen["phase"] == "recovery" and seen["dist"] < 2.2 and rng.randf() < profile.punish_chance:
			_attack(InputState.HEAVY, 0, 0)
			return
		# Anti-air an incoming jump.
		if seen["airborne"] and seen["dist"] < 2.6 and seen["y"] > 0.4 and rng.randf() < profile.anti_air_chance:
			_attack(InputState.HEAVY, 0, 0)
			return

	var has_projectile := me.data.has_move(&"sp_neutral") and me.data.get_move(&"sp_neutral").kind == AttackData.Kind.PROJECTILE
	if dist > 4.2:
		var r := rng.randf()
		if has_projectile and not me.projectile_out and r < profile.special_chance:
			_telegraph(tele)
			_attack(InputState.SPECIAL, 0, 0)
		elif r < profile.special_chance + profile.aggression * 0.5:
			_plan.append({"x": 1, "y": 0, "b": 0, "frames": 2})
			_plan.append({"x": 0, "y": 0, "b": 0, "frames": 2})
			_plan.append({"x": 1, "y": 0, "b": 0, "frames": 2})   # dash in
		else:
			_plan.append({"x": 1, "y": 0, "b": 0, "frames": 18 + rng.randi_range(0, 18), "interruptible": true})
	elif dist > 1.7:
		var r2 := rng.randf()
		if r2 < profile.jump_chance:
			_plan.append({"x": 1, "y": 1, "b": 0, "frames": 4})
			_plan.append({"x": 0, "y": 0, "b": 0, "frames": 12})
			_plan.append({"x": 0, "y": 0, "b": InputState.HEAVY, "frames": 2})
		elif r2 < profile.jump_chance + profile.special_chance * 0.6:
			_telegraph(tele)
			_attack(InputState.SPECIAL, 1, 0)
		elif r2 < 0.55:
			_telegraph(tele)
			_attack(InputState.MEDIUM, 0, -1 if rng.randf() < 0.5 else 0)
		elif r2 < 0.55 + profile.aggression * 0.4:
			_plan.append({"x": 1, "y": 0, "b": 0, "frames": 10 + rng.randi_range(0, 14), "interruptible": true})
		else:
			_plan.append({"x": -1, "y": 0, "b": 0, "frames": 10 + rng.randi_range(0, 10), "interruptible": true})
	else:
		var r3 := rng.randf()
		if r3 < profile.throw_chance:
			_attack(InputState.THROW, 0, 0)
		elif r3 < profile.throw_chance + profile.aggression * 0.7:
			_telegraph(tele)
			_attack(InputState.LIGHT, 0, -1 if rng.randf() < 0.35 else 0)
		elif r3 < 0.85:
			_plan.append({"x": -1, "y": -1 if rng.randf() < 0.4 else 0, "b": 0, "frames": 12 + rng.randi_range(0, 12), "interruptible": true})
		else:
			_plan.append({"x": -1, "y": 0, "b": 0, "frames": 2})
			_plan.append({"x": 0, "y": 0, "b": 0, "frames": 2})
			_plan.append({"x": -1, "y": 0, "b": 0, "frames": 2})   # back dash


func _telegraph(frames: int) -> void:
	if frames > 0:
		_plan.append({"x": 0, "y": 0, "b": 0, "frames": frames})


func _attack(button: int, rel_x: int, y: int) -> void:
	_plan.append({"x": rel_x, "y": y, "b": button, "frames": 2})
	_plan.append({"x": 0, "y": 0, "b": 0, "frames": 1})


func _random_action() -> void:
	var options := [InputState.LIGHT, InputState.MEDIUM, InputState.HEAVY, InputState.SPECIAL, 0]
	var b: int = options[rng.randi_range(0, options.size() - 1)]
	if b == 0:
		_plan.append({"x": rng.randi_range(-1, 1), "y": 0, "b": 0, "frames": 16})
	else:
		_attack(b, rng.randi_range(-1, 1), 0)


func _next_combo_button(me: FighterSim) -> int:
	var a := me.attack
	if a == null:
		return 0
	match a.strength:
		AttackData.Strength.LIGHT:
			return InputState.MEDIUM
		AttackData.Strength.MEDIUM:
			return InputState.HEAVY
		AttackData.Strength.HEAVY:
			return InputState.SPECIAL if rng.randf() < profile.special_chance + 0.3 else 0
	return 0


# --------------------------------------------------------------------------
# Output
# --------------------------------------------------------------------------

func _from_plan(me: FighterSim) -> InputState:
	var step: Dictionary = _plan[0]
	step["frames"] -= 1
	if step["frames"] <= 0:
		_plan.pop_front()
	return _emit(me, step["x"], step["y"], step["b"])


func _emit(me: FighterSim, rel_x: int, y: int, buttons: int) -> InputState:
	# Release buttons for one frame between identical presses so each plan
	# step is a fresh press, like a human tapping a button.
	if buttons != 0 and buttons == _last_buttons and _plan.is_empty():
		buttons = 0
	_last_buttons = buttons
	return InputState.new(rel_x * me.facing, y, buttons)
