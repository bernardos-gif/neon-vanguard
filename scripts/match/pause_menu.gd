class_name PauseMenu
extends CanvasLayer
## Pause menu (Esc / Start). Pauses the whole match, including the combat
## simulation, until resumed.

signal restart_requested

var enabled := true
var _root: Control
var _first: Button
var _overlay: Control


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiTheme.get_theme()
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.03, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.position = Vector2(160, 260)
	_root.add_child(v)
	v.add_child(UiTheme.title_label("PAUSED", 72, UiTheme.CYAN))
	_first = UiTheme.button("RESUME", resume)
	v.add_child(_first)
	v.add_child(UiTheme.button("CONTROLS", _open.bind("controls")))
	v.add_child(UiTheme.button("SETTINGS", _open.bind("settings")))
	v.add_child(UiTheme.button("RESTART MATCH", func(): restart_requested.emit()))
	v.add_child(UiTheme.button("CHARACTER SELECT", func(): GameState.go_to(GameState.CHARACTER_SELECT)))
	v.add_child(UiTheme.button("MAIN MENU", func(): GameState.go_to(GameState.MAIN_MENU)))


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if _overlay:
			return
		if get_tree().paused:
			resume()
		else:
			pause()
	elif event.is_action_pressed("ui_cancel") and get_tree().paused and _overlay == null:
		get_viewport().set_input_as_handled()
		resume()


func pause() -> void:
	get_tree().paused = true
	_root.visible = true
	AudioManager.play(&"ui_back", -4.0, 0.0)
	_first.grab_focus()


func resume() -> void:
	get_tree().paused = false
	_root.visible = false


func _open(which: String) -> void:
	_overlay = SettingsMenu.new() if which == "settings" else ControlsPanel.new()
	_root.add_child(_overlay)
	_overlay.closed.connect(func():
		_overlay = null
		_first.grab_focus())
