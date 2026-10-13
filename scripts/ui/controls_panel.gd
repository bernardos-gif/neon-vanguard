class_name ControlsPanel
extends Control
## Shows the keyboard and gamepad controls.

signal closed

var _back: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	v.add_child(UiTheme.title_label("CONTROLS", 46, UiTheme.CYAN))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 60)
	v.add_child(cols)
	for p in [["PLAYER 1  (keyboard)", "p1"], ["PLAYER 2  (keyboard)", "p2"]]:
		var col := VBoxContainer.new()
		col.add_child(UiTheme.label(p[0], 28, UiTheme.MAGENTA, UiTheme.bold_font()))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 28)
		for row in InputConfig.describe(p[1]):
			grid.add_child(UiTheme.label(row[0], 26, UiTheme.DIM))
			grid.add_child(UiTheme.label(row[1], 26))
		col.add_child(grid)
		cols.add_child(col)
	var pad := UiTheme.label("GAMEPAD (pad 1 = P1, pad 2 = P2):  D-pad / left stick move  ·  X light  ·  Y medium  ·  RB heavy  ·  A special  ·  B throw  ·  Start pause", 24, UiTheme.TEXT)
	pad.autowrap_mode = TextServer.AUTOWRAP_WORD
	pad.custom_minimum_size = Vector2(1100, 0)
	v.add_child(pad)
	var tips := UiTheme.label(
		"BASICS:  hold BACK (away from your opponent) to block high/mid  ·  hold DOWN-BACK to block lows\n" +
		"Jump attacks must be blocked standing  ·  Throws beat blocking; press THROW as you are grabbed to break it\n" +
		"Double-tap forward/back to dash  ·  Chain Light > Medium > Heavy > Special when an attack connects\n" +
		"SPECIALS:  Special alone, Special + forward, Special + back (each fighter has three)", 24, UiTheme.DIM)
	tips.autowrap_mode = TextServer.AUTOWRAP_WORD
	tips.custom_minimum_size = Vector2(1100, 0)
	v.add_child(tips)
	_back = UiTheme.button("BACK", close)
	v.add_child(_back)
	await get_tree().process_frame
	_back.grab_focus()
	panel.position = (get_viewport_rect().size - panel.size) * 0.5


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	AudioManager.play(&"ui_back", -4.0, 0.0)
	closed.emit()
	queue_free()
