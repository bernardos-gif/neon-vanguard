class_name FighterData
extends Resource
## Everything that defines a fighter: identity, movement stats, moves and look.
## Stored as .tres files in res://data/fighters so values can be tuned in the
## Godot Inspector without touching code.

@export var id: StringName
@export var display_name := ""
@export var title := ""
@export_multiline var bio := ""
@export_multiline var style_summary := ""

@export_group("Stats")
@export var max_health := 1000
@export var walk_forward_speed := 2.6
@export var walk_back_speed := 2.0
@export var dash_forward_speed := 7.5
@export var dash_forward_frames := 16
@export var dash_back_speed := 6.5
@export var dash_back_frames := 18
@export var jump_velocity := 9.6
@export var jump_forward_speed := 3.0
@export var jump_back_speed := 2.6
@export var gravity := 26.0
@export var pushbox_width := 0.6
@export var stand_height := 1.8
@export var crouch_height := 1.15

@export_group("Moves")
## Move id -> AttackData. Expected ids: st_light, st_medium, st_heavy,
## cr_light, cr_medium, cr_heavy, j_light, j_medium, j_heavy, sp_neutral,
## sp_forward, sp_back, throw, plus any follow-up moves (counter attacks).
@export var moves: Dictionary = {}

@export_group("Look")
@export var rig_style: StringName = &"kairo"
@export var body_scale := 1.0
@export var primary_color := Color(0.1, 0.25, 0.8)
@export var secondary_color := Color(0.05, 0.06, 0.1)
@export var accent_color := Color(0.2, 0.9, 1.0)
@export var skin_color := Color(0.78, 0.58, 0.45)
@export var hair_color := Color(0.05, 0.05, 0.06)
@export var alt_primary_color := Color(0.8, 0.8, 0.85)
@export var alt_secondary_color := Color(0.15, 0.15, 0.18)
@export var alt_accent_color := Color(1.0, 0.7, 0.2)
@export var ui_color := Color(0.2, 0.9, 1.0)


func get_move(move_id: StringName) -> AttackData:
	return moves.get(move_id) as AttackData


func has_move(move_id: StringName) -> bool:
	return moves.has(move_id) and moves[move_id] != null
