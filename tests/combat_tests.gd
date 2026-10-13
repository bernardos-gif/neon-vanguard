class_name CombatTests
extends RefCounted
## Automated tests for the combat engine, round flow and CPU.
## Run with:  godot --headless --path . res://tests/test_runner.tscn

const N := InputState.LIGHT * 0

var kairo: FighterData
var vesper: FighterData
var passed := 0
var failed := 0
var failures: Array[String] = []
var _current := ""


func _init() -> void:
	kairo = load("res://data/fighters/kairo.tres")
	vesper = load("res://data/fighters/vesper.tres")


func run_all() -> void:
	var tests := [
		"test_data_complete",
		"test_jab_damages_only_on_active_frame",
		"test_out_of_range_whiffs",
		"test_standing_block_prevents_damage",
		"test_low_attack_needs_crouch_block",
		"test_block_level_rules",
		"test_chip_damage_cannot_ko",
		"test_chain_combo_and_scaling",
		"test_throw_beats_block",
		"test_throw_tech",
		"test_projectile_hits",
		"test_projectiles_clash",
		"test_counter_stance",
		"test_evade_is_invulnerable",
		"test_knockdown_and_wakeup",
		"test_held_button_triggers_once",
		"test_no_duplicate_hits_per_attack",
		"test_multi_hit_special",
		"test_determinism",
		"test_round_transition",
		"test_match_completion",
		"test_timeout_rules",
		"test_double_ko_is_draw",
		"test_soak_invariants",
		"test_ai_completes_matches",
	]
	for t in tests:
		_current = t
		var before := failed
		call(t)
		if failed == before:
			passed += 1
			print("  PASS  ", t)
		else:
			print("  FAIL  ", t)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failed += 1
		failures.append("%s: %s" % [_current, msg])
		push_error("TEST FAILURE %s: %s" % [_current, msg])


# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------

func _world(a: FighterData, b: FighterData, distance := 0.9) -> CombatWorld:
	var w := CombatWorld.new(a, b)
	w.fighters[0].pos.x = -distance * 0.5
	w.fighters[1].pos.x = distance * 0.5
	return w


func _in(x := 0, y := 0, b := 0) -> InputState:
	return InputState.new(x, y, b)


## Steps the world n frames with constant inputs, returns all events.
func _run(w: CombatWorld, n: int, a: InputState = null, b: InputState = null) -> Array:
	var ev: Array = []
	for i in n:
		ev.append_array(w.step(a if a else _in(), b if b else _in()))
	return ev


func _count(events: Array, type: String) -> int:
	var c := 0
	for e in events:
		if e["type"] == type:
			c += 1
	return c


# --------------------------------------------------------------------------
# Tests
# --------------------------------------------------------------------------

func test_data_complete() -> void:
	var required := ["st_light", "st_medium", "st_heavy", "cr_light", "cr_medium", "cr_heavy",
		"j_light", "j_medium", "j_heavy", "sp_neutral", "sp_forward", "sp_back", "throw"]
	for f in [kairo, vesper]:
		_check(f != null, "fighter data failed to load")
		if f == null:
			continue
		for id in required:
			_check(f.has_move(StringName(id)), "%s is missing move %s" % [f.id, id])
		for id in f.moves:
			var m: AttackData = f.moves[id]
			_check(m.startup >= 1 and m.active >= 1 and m.recovery >= 0, "%s %s has invalid frame data" % [f.id, id])
	_check(kairo.has_move(&"still_water_strike"), "Kairo counter follow-up missing")


func test_jab_damages_only_on_active_frame() -> void:
	var w := _world(kairo, vesper)
	var target: FighterSim = w.fighters[1]
	var full := target.health
	var hit_step := -1
	for step in range(1, 20):
		var b := InputState.LIGHT if step == 1 else 0
		w.step(_in(0, 0, b), _in())
		if target.health < full and hit_step < 0:
			hit_step = step
	var jab := kairo.get_move(&"st_light")
	# Pressed on step 1 = move frame 0, first active frame = move frame `startup`.
	_check(hit_step == 1 + jab.startup, "jab hit on step %d, expected %d" % [hit_step, 1 + jab.startup])
	_check(target.health == full - jab.damage, "jab dealt %d, expected %d" % [full - target.health, jab.damage])


