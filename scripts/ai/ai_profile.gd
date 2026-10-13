class_name AiProfile
extends Resource
## Decision-making parameters for one CPU difficulty. Difficulty changes how
## the CPU *decides*, never the combat rules it plays by.

@export var display_name := "Normal"
## Frames before the CPU perceives what the opponent is doing.
@export var reaction_frames := 16
## Base frames between neutral decisions.
@export var decision_interval := 16
## Chance to correctly block an attack it has perceived.
@export_range(0.0, 1.0) var block_chance := 0.45
## Chance to punish a perceived whiffed / unsafe move.
@export_range(0.0, 1.0) var punish_chance := 0.4
@export_range(0.0, 1.0) var anti_air_chance := 0.3
## Chance to continue a combo after each confirmed hit.
@export_range(0.0, 1.0) var combo_skill := 0.5
## Preference for approaching and attacking versus waiting.
@export_range(0.0, 1.0) var aggression := 0.6
@export_range(0.0, 1.0) var throw_chance := 0.12
@export_range(0.0, 1.0) var special_chance := 0.3
@export_range(0.0, 1.0) var jump_chance := 0.1
## Idle frames held before committing to an attack (a readable "tell").
@export var telegraph_frames := 6
## Chance that a decision is replaced with a random (often poor) action.
@export_range(0.0, 1.0) var mistake_chance := 0.1
