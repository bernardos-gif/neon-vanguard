class_name PlayerInputReader
extends RefCounted
## Reads one player's actions from the InputMap and converts them into an
## InputState for the combat simulation. Works for keyboard and gamepads.

var prefix := "p1_"


func _init(player: int) -> void:
	prefix = "p%d_" % (player + 1)


func _held(action: String) -> bool:
	var a := prefix + action
	return Input.is_action_pressed(a) or Input.is_action_just_pressed(a)


func read() -> InputState:
	var x := int(_held("right")) - int(_held("left"))
	var up := _held("up")
	var down := _held("down")
	var y := 0
	if up and not down:
		y = 1
	elif down and not up:
		y = -1
	var b := 0
	if _held("light"): b |= InputState.LIGHT
	if _held("medium"): b |= InputState.MEDIUM
	if _held("heavy"): b |= InputState.HEAVY
	if _held("special"): b |= InputState.SPECIAL
	if _held("throw"): b |= InputState.THROW
	return InputState.new(x, y, b)