func test_out_of_range_whiffs() -> void:
	var w := _world(kairo, vesper, 3.0)
	var ev := w.step(_in(0, 0, InputState.HEAVY), _in())
	ev.append_array(_run(w, 40))
	_check(w.fighters[1].health == vesper.max_health, "attack hit from 3 m away")
	_check(_count(ev, "hit") == 0, "unexpected hit event")


func test_standing_block_prevents_damage() -> void:
	var w := _world(kairo, vesper)
	var ev := w.step(_in(0, 0, InputState.MEDIUM), _in(1))
	ev.append_array(_run(w, 30, _in(), _in(1)))
	_check(w.fighters[1].health == vesper.max_health, "blocked medium dealt damage")
	_check(_count(ev, "block") == 1, "expected exactly one block event, got %d" % _count(ev, "block"))
	_check(w.fighters[1].stat_blocks == 1, "block statistic not recorded")


func test_low_attack_needs_crouch_block() -> void:
	# Standing guard loses to a low.
	var w := _world(kairo, vesper)
	w.step(_in(0, -1, InputState.MEDIUM), _in(1, 0))
	_run(w, 30, _in(), _in(1, 0))
	_check(w.fighters[1].health < vesper.max_health, "low attack was blocked standing")
	# Crouching guard blocks it.
	var w2 := _world(kairo, vesper)
	var ev := w2.step(_in(0, -1, InputState.MEDIUM), _in(1, -1))
	ev.append_array(_run(w2, 30, _in(), _in(1, -1)))
	_check(w2.fighters[1].health == vesper.max_health, "crouch block failed against low")
	_check(_count(ev, "block") == 1, "no block event for crouch block")


func test_block_level_rules() -> void:
	var w := _world(kairo, vesper)
	var d: FighterSim = w.fighters[1]   # attacker is on the left (x < d.x)
	d.input = _in(1, 0)
	_check(d.can_block(AttackData.HitLevel.MID, -1.0), "standing guard should block mid")
	_check(d.can_block(AttackData.HitLevel.OVERHEAD, -1.0), "standing guard should block overhead")
	_check(not d.can_block(AttackData.HitLevel.LOW, -1.0), "standing guard must not block low")
	d.input = _in(1, -1)
	_check(d.can_block(AttackData.HitLevel.LOW, -1.0), "crouch guard should block low")
	_check(not d.can_block(AttackData.HitLevel.OVERHEAD, -1.0), "crouch guard must not block overhead")
	d.input = _in(-1, 0)
	_check(not d.can_block(AttackData.HitLevel.MID, -1.0), "holding toward attacker must not block")
	_check(not d.can_block(AttackData.HitLevel.UNBLOCKABLE, -1.0), "unblockable was blocked")
	d.input = _in(1, 0)
	d.airborne = true
	_check(not d.can_block(AttackData.HitLevel.MID, -1.0), "air blocking is not allowed")


func test_chip_damage_cannot_ko() -> void:
	var w := _world(kairo, vesper, 1.4)
	w.fighters[1].health = 3
	var ev := w.step(_in(1, 0, InputState.SPECIAL), _in(1))
	ev.append_array(_run(w, 60, _in(), _in(1)))
	_check(_count(ev, "block") >= 1, "Comet Drive was not blocked")
	_check(w.fighters[1].health == 1, "chip left health at %d, expected 1" % w.fighters[1].health)
	_check(w.fighters[1].state != FighterSim.State.KO, "chip damage caused a KO")


