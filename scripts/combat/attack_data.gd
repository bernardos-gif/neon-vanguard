class_name AttackData
extends Resource
## Frame data and properties of one move. All timing is in frames at the
## fixed 60 Hz combat rate, so results never depend on rendering frame rate.
##
## Frame numbering: the frame on which a move begins is frame 0.
## Frames [0, startup) are startup, [startup, startup + active) are active,
## and the remaining `recovery` frames are recovery.

enum HitLevel { MID, LOW, OVERHEAD, UNBLOCKABLE }
enum Strength { LIGHT, MEDIUM, HEAVY, SPECIAL }
enum Kind { STRIKE, PROJECTILE, THROW, COUNTER, EVADE }

@export var id: StringName
@export var display_name := ""
@export var kind: Kind = Kind.STRIKE
@export var strength: Strength = Strength.LIGHT
@export var hit_level: HitLevel = HitLevel.MID

@export_group("Timing (frames at 60 fps)")
@export var startup := 5
@export var active := 2
@export var recovery := 8

@export_group("Damage and stun")
@export var damage := 30
@export var chip_damage := 0
@export var hitstun := 14
@export var blockstun := 10
## Initial horizontal speed (m/s) given to the defender on hit / block.
@export var hit_pushback := 2.5
@export var block_pushback := 3.0
## Number of separate hits (multi-hit moves) and frames between them.
@export var hits := 1
@export var hit_interval := 0
@export var knockdown := false
## Launch velocity (m/s) for knockdowns: x away from attacker, y upward.
@export var launch := Vector2(2.5, 5.5)

@export_group("Hitbox (fighter space, facing right, metres)")
## position.x = distance in front of the fighter's centre where the box starts,
## position.y = height of the box's bottom edge above the fighter's feet.
@export var hitbox := Rect2(0.2, 1.2, 0.6, 0.3)

@export_group("Movement")
## Velocity (m/s, x forward) applied between move_start and move_end frames.
@export var move_velocity := Vector2.ZERO
@export var move_start := 0
@export var move_end := 0

@export_group("Defence")
## Fully invulnerable between these frames (inclusive). invuln_end < 0 = none.
@export var invuln_start := 0
@export var invuln_end := -1
## Shrinks the hurtbox during startup/active so the move passes under high attacks.
@export var low_profile := false
## For COUNTER moves: the move that is performed when the counter succeeds.
@export var counter_attack: StringName

@export_group("Projectile")
@export var projectile_speed := 7.0
@export var projectile_lifetime := 110
@export var projectile_size := Vector2(0.45, 0.45)
@export var projectile_height := 1.25

@export_group("Cancels")
## On contact (hit or block) this move may be cancelled into a stronger normal.
@export var cancel_into_normals := true
## On contact this move may be cancelled into a special move.
@export var cancel_into_specials := true
## Throws only: maximum gap (m) between the two fighters' bodies.
@export var throw_range := 0.55

@export_group("Presentation")
@export var pose_windup: StringName
@export var pose_strike: StringName
@export var hit_sound: StringName = &"hit_light"
@export var whiff_sound: StringName = &"whiff_light"


func total_frames() -> int:
	return startup + active + recovery


func is_active_frame(frame: int) -> bool:
	return frame >= startup and frame < startup + active


func is_recovery_frame(frame: int) -> bool:
	return frame >= startup + active


func is_invulnerable_frame(frame: int) -> bool:
	return invuln_end >= 0 and frame >= invuln_start and frame <= invuln_end


func is_normal() -> bool:
	return strength != Strength.SPECIAL and kind == Kind.STRIKE
