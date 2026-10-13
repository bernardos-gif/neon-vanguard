class_name FighterSim
extends RefCounted
## Deterministic simulation of one fighter on the 2D combat plane.
##
## Coordinates: x = horizontal position (metres), y = height above the floor.
## The simulation advances exactly one frame per call to update() at 60 Hz and
## has no dependency on rendering, nodes or the frame rate.

enum State {
	IDLE, WALK, CROUCH, PREJUMP, JUMP, LANDING, DASH, ATTACK,
	HITSTUN, BLOCKSTUN, KNOCKDOWN, WAKEUP, THROWING, THROWN, KO, VICTORY,
}

const DT := 1.0 / 60.0
const BUFFER_FRAMES := 8
const DOUBLE_TAP_FRAMES := 12
const DASH_REQUEST_FRAMES := 4
const PREJUMP_FRAMES := 3
const LANDING_FRAMES := 3
const AIR_ATTACK_LANDING_FRAMES := 4
const KNOCKDOWN_FRAMES := 42
const WAKEUP_FRAMES := 14
const GROUND_FRICTION := 20.0
const MAX_JUGGLE := 3
const THROW_TECH_FRAMES := 9
const THROW_HIT_FRAME := 20
const THROW_TOTAL_FRAMES := 40
const THROW_DAMAGE_DEFAULT := 100
const ATTACK_ORDER := [InputState.HEAVY, InputState.MEDIUM, InputState.LIGHT]
const BUTTON_NAMES := {
	InputState.LIGHT: "light", InputState.MEDIUM: "medium", InputState.HEAVY: "heavy",
}

var data: FighterData
var index := 0

var pos := Vector2.ZERO
var vel := Vector2.ZERO
var facing := 1
var airborne := false
var health := 1000
var state: State = State.IDLE
var state_frame := 0
var crouching := false

# Current move
var attack: AttackData
var attack_connected := false   # hit or blocked: enables cancels
var attack_hit := false         # connected on hit
var hits_landed := 0
var last_hit_frame := -100
var air_attack_used := false

# Stun / defence
var stun := 0
var juggle_count := 0
var block_low := false
var invuln := 0
var throw_partner: FighterSim
var projectile_out := false
## Set while the fighter is locked (round intro / round over).
var locked := false

# Combo counters (victim side: hits taken in the current combo)
var combo_hits := 0
var combo_damage := 0

# Movement helpers
var jump_dir := 0
var dash_dir := 0

# Input handling
var input := InputState.new()
var prev_buttons := 0
var prev_x := 0
var buffer: Array = []          # [{ "b": button, "age": frames }]
var tap_forward_age := 999
var tap_back_age := 999
var dash_request := 0
var dash_request_age := 0

# Statistics for the results screen
var stat_damage_dealt := 0
var stat_max_combo := 0
var stat_hits := 0
var stat_blocks := 0
var stat_attacks := 0

## The owning CombatWorld, held weakly to avoid a reference cycle.
var world:
	get:
		return _world_ref.get_ref() if _world_ref else null
	set(value):
		_world_ref = weakref(value) if value else null
var _world_ref: WeakRef


func _init(p_data: FighterData, p_index: int) -> void:
	data = p_data
	index = p_index
	reset_for_round(0.0, 1)


func reset_for_round(x: float, face: int) -> void:
	pos = Vector2(x, 0.0)
	vel = Vector2.ZERO
	facing = face
	airborne = false
	health = data.max_health
	attack = null
	attack_connected = false
	attack_hit = false
	stun = 0
	juggle_count = 0
	invuln = 0
	throw_partner = null
	projectile_out = false
	combo_hits = 0
	combo_damage = 0
	crouching = false
	block_low = false
	air_attack_used = false
	clear_input()
	_set_state(State.IDLE, true)


func clear_input() -> void:
	buffer.clear()
	dash_request = 0
	tap_forward_age = 999
	tap_back_age = 999
	input = InputState.new()


# --------------------------------------------------------------------------
# Input
# --------------------------------------------------------------------------