func test_chain_combo_and_scaling() -> void:
	var w := _world(kairo, vesper)
	var target: FighterSim = w.fighters[1]
	var max_combo := 0
	for step in range(1, 90):
		var b := 0
		if step % 2 == 1:
			if step < 6:
				b = InputState.LIGHT
			elif step < 20:
				b = InputState.MEDIUM
			elif step < 34:
				b = InputState.HEAVY
		w.step(_in(0, 0, b), _in())
		max_combo = maxi(max_combo, target.combo_hits)
		if step > 3 and target.combo_hits == 0 and max_combo > 0 and max_combo < 3:
			break
	_check(max_combo == 3, "expected a 3-hit chain combo, got %d" % max_combo)
	var expected := 30 + 55 + int(round(90 * 0.9))
	_check(vesper.max_health - target.health == expected, "combo damage %d, expected %d (scaling)" % [vesper.max_health - target.health, expected])


func test_throw_beats_block() -> void:
	var w := _world(kairo, vesper, 0.65)
	var ev := w.step(_in(0, 0, InputState.THROW), _in(1))
	var saw_knockdown := false
	for i in 80:
		ev.append_array(w.step(_in(), _in(1)))
		if w.fighters[1].state == FighterSim.State.KNOCKDOWN:
			saw_knockdown = true
	_check(_count(ev, "throw_start") == 1, "throw did not connect against a blocking opponent")
	_check(w.fighters[1].health == vesper.max_health - kairo.get_move(&"throw").damage, "throw damage incorrect: %d" % w.fighters[1].health)
	_check(saw_knockdown, "thrown fighter was not knocked down")


func test_throw_tech() -> void:
	var w := _world(kairo, vesper, 0.65)
	var ev: Array = []
	for step in range(1, 60):
		var a := InputState.THROW if step == 1 else 0
		var b := InputState.THROW if step == 6 else 0
		ev.append_array(w.step(_in(0, 0, a), _in(0, 0, b)))
	_check(_count(ev, "throw_start") == 1, "throw did not start")
	_check(_count(ev, "throw_tech") == 1, "throw was not teched")
	_check(w.fighters[1].health == vesper.max_health, "teched throw dealt damage")


func test_projectile_hits() -> void:
	var w := _world(kairo, vesper, 4.0)
	var ev := w.step(_in(0, 0, InputState.SPECIAL), _in())
	ev.append_array(_run(w, 90))
	_check(_count(ev, "projectile_spawn") == 1, "projectile not spawned")
	_check(w.fighters[1].health == vesper.max_health - kairo.get_move(&"sp_neutral").damage, "projectile damage wrong")
	_check(w.projectiles.is_empty() and not w.fighters[0].projectile_out, "projectile not cleaned up")
	# Only one projectile at a time.
	var w2 := _world(kairo, vesper, 6.5)
	var ev2: Array = []
	for step in range(1, 50):
		var b := InputState.SPECIAL if step % 2 == 1 else 0
		ev2.append_array(w2.step(_in(0, 0, b), _in()))
	_check(_count(ev2, "projectile_spawn") == 1, "more than one projectile on screen")


func test_projectiles_clash() -> void:
	var w := _world(kairo, kairo, 5.0)
	var ev := w.step(_in(0, 0, InputState.SPECIAL), _in(0, 0, InputState.SPECIAL))
	ev.append_array(_run(w, 90))
	_check(_count(ev, "projectile_spawn") == 2, "both projectiles should spawn")
	_check(w.fighters[0].health == kairo.max_health and w.fighters[1].health == kairo.max_health, "clashing projectiles dealt damage")


func test_counter_stance() -> void:
	var w := _world(kairo, vesper)
	var ev: Array = []
	for step in range(1, 70):
		var a := InputState.SPECIAL if step == 1 else 0
		var b := InputState.LIGHT if step == 2 else 0
		ev.append_array(w.step(_in(-1 if step == 1 else 0, 0, a), _in(0, 0, b)))
	_check(_count(ev, "counter") == 1, "counter did not trigger")
	_check(w.fighters[0].health == kairo.max_health, "countering fighter took damage")
	var riposte := kairo.get_move(&"still_water_strike").damage
	_check(w.fighters[1].health == vesper.max_health - riposte, "riposte damage wrong: %d" % (vesper.max_health - w.fighters[1].health))


