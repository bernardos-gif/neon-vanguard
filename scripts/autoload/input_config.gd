extends Node
## Registers all input actions at startup: keyboard for both players and
## gamepads (Xbox-style layout) for both players. Every device feeds the same
## actions, so combat rules are identical for all control methods.
##
## Default layout
##   Player 1 keyboard: A/D move, W jump, S crouch, J light, K medium,
##                      L heavy, I special, U throw
##   Player 2 keyboard: arrows move/jump/crouch, Numpad 1/2/3 light/medium/heavy,
##                      Numpad 5 special, Numpad 4 throw  (alt: , . / ; ')
##   Gamepad (pad 1 = Player 1, pad 2 = Player 2): D-pad / left stick move,
##                      X light, Y medium, RB heavy, A special, B throw,
##                      Start pause

const PLAYER_ACTIONS := ["left", "right", "up", "down", "light", "medium", "heavy", "special", "throw"]

const KEYS := {
	"p1": {
		"left": [KEY_A], "right": [KEY_D], "up": [KEY_W], "down": [KEY_S],
		"light": [KEY_J], "medium": [KEY_K], "heavy": [KEY_L], "special": [KEY_I], "throw": [KEY_U],
	},
	"p2": {
		"left": [KEY_LEFT], "right": [KEY_RIGHT], "up": [KEY_UP], "down": [KEY_DOWN],
		"light": [KEY_KP_1, KEY_COMMA], "medium": [KEY_KP_2, KEY_PERIOD], "heavy": [KEY_KP_3, KEY_SLASH],
		"special": [KEY_KP_5, KEY_SEMICOLON], "throw": [KEY_KP_4, KEY_APOSTROPHE],
	},
}

const PAD_BUTTONS := {
	"left": [JOY_BUTTON_DPAD_LEFT], "right": [JOY_BUTTON_DPAD_RIGHT],
	"up": [JOY_BUTTON_DPAD_UP], "down": [JOY_BUTTON_DPAD_DOWN],
	"light": [JOY_BUTTON_X], "medium": [JOY_BUTTON_Y], "heavy": [JOY_BUTTON_RIGHT_SHOULDER],
	"special": [JOY_BUTTON_A], "throw": [JOY_BUTTON_B],
}

const PAD_AXES := {
	"left": [JOY_AXIS_LEFT_X, -1.0], "right": [JOY_AXIS_LEFT_X, 1.0],
	"up": [JOY_AXIS_LEFT_Y, -1.0], "down": [JOY_AXIS_LEFT_Y, 1.0],
}


func _ready() -> void:
	register_defaults()


func register_defaults() -> void:
	for player in ["p1", "p2"]:
		var device := 0 if player == "p1" else 1
		for act in PLAYER_ACTIONS:
			var action: String = player + "_" + act
			if InputMap.has_action(action):
				InputMap.erase_action(action)
			InputMap.add_action(action, 0.45)
			for key in KEYS[player][act]:
				var ev := InputEventKey.new()
				ev.physical_keycode = key
				InputMap.action_add_event(action, ev)
			for btn in PAD_BUTTONS[act]:
				var jb := InputEventJoypadButton.new()
				jb.device = device
				jb.button_index = btn
				InputMap.action_add_event(action, jb)
			if PAD_AXES.has(act):
				var jm := InputEventJoypadMotion.new()
				jm.device = device
				jm.axis = PAD_AXES[act][0]
				jm.axis_value = PAD_AXES[act][1]
				InputMap.action_add_event(action, jm)
	# Pause on Escape or Start (any pad).
	if InputMap.has_action("pause"):
		InputMap.erase_action("pause")
	InputMap.add_action("pause")
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	InputMap.action_add_event("pause", esc)
	var start := InputEventJoypadButton.new()
	start.device = -1
	start.button_index = JOY_BUTTON_START
	InputMap.action_add_event("pause", start)
	# Let Player 1's keys also navigate menus.
	_add_key("ui_left", KEY_A)
	_add_key("ui_right", KEY_D)
	_add_key("ui_up", KEY_W)
	_add_key("ui_down", KEY_S)
	_add_key("ui_accept", KEY_J)
	_add_key("ui_cancel", KEY_BACKSPACE)


func _add_key(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		return
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and ev.physical_keycode == key:
			return
	var e := InputEventKey.new()
	e.physical_keycode = key
	InputMap.action_add_event(action, e)


## Human-readable binding list for the controls screen.
func describe(player: String) -> Array:
	var rows := []
	var labels := {
		"left": "Move left", "right": "Move right", "up": "Jump", "down": "Crouch",
		"light": "Light attack", "medium": "Medium attack", "heavy": "Heavy attack",
		"special": "Special (+ direction)", "throw": "Throw",
	}
	for act in PLAYER_ACTIONS:
		var keys := []
		for ev in InputMap.action_get_events(player + "_" + act):
			if ev is InputEventKey:
				keys.append(OS.get_keycode_string(ev.physical_keycode))
		rows.append([labels[act], " / ".join(keys)])
	return rows
