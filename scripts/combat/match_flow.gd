class_name MatchFlow
extends RefCounted
## Round and match rules: intro, fight, KO / time-out, round transitions and
## match completion. Pure logic driven one frame at a time by tick(), so the
## whole match loop can be tested headlessly.

enum Phase { INTRO, FIGHT, ROUND_END, MATCH_END }

const FPS := 60
const INTRO_FRAMES := 100        # "ROUND n" ... "FIGHT!"
const ROUND_END_FRAMES := 200
const VICTORY_POSE_FRAME := 80
const DRAW := -1
const UNDECIDED := -2

var world: CombatWorld
var rounds_to_win := 2
var round_seconds := 99
var phase: Phase = Phase.INTRO
var phase_frame := 0
var round_number := 0
var wins := [0, 0]
var round_results: Array = []    # winner index per round (DRAW for draws)
var round_winner := UNDECIDED
var round_end_reason := ""       # "ko", "double_ko", "timeout"
var match_winner := UNDECIDED
var timer_frames := 0
var total_frames := 0
var fight_frames := 0

var _neutral := InputState.new()


func _init(p_world: CombatWorld, p_rounds_to_win := 2, p_round_seconds := 99) -> void:
	world = p_world
	rounds_to_win = maxi(1, p_rounds_to_win)
	round_seconds = maxi(1, p_round_seconds)


func max_rounds() -> int:
	return rounds_to_win * 2 + 1


func start_match() -> Array:
	wins = [0, 0]
	round_results.clear()
	round_number = 0
	match_winner = UNDECIDED
	total_frames = 0
	fight_frames = 0
	return _start_round()


func _start_round() -> Array:
	round_number += 1
	world.reset_round()
	world.set_locked(true)
	phase = Phase.INTRO
	phase_frame = 0
	round_winner = UNDECIDED
	round_end_reason = ""
	timer_frames = round_seconds * FPS
	return [{"type": "round_start", "round": round_number, "final": _is_final_round()}]


func _is_final_round() -> bool:
	return wins[0] == rounds_to_win - 1 and wins[1] == rounds_to_win - 1


func seconds_left() -> int:
	return int(ceil(float(timer_frames) / FPS))


func is_fighting() -> bool:
	return phase == Phase.FIGHT


## Advances one frame. Inputs are ignored outside the FIGHT phase.
func tick(input_a: InputState, input_b: InputState) -> Array:
	var out: Array = []
	phase_frame += 1
	total_frames += 1
	match phase:
		Phase.INTRO:
			out.append_array(world.step(_neutral, _neutral))
			if phase_frame >= INTRO_FRAMES:
				world.set_locked(false)
				phase = Phase.FIGHT
				phase_frame = 0
				out.append({"type": "fight"})
		Phase.FIGHT:
			fight_frames += 1
			out.append_array(world.step(input_a, input_b))
			if world.hitstop == 0:
				timer_frames = maxi(timer_frames - 1, 0)
			var a: FighterSim = world.fighters[0]
			var b: FighterSim = world.fighters[1]
			if a.health <= 0 or b.health <= 0:
				if a.health <= 0 and b.health <= 0:
					out.append_array(_end_round(DRAW, "double_ko"))
				else:
					out.append_array(_end_round(0 if b.health <= 0 else 1, "ko"))
			elif timer_frames <= 0:
				var ra := float(a.health) / a.data.max_health
				var rb := float(b.health) / b.data.max_health
				var w := DRAW
				if ra > rb + 0.0001:
					w = 0
				elif rb > ra + 0.0001:
					w = 1
				out.append_array(_end_round(w, "timeout"))
		Phase.ROUND_END:
			out.append_array(world.step(_neutral, _neutral))
			if phase_frame == VICTORY_POSE_FRAME and round_winner >= 0:
				var wf: FighterSim = world.fighters[round_winner]
				if not wf.airborne and wf.state != FighterSim.State.KO:
					wf.enter_victory()
					out.append({"type": "victory_pose", "fighter": round_winner})
			if phase_frame >= ROUND_END_FRAMES:
				var mw := _decided_match_winner()
				if mw != UNDECIDED:
					match_winner = mw
					phase = Phase.MATCH_END
					phase_frame = 0
					out.append({"type": "match_over", "winner": mw})
				else:
					out.append_array(_start_round())
		Phase.MATCH_END:
			out.append_array(world.step(_neutral, _neutral))
	return out


func _end_round(winner: int, reason: String) -> Array:
	phase = Phase.ROUND_END
	phase_frame = 0
	round_winner = winner
	round_end_reason = reason
	world.round_over = true
	world.set_locked(true)
	if winner >= 0:
		wins[winner] += 1
	round_results.append(winner)
	var perfect := false
	if winner >= 0:
		var wf: FighterSim = world.fighters[winner]
		perfect = wf.health == wf.data.max_health
	return [{"type": "round_over", "winner": winner, "reason": reason, "round": round_number, "perfect": perfect}]


func _decided_match_winner() -> int:
	for i in 2:
		if wins[i] >= rounds_to_win:
			return i
	if round_number >= max_rounds():
		if wins[0] > wins[1]:
			return 0
		if wins[1] > wins[0]:
			return 1
		return DRAW
	return UNDECIDED