func test_evade_is_invulnerable() -> void:
	var w := _world(vesper, kairo)
	# Vesper (P1, facing right) flips backwards; Kairo jabs during the flip.
	var ev: Array = []
	for step in range(1, 40):
		var a := InputState.SPECIAL if step == 1 else 0
		var b := InputState.LIGHT if step == 2 else 0
		ev.append_array(w.step(_in(-1 if step == 1 else 0, 0, a), _in(0, 0, b)))
	_check(w.fighters[0].health == vesper.max_health, "Mirage Flip was hit during invulnerability")


func test_knockdown_and_wakeup() -> void:
	var w := _world(kairo, vesper)
	var t: FighterSim = w.fighters[1]
	w.step(_in(0, -1, InputState.HEAVY), _in())
	var seen := {}
	var invuln_ok := true
	for i in 160:
		w.step(_in(), _in())
		seen[t.state] = true
		if t.state == FighterSim.State.KNOCKDOWN and not t.is_invulnerable():
			invuln_ok = false
	_check(seen.has(FighterSim.State.KNOCKDOWN), "sweep did not knock down")
	_check(seen.has(FighterSim.State.WAKEUP), "fighter did not wake up")
	_check(t.state == FighterSim.State.IDLE, "fighter did not return to idle (state %d)" % t.state)
	_check(invuln_ok, "knocked-down fighter was hittable")


func test_held_button_triggers_once() -> void:
	var w := _world(kairo, vesper, 3.0)
	var ev := _run(w, 40, _in(0, 0, InputState.LIGHT), _in())
	_check(_count(ev, "attack_start") == 1, "holding a button started %d attacks" % _count(ev, "attack_start"))


func test_no_duplicate_hits_per_attack() -> void:
	var w := _world(kairo, vesper)
	var ev := w.step(_in(0, 0, InputState.HEAVY), _in())
	ev.append_array(_run(w, 60))
	_check(_count(ev, "hit") == 1, "single-hit move registered %d hits" % _count(ev, "hit"))


func test_multi_hit_special() -> void:
	var w := _world(vesper, kairo)
	var ev := w.step(_in(0, 0, InputState.SPECIAL), _in())
	ev.append_array(_run(w, 80))
	_check(_count(ev, "hit") == 4, "Razor Flurry hit %d times, expected 4" % _count(ev, "hit"))


func _ai_match(d1: int, d2: int, fa: FighterData, fb: FighterData, seed: int, rounds := 2) -> Dictionary:
	var w := CombatWorld.new(fa, fb)
	var flow := MatchFlow.new(w, rounds, 99)
	var ai_a := CpuController.new(load(GameState.AI_PROFILES[d1]), 0, seed)
	var ai_b := CpuController.new(load(GameState.AI_PROFILES[d2]), 1, seed + 1)
	var ev := flow.start_match()
	var frames := 0
	var limit := 99 * 60 * flow.max_rounds() + 2000
	var invariant_error := ""
	var stuck := [0, 0]
	while flow.phase != MatchFlow.Phase.MATCH_END and frames < limit:
		var ia := ai_a.get_input(w)
		var ib := ai_b.get_input(w)
		ev.append_array(flow.tick(ia, ib))
		frames += 1
		for f in w.fighters:
			if f.health < 0 or f.health > f.data.max_health:
				invariant_error = "health out of range"
			if absf(f.pos.x) > CombatWorld.STAGE_HALF_WIDTH + 0.001:
				invariant_error = "fighter outside stage at x=%f" % f.pos.x
			if f.pos.y < -0.001:
				invariant_error = "fighter below floor"
			if f.state in [FighterSim.State.HITSTUN, FighterSim.State.BLOCKSTUN, FighterSim.State.THROWN]:
				stuck[f.index] += 1
				if stuck[f.index] > 400:
					invariant_error = "fighter stuck in stun state %d" % f.state
			else:
				stuck[f.index] = 0
		if absf(w.fighters[1].pos.x - w.fighters[0].pos.x) > CombatWorld.MAX_SEPARATION + 0.01:
			invariant_error = "fighters exceeded max separation"
	return {"flow": flow, "world": w, "events": ev, "frames": frames, "error": invariant_error}


