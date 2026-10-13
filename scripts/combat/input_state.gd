class_name InputState
extends RefCounted
## One frame of fighter input, independent of the device that produced it.
## Keyboard, gamepad and the CPU all produce InputState objects, so every
## control method runs through exactly the same combat rules.

const LIGHT := 1
const MEDIUM := 2
const HEAVY := 4
const SPECIAL := 8
const THROW := 16
const ATTACK_BUTTONS := LIGHT | MEDIUM | HEAVY

## Horizontal direction in screen space: -1 left, 0 neutral, +1 right.
var x := 0
## Vertical direction: -1 down (crouch), 0 neutral, +1 up (jump).
var y := 0
## Bit mask of buttons currently held.
var buttons := 0


func _init(p_x := 0, p_y := 0, p_buttons := 0) -> void:
	x = clampi(p_x, -1, 1)
	y = clampi(p_y, -1, 1)
	buttons = p_buttons


func has(button: int) -> bool:
	return (buttons & button) != 0


func duplicate_state() -> InputState:
	return InputState.new(x, y, buttons)


static func neutral() -> InputState:
	return InputState.new()