## Called every frame (including hitstop frames) with the latest input.
func feed_input(inp: InputState) -> void:
	if locked:
		inp = InputState.new()
	var pressed := inp.buttons & ~prev_buttons
	prev_buttons = inp.buttons
	for b in [InputState.LIGHT, InputState.MEDIUM, InputState.HEAVY, InputState.SPECIAL, InputState.THROW]:
		if (pressed & b) != 0:
			buffer.append({"b": b, "age": 0})
	if inp.x != 0 and inp.x != prev_x:
		if inp.x == facing:
			if tap_forward_age <= DOUBLE_TAP_FRAMES:
				_request_dash(1)
				tap_forward_age = 999
			else:
				tap_forward_age = 0
		else:
			if tap_back_age <= DOUBLE_TAP_FRAMES:
				_request_dash(-1)
				tap_back_age = 999
			else:
				tap_back_age = 0
	prev_x = inp.x
	input = inp


func _request_dash(dir: int) -> void:
	dash_request = dir
	dash_request_age = 0


## Ages buffered inputs. Not called during hitstop, so presses made during an
## impact freeze are kept for the frame the action resumes.
func age_buffer() -> void:
	for e in buffer:
		e["age"] += 1
	buffer = buffer.filter(func(e): return e["age"] <= BUFFER_FRAMES)
	tap_forward_age = mini(tap_forward_age + 1, 999)
	tap_back_age = mini(tap_back_age + 1, 999)
	if dash_request != 0:
		dash_request_age += 1
		if dash_request_age > DASH_REQUEST_FRAMES:
			dash_request = 0


func has_buffered(mask: int) -> bool:
	for e in buffer:
		if (e["b"] & mask) != 0:
			return true
	return false


## Removes and returns the oldest buffered button matching mask (0 if none).
## Buttons pressed on the same frame resolve strongest first.
func consume(mask: int) -> int:
	var best := -1
	for i in buffer.size():
		var b: int = buffer[i]["b"]
		if (b & mask) == 0:
			continue
		if best < 0 or buffer[i]["age"] > buffer[best]["age"] or (buffer[i]["age"] == buffer[best]["age"] and b > buffer[best]["b"]):
			best = i
	if best < 0:
		return 0
	var result: int = buffer[best]["b"]
	buffer.remove_at(best)
	return result


# --------------------------------------------------------------------------
# Queries
# --------------------------------------------------------------------------

func is_actionable() -> bool:
	return state in [State.IDLE, State.WALK, State.CROUCH]


func half_width() -> float:
	return data.pushbox_width * 0.5


func is_attacking() -> bool:
	return state == State.ATTACK and attack != null


func attack_phase() -> String:
	if not is_attacking():
		return ""
	if state_frame < attack.startup:
		return "startup"
	if attack.is_active_frame(state_frame):
		return "active"
	return "recovery"


func is_invulnerable() -> bool:
	if invuln > 0:
		return true
	match state:
		State.KNOCKDOWN, State.WAKEUP, State.KO, State.THROWING, State.THROWN, State.VICTORY:
			return true
		State.ATTACK:
			if attack and attack.is_invulnerable_frame(state_frame):
				return true
		State.HITSTUN:
			if airborne and juggle_count >= MAX_JUGGLE:
				return true
	return false


func is_throwable() -> bool:
	if airborne or is_invulnerable():
		return false
	return not (state in [State.HITSTUN, State.BLOCKSTUN, State.KNOCKDOWN, State.WAKEUP, State.THROWING, State.THROWN, State.KO])


func hurtbox() -> Rect2:
	var w := data.pushbox_width + 0.12
	var h := data.stand_height
	var y := pos.y
	if crouching or (state == State.BLOCKSTUN and block_low):
		h = data.crouch_height
	if airborne:
		y += 0.25
		h = 1.35
	if state == State.ATTACK and attack and attack.low_profile and state_frame < attack.startup + attack.active:
		h = 0.9
	if state == State.KNOCKDOWN or state == State.KO:
		h = 0.4
	return Rect2(pos.x - w * 0.5, y, w, h)


func hitbox_for(atk: AttackData) -> Rect2:
	var hb := atk.hitbox
	var x0 := pos.x + facing * hb.position.x
	var x1 := pos.x + facing * (hb.position.x + hb.size.x)
	return Rect2(minf(x0, x1), pos.y + hb.position.y, absf(x1 - x0), hb.size.y)


