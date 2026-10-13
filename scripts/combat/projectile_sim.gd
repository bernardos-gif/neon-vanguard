class_name ProjectileSim
extends RefCounted
## A projectile travelling along the combat plane.

var id := 0
var owner  # FighterSim
var attack: AttackData
var pos := Vector2.ZERO
var dir := 1
var age := 0
var alive := true


func step() -> void:
	age += 1
	pos.x += dir * attack.projectile_speed * FighterSim.DT


func rect() -> Rect2:
	var s := attack.projectile_size
	return Rect2(pos - s * 0.5, s)
