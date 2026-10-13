class_name SettingsMenu
extends Control
## Settings overlay (audio, display, graphics, gameplay). Works from the main
## menu and from the pause menu. Every option applies immediately and is
## saved to user://settings.cfg.

signal closed

var _first: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	v.add_child(UiTheme.title_label("SETTINGS", 46, UiTheme.CYAN))
	v.add_child(_section("AUDIO"))
	for spec in [["Master volume", "master_volume"], ["Music", "music_volume"], ["Sound effects", "sfx_volume"], ["Ambience", "ambient_volume"]]:
		var row := SliderRow.new(spec[0], Settings.get_value(spec[1]))
		var key: String = spec[1]
		row.value_changed.connect(func(val): Settings.set_value(key, val))
		v.add_child(row)
		if _first == null:
			_first = row.slider
	v.add_child(_section("DISPLAY & GRAPHICS"))
	var full := OptionRow.new("Window mode", ["WINDOWED", "FULLSCREEN"], 1 if Settings.get_value("fullscreen") else 0)
	full.value_changed.connect(func(i): Settings.set_value("fullscreen", i == 1))
	v.add_child(full)
	var vsync := OptionRow.new("V-Sync", ["OFF", "ON"], 1 if Settings.get_value("vsync") else 0)
	vsync.value_changed.connect(func(i): Settings.set_value("vsync", i == 1))
	v.add_child(vsync)
	var fps := OptionRow.new("Frame limit", ["UNLIMITED", "60", "120", "144"], Settings.get_value("fps_limit_index"))
	fps.value_changed.connect(func(i): Settings.set_value("fps_limit_index", i))
	v.add_child(fps)
	var q := OptionRow.new("Graphics quality", Settings.QUALITY_NAMES, Settings.quality())
	q.value_changed.connect(func(i): Settings.set_value("quality", i))
	v.add_child(q)
	v.add_child(_section("GAMEPLAY"))
	var shake := OptionRow.new("Screen shake", ["OFF", "ON"], 1 if Settings.get_value("screen_shake") else 0)
	shake.value_changed.connect(func(i): Settings.set_value("screen_shake", i == 1))
	v.add_child(shake)
	var hints := OptionRow.new("Control hints in match", ["OFF", "ON"], 1 if Settings.get_value("show_hints") else 0)
	hints.value_changed.connect(func(i): Settings.set_value("show_hints", i == 1))
	v.add_child(hints)
	var diff := OptionRow.new("Default CPU difficulty", GameState.DIFFICULTY_NAMES, Settings.get_value("default_difficulty"))
	diff.value_changed.connect(func(i):
		Settings.set_value("default_difficulty", i)
		GameState.difficulty = i)
	v.add_child(diff)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	v.add_child(spacer)
	v.add_child(UiTheme.button("BACK", close))
	await get_tree().process_frame
	if is_instance_valid(_first):
		_first.grab_focus()
	panel.position = (get_viewport_rect().size - panel.size) * 0.5


func _section(text: String) -> Label:
	var l := UiTheme.label(text, 24, UiTheme.MAGENTA, UiTheme.bold_font())
	return l


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	AudioManager.play(&"ui_back", -4.0, 0.0)
	closed.emit()
	queue_free()