func test_determinism() -> void:
	var r1 := _ai_match(2, 2, kairo, vesper, 1234, 1)
	var r2 := _ai_match(2, 2, kairo, vesper, 1234, 1)
	_check(r1["world"].snapshot() == r2["world"].snapshot(), "identical inputs produced different results")
	_check(r1["frames"] == r2["frames"], "identical matches lasted different lengths")


func test_round_transition() -> void:
	var w := _world(kairo, vesper)
	var flow := MatchFlow.new(w, 2, 99)
	flow.start_match()
	for i in MatchFlow.INTRO_FRAMES:
		flow.tick(_in(0, 0, InputState.LIGHT), _in())
	_check(flow.phase == MatchFlow.Phase.FIGHT, "did not reach FIGHT after intro")
	_check(w.fighters[1].health == vesper.max_health, "input during intro had an effect")
	_check(not w.fighters[0].locked, "fighters still locked after FIGHT")
	_ko_p2(flow)
	_check(flow.phase == MatchFlow.Phase.ROUND_END, "round did not end on KO")
	_check(flow.wins == [1, 0], "wins after round 1: %s" % str(flow.wins))
	var ev: Array = []
	for i in MatchFlow.ROUND_END_FRAMES:
		ev.append_array(flow.tick(_in(), _in()))
	_check(flow.phase == MatchFlow.Phase.INTRO and flow.round_number == 2, "round 2 did not start")
	_check(w.fighters[0].health == kairo.max_health and w.fighters[1].health == vesper.max_health, "health not reset for round 2")
	_check(_count(ev, "round_start") == 1, "expected one round_start event")
	_check(_count(ev, "victory_pose") == 1, "winner did not take a victory pose")


func _ko_p2(flow: MatchFlow) -> void:
	var w := flow.world
	w.fighters[0].pos.x = -0.45
	w.fighters[1].pos.x = 0.45
	w.fighters[1].health = 1
	flow.tick(_in(0, 0, InputState.LIGHT), _in())
	for i in 20:
		if flow.phase != MatchFlow.Phase.FIGHT:
			break
		flow.tick(_in(), _in())


func test_match_completion() -> void:
	var w := _world(kairo, vesper)
	var flow := MatchFlow.new(w, 2, 99)
	flow.start_match()
	var ev: Array = []
	for r in 2:
		for i in MatchFlow.INTRO_FRAMES:
			flow.tick(_in(), _in())
		_ko_p2(flow)
		for i in MatchFlow.ROUND_END_FRAMES:
			ev.append_array(flow.tick(_in(), _in()))
	_check(flow.phase == MatchFlow.Phase.MATCH_END, "match did not end after 2 round wins")
	_check(flow.match_winner == 0, "wrong match winner %d" % flow.match_winner)
	_check(_count(ev, "match_over") == 1, "expected exactly one match_over event")
	# Further ticks must not start new rounds or emit more results.
	var extra: Array = []
	for i in 300:
		extra.append_array(flow.tick(_in(), _in()))
	_check(_count(extra, "match_over") == 0 and _count(extra, "round_start") == 0, "events after match end")
	# Rematch: a fresh start resets everything.
	flow.start_match()
	_check(flow.wins == [0, 0] and flow.round_number == 1 and flow.phase == MatchFlow.Phase.INTRO, "rematch did not reset")