## True on frames where the current strike can register a new hit.
func can_strike_now() -> bool:
	if state != State.ATTACK or attack == null or attack.kind != AttackData.Kind.STRIKE:
		return false
	if not attack.is_active_frame(state_frame):
		return false
	if hits_landed >= attack.hits:
		return false
	if hits_landed > 0 and state_frame - last_hit_frame < maxi(1, attack.hit_interval):
		return false
	return true


## Whether this fighter blocks an attack of the given level coming from source_x.
func can_block(level: int, source_x: float) -> bool:
	if airborne or locked:
		return false
	if not (state in [State.IDLE, State.WALK, State.CROUCH, State.BLOCKSTUN]):
		return false
	var away := -1 if source_x > pos.x else 1
	if is_equal_approx(source_x, pos.x):
		away = -facing
	if input.x != away:
		return false
	var low := input.y < 0
	match level:
		AttackData.HitLevel.MID:
			return true
		AttackData.HitLevel.LOW:
			return low
		AttackData.HitLevel.OVERHEAD:
			return not low
	return false


## True when holding a guard direction away from the opponent (for visuals).
func is_guarding(opp_x: float) -> bool:
	if state == State.BLOCKSTUN:
		return true
	if not is_actionable():
		return false
	var away := -1 if opp_x > pos.x else 1
	return input.x == away


# --------------------------------------------------------------------------
# Per-frame update
# --------------------------------------------------------------------------

func update(opp: FighterSim) -> void:
	state_frame += 1
	if invuln > 0:
		invuln -= 1
	match state:
		State.IDLE, State.WALK, State.CROUCH:
			_face(opp)
			if locked or not _try_ground_actions():
				_ground_movement()
		State.PREJUMP:
			vel.x = 0.0
			if state_frame >= PREJUMP_FRAMES:
				_launch_jump()
		State.JUMP:
			if not locked:
				_try_air_attack()
		State.LANDING:
			vel.x = 0.0
			if state_frame >= _landing_frames:
				to_neutral(opp)
		State.DASH:
			_update_dash(opp)
		State.ATTACK:
			_update_attack(opp)
		State.HITSTUN:
			if not airborne:
				stun -= 1
				if stun <= 0:
					end_combo()
					to_neutral(opp)
		State.BLOCKSTUN:
			stun -= 1
			if stun <= 0:
				to_neutral(opp)
		State.KNOCKDOWN:
			vel.x = 0.0
			if state_frame >= KNOCKDOWN_FRAMES:
				_set_state(State.WAKEUP)
		State.WAKEUP:
			if state_frame >= WAKEUP_FRAMES:
				invuln = 2
				to_neutral(opp)
		State.THROWING:
			vel.x = 0.0
			if state_frame == THROW_HIT_FRAME and throw_partner and world:
				world.resolve_throw_damage(self)
			if state_frame >= THROW_TOTAL_FRAMES:
				throw_partner = null
				to_neutral(opp)
		State.THROWN:
			if throw_partner:
				pos = throw_partner.pos + Vector2(throw_partner.facing * (throw_partner.half_width() + half_width() + 0.05), 0.0)
				vel = Vector2.ZERO
				if state_frame <= THROW_TECH_FRAMES and consume(InputState.THROW) != 0 and world:
					world.resolve_throw_tech(throw_partner, self)
		State.KO, State.VICTORY:
			pass
	_integrate(opp)


var _landing_frames := LANDING_FRAMES


func _set_state(s: State, force := false) -> void:
	if s != state or force:
		state = s
		state_frame = 0


func _face(opp: FighterSim) -> void:
	if airborne:
		return
	var d := opp.pos.x - pos.x
	if absf(d) > 0.01:
		facing = 1 if d > 0 else -1


func to_neutral(opp: FighterSim = null) -> void:
	attack = null
	if opp:
		_face(opp)
	if airborne:
		_set_state(State.JUMP, true)
	elif input.y < 0 and not locked:
		crouching = true
		_set_state(State.CROUCH, true)
	else:
		crouching = false
		_set_state(State.IDLE, true)


