extends Node
## Match setup shared between menus and the match scene.

enum Mode { VS_CPU, VS_PLAYER, CPU_VS_CPU }

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const CHARACTER_SELECT := "res://scenes/ui/character_select.tscn"
const MATCH := "res://scenes/match/match.tscn"

const FIGHTERS := {
	&"kairo": "res://data/fighters/kairo.tres",
	&"vesper": "res://data/fighters/vesper.tres",
}
const FIGHTER_ORDER := [&"kairo", &"vesper"]
const AI_PROFILES := ["res://data/ai/easy.tres", "res://data/ai/normal.tres", "res://data/ai/hard.tres"]
const DIFFICULTY_NAMES := ["EASY", "NORMAL", "HARD"]

var mode: Mode = Mode.VS_CPU
var p1_fighter: StringName = &"kairo"
var p2_fighter: StringName = &"vesper"
var difficulty := 1
var p1_difficulty := 1          # used by CPU_VS_CPU
var rounds_to_win := 2
var round_seconds := 99
var ai_seed := 0                # 0 = random


func get_fighter(id: StringName) -> FighterData:
	var path: String = FIGHTERS.get(id, FIGHTERS[&"kairo"])
	var res := load(path) as FighterData
	if res == null:
		push_error("GameState: could not load fighter data at " + path)
	return res


func get_ai_profile(level: int) -> AiProfile:
	var path: String = AI_PROFILES[clampi(level, 0, AI_PROFILES.size() - 1)]
	var res := load(path) as AiProfile
	if res == null:
		push_error("GameState: could not load AI profile at " + path)
	return res


func go_to(path: String) -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("GameState: failed to change scene to %s (error %d)" % [path, err])