func test_timeout_rules() -> void:
	var w := _world(kairo, vesper, 3.0)
	var flow := MatchFlow.new(w, 2, 2)
	flow.start_match()
	for i in MatchFlow.INTRO_FRAMES:
		flow.tick(_in(), _in())
	w.fighters[1].health = 400
	for i in 2 * 60 + 5:
		flow.tick(_in(), _in())
	_check(flow.phase == MatchFlow.Phase.ROUND_END and flow.round_end_reason == "timeout", "timeout did not end the round")
	_check(flow.round_winner == 0, "timeout winner should be the healthier fighter")
	# Equal health ratio -> draw, no wins awarded.
	var w2 := _world(kairo, kairo, 3.0)
	var flow2 := MatchFlow.new(w2, 2, 1)
	flow2.start_match()
	for i in MatchFlow.INTRO_FRAMES + 70:
		flow2.tick(_in(), _in())
	_check(flow2.round_winner == MatchFlow.DRAW, "equal health timeout should be a draw")
	_check(flow2.wins == [0, 0], "draw awarded a round win")


func test_double_ko_is_draw() -> void:
	var w := _world(kairo, kairo)
	var flow := MatchFlow.new(w, 2, 99)
	flow.start_match()
	for i in MatchFlow.INTRO_FRAMES:
		flow.tick(_in(), _in())
	w.fighters[0].pos.x = -0.45
	w.fighters[1].pos.x = 0.45
	w.fighters[0].health = 1
	w.fighters[1].health = 1
	flow.tick(_in(0, 0, InputState.LIGHT), _in(0, 0, InputState.LIGHT))
	for i in 20:
		flow.tick(_in(), _in())
	_check(flow.round_end_reason == "double_ko", "simultaneous KO not detected (%s)" % flow.round_end_reason)
	_check(flow.wins == [0, 0], "double KO awarded a win")
	# Draw rounds cannot loop forever: the match is decided within max_rounds.
	var w3 := _world(kairo, kairo, 3.0)
	var flow3 := MatchFlow.new(w3, 1, 1)
	flow3.start_match()
	var guard := 0
	while flow3.phase != MatchFlow.Phase.MATCH_END and guard < 20000:
		flow3.tick(_in(), _in())
		guard += 1
	_check(flow3.phase == MatchFlow.Phase.MATCH_END and flow3.match_winner == MatchFlow.DRAW, "endless draws did not end as a draw game")


func test_soak_invariants() -> void:
	var seeds := [11, 22, 33]
	for s in seeds:
		var r := _ai_match(2, 2, kairo, vesper, s)
		_check(r["error"] == "", "invariant broken (seed %d): %s" % [s, r["error"]])


func test_ai_completes_matches() -> void:
	var pairs := [[kairo, vesper], [vesper, kairo], [vesper, vesper], [kairo, kairo]]
	for d in 3:
		for p in pairs:
			var r := _ai_match(d, 1, p[0], p[1], 500 + d * 10 + pairs.find(p))
			var flow: MatchFlow = r["flow"]
			var tag := "difficulty %s %s vs %s" % [GameState.DIFFICULTY_NAMES[d], p[0].id, p[1].id]
			_check(flow.phase == MatchFlow.Phase.MATCH_END, "%s: match did not finish" % tag)
			_check(r["error"] == "", "%s: %s" % [tag, r["error"]])
			var w: CombatWorld = r["world"]
			for f in w.fighters:
				_check(f.stat_attacks >= 5, "%s: P%d attacked only %d times (passive AI)" % [tag, f.index + 1, f.stat_attacks])
			var hits := _count(r["events"], "hit")
			_check(hits >= 5, "%s: only %d hits in the whole match" % [tag, hits])
			print("        %s -> winner P%d, %d frames, %d hits, rounds %s" % [tag, flow.match_winner + 1, r["frames"], hits, str(flow.round_results)])