func end_combo() -> void:
	combo_hits = 0
	combo_damage = 0
	juggle_count = 0


func _try_ground_actions() -> bool:
	# Throw
	if consume(InputState.THROW) != 0:
		return start_attack(&"throw")
	# Specials: Special button + direction
	if has_buffered(InputState.SPECIAL):
		var id := _special_for_direction()
		if data.has_move(id) and _can_use_move(id):
			consume(InputState.SPECIAL)
			return start_attack(id)
		consume(InputState.SPECIAL)
	# Normals
	var b := consume(InputState.ATTACK_BUTTONS)
	if b != 0:
		var prefix := "cr_" if input.y < 0 else "st_"
		return start_attack(StringName(prefix + BUTTON_NAMES[b]))
	# Dash
	if dash_request != 0:
		dash_dir = dash_request
		dash_request = 0
		_set_state(State.DASH, true)
		crouching = false
		if dash_dir < 0:
			invuln = 5
		return true
	# Jump
	if input.y > 0:
		jump_dir = input.x
		crouching = false
		_set_state(State.PREJUMP, true)
		return true
	return false


func _special_for_direction() -> StringName:
	var rel := input.x * facing
	if rel > 0:
		return &"sp_forward"
	if rel < 0:
		return &"sp_back"
	return &"sp_neutral"


func _can_use_move(id: StringName) -> bool:
	var a := data.get_move(id)
	if a == null:
		return false
	if a.kind == AttackData.Kind.PROJECTILE and projectile_out:
		return false
	return true


func _ground_movement() -> void:
	var want_crouch := input.y < 0 and not locked
	crouching = want_crouch
	if want_crouch:
		_set_state(State.CROUCH)
		vel.x = move_toward(vel.x, 0.0, GROUND_FRICTION * DT)
	elif input.x != 0 and not locked:
		_set_state(State.WALK)
		var spd := data.walk_forward_speed if input.x == facing else data.walk_back_speed
		vel.x = input.x * spd
	else:
		_set_state(State.IDLE)
		vel.x = move_toward(vel.x, 0.0, GROUND_FRICTION * DT)


func _launch_jump() -> void:
	airborne = true
	air_attack_used = false
	var hspeed := 0.0
	if jump_dir != 0:
		hspeed = data.jump_forward_speed if jump_dir == facing else data.jump_back_speed
	vel = Vector2(jump_dir * hspeed, data.jump_velocity)
	_set_state(State.JUMP, true)
	if world:
		world.emit_event({"type": "jump", "fighter": index})


func _try_air_attack() -> void:
	if air_attack_used:
		return
	var b := consume(InputState.ATTACK_BUTTONS)
	if b != 0:
		var id := StringName("j_" + BUTTON_NAMES[b])
		if data.has_move(id):
			air_attack_used = true
			start_attack(id)


func _update_dash(opp: FighterSim) -> void:
	var frames := data.dash_forward_frames if dash_dir > 0 else data.dash_back_frames
	var spd := data.dash_forward_speed if dash_dir > 0 else data.dash_back_speed
	var t := float(state_frame) / float(maxi(frames, 1))
	vel.x = dash_dir * facing * spd * (1.0 - t * t)
	if state_frame >= frames:
		vel.x = 0.0
		to_neutral(opp)


## Starts a move by id. Returns false when the fighter has no such move.
func start_attack(id: StringName) -> bool:
	var a := data.get_move(id)
	if a == null:
		return false
	attack = a
	attack_connected = false
	attack_hit = false
	hits_landed = 0
	last_hit_frame = -100
	stat_attacks += 1
	crouching = String(id).begins_with("cr_")
	_set_state(State.ATTACK, true)
	if not airborne:
		vel.x = 0.0
	if world:
		world.emit_event({"type": "attack_start", "fighter": index, "move": id, "sound": a.whiff_sound, "strength": a.strength})
	return true


func _update_attack(opp: FighterSim) -> void:
	var a := attack
	var f := state_frame
	if not airborne:
		if a.move_end > a.move_start and f >= a.move_start and f < a.move_end:
			vel.x = a.move_velocity.x * facing
		else:
			vel.x = move_toward(vel.x, 0.0, GROUND_FRICTION * DT)
	if a.kind == AttackData.Kind.PROJECTILE and f == a.startup and world:
		world.spawn_projectile(self, a)
	if a.kind == AttackData.Kind.THROW and a.is_active_frame(f) and world:
		if world.try_throw(self, opp):
			return
	if attack_connected and not airborne and not locked and _try_cancel():
		return
	if f >= a.total_frames() - 1:
		if airborne:
			attack = null
			_set_state(State.JUMP, true)
		else:
			to_neutral(opp)


func _try_cancel() -> bool:
	var a := attack
	if a.cancel_into_specials and has_buffered(InputState.SPECIAL):
		var id := _special_for_direction()
		if id != a.id and data.has_move(id) and _can_use_move(id):
			consume(InputState.SPECIAL)
			return start_attack(id)
	if a.cancel_into_normals and a.is_normal():
		for b in ATTACK_ORDER:
			var tier := ATTACK_ORDER.size() - 1 - ATTACK_ORDER.find(b)
			if tier > int(a.strength) and has_buffered(b):
				consume(b)
				var prefix := "cr_" if input.y < 0 else "st_"
				return start_attack(StringName(prefix + BUTTON_NAMES[b]))
	return false


func _integrate(opp: FighterSim) -> void:
	if state == State.THROWN:
		return
	if airborne:
		vel.y -= data.gravity * DT
		pos += vel * DT
		if pos.y <= 0.0 and vel.y <= 0.0:
			pos.y = 0.0
			_on_land(opp)
	else:
		# Walking, dashing and attacking set their own velocity every frame;
		# every other grounded state (stun, landing, knockdown...) slides to a stop.
		if not (state in [State.WALK, State.DASH, State.ATTACK]):
			vel.x = move_toward(vel.x, 0.0, GROUND_FRICTION * DT)
		pos.x += vel.x * DT
		pos.y = 0.0


func _on_land(opp: FighterSim) -> void:
	airborne = false
	vel.y = 0.0
	match state:
		State.JUMP:
			vel.x = 0.0
			_landing_frames = LANDING_FRAMES
			_set_state(State.LANDING, true)
			_face(opp)
			if world:
				world.emit_event({"type": "land", "fighter": index})
		State.ATTACK:
			vel.x = 0.0
			attack = null
			_landing_frames = AIR_ATTACK_LANDING_FRAMES
			_set_state(State.LANDING, true)
			_face(opp)
			if world:
				world.emit_event({"type": "land", "fighter": index})
		State.HITSTUN:
			vel.x = 0.0
			end_combo()
			_set_state(State.KNOCKDOWN, true)
			if world:
				world.emit_event({"type": "knockdown", "fighter": index})
		State.KO:
			vel.x = 0.0
			if world:
				world.emit_event({"type": "knockdown", "fighter": index})
		_:
			vel.x = 0.0
			to_neutral(opp)


# --------------------------------------------------------------------------
# Reactions (called by CombatWorld)
# --------------------------------------------------------------------------

func enter_hitstun(frames: int, push: float) -> void:
	attack = null
	crouching = false
	stun = maxi(frames, 1)
	vel.x = push
	_set_state(State.HITSTUN, true)


func enter_blockstun(frames: int, push: float, low: bool) -> void:
	attack = null
	block_low = low
	crouching = low
	stun = maxi(frames, 1)
	vel.x = push
	_set_state(State.BLOCKSTUN, true)


func launch(velocity: Vector2) -> void:
	attack = null
	crouching = false
	airborne = true
	vel = velocity
	if pos.y <= 0.0:
		pos.y = 0.01
	_set_state(State.HITSTUN, true)


func enter_ko(velocity: Vector2) -> void:
	attack = null
	crouching = false
	airborne = true
	vel = velocity
	if pos.y <= 0.0:
		pos.y = 0.01
	_set_state(State.KO, true)


func enter_victory() -> void:
	if state == State.KO:
		return
	attack = null
	crouching = false
	vel.x = 0.0
	_set_state(State.VICTORY, true)
